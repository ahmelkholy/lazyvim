local M = {}

local uv = vim.uv or vim.loop
local jsonc = require("config.jsonc")
local key_actions = require("config.key_actions")
local begin_marker = "// BEGIN NVIM SHARED KEY ROUTES"
local end_marker = "// END NVIM SHARED KEY ROUTES"
local route_metadata_prefix = "// NVIM SHARED "
local manifest_fields = { "key", "command", "args", "when", "nvim", "description", "modes", "source", "replaced" }
local binding_fields = { "key", "command", "args", "when" }
local metadata_fields = { "nvim", "description", "modes", "source", "replaced" }

M.manifest_path = vim.fn.stdpath("config") .. "/shared-keybindings.json"

local function vscode_user_dir()
  if vim.env.NVIM_VSCODE_USER_DIR and vim.env.NVIM_VSCODE_USER_DIR ~= "" then
    return vim.fs.normalize(vim.env.NVIM_VSCODE_USER_DIR)
  end
  if vim.fn.has("mac") == 1 then
    return vim.fs.normalize(vim.fn.expand("~/Library/Application Support/Code/User"))
  end
  if vim.fn.has("win32") == 1 then
    local appdata = vim.env.APPDATA
    return appdata and vim.fs.normalize(appdata .. "/Code/User") or nil
  end
  return vim.fs.normalize(vim.fn.expand("~/.config/Code/User"))
end

local user_dir = vscode_user_dir()
M.keybindings_path = user_dir and (user_dir .. "/keybindings.json") or nil

local function read_raw(path)
  if not path then
    return nil, "path is unavailable on this host"
  end
  local handle, err = io.open(path, "rb")
  if not handle then
    return nil, err
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function write_raw(path, content)
  local handle, err = io.open(path, "wb")
  if not handle then
    return false, err
  end
  local ok, write_err = handle:write(content)
  local close_ok, close_err = handle:close()
  if not ok then
    return false, write_err
  end
  if not close_ok then
    return false, close_err
  end
  if M._expected_writes then
    M._expected_writes[path] = {
      content = content,
      expires = uv.hrtime() + 1000000000,
    }
  end
  return true
end

local function normalize_lines(raw)
  local normalized = raw:gsub("\r\n", "\n")
  return vim.split(normalized, "\n", { plain = true }), raw:find("\r\n", 1, true) and "\r\n" or "\n"
end

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function marker_range(lines)
  local first
  for index, line in ipairs(lines) do
    local value = trim(line)
    if value == begin_marker then
      first = index
    elseif value == end_marker and first then
      return first, index
    end
  end
end

local function route_view(route)
  local view = {}
  for _, field in ipairs(manifest_fields) do
    if route[field] ~= nil then
      view[field] = route[field]
    end
  end
  return view
end

local function read_manifest()
  local raw, err = read_raw(M.manifest_path)
  if not raw then
    return nil, "cannot read shared key manifest: " .. tostring(err)
  end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok then
    return nil, "invalid shared key manifest: " .. tostring(decoded)
  end
  if
    type(decoded) ~= "table"
    or decoded.version ~= 1
    or type(decoded.routes) ~= "table"
    or not vim.islist(decoded.routes)
  then
    return nil, "shared key manifest must contain version 1 and a routes array"
  end
  return decoded
end

local function render_manifest(manifest)
  local lines = { "{", '  "version": 1,', '  "routes": [' }
  for index, route in ipairs(manifest.routes) do
    lines[#lines + 1] = "    {"
    local fields = {}
    for _, field in ipairs(manifest_fields) do
      if route[field] ~= nil then
        fields[#fields + 1] = field
      end
    end
    for field_index, field in ipairs(fields) do
      local comma = field_index < #fields and "," or ""
      lines[#lines + 1] = ("      %s: %s%s"):format(vim.json.encode(field), vim.json.encode(route[field]), comma)
    end
    lines[#lines + 1] = index < #manifest.routes and "    }," or "    }"
  end
  lines[#lines + 1] = "  ]"
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n") .. "\n"
end

local function read_managed_bindings()
  if not M.keybindings_path then
    return nil, "VS Code User directory is unavailable on this host"
  end
  local raw, err = read_raw(M.keybindings_path)
  if not raw then
    return nil, "cannot read VS Code keybindings: " .. tostring(err)
  end
  local lines = normalize_lines(raw)
  local first, last = marker_range(lines)
  if not first or not last then
    if raw:find(begin_marker, 1, true) or raw:find(end_marker, 1, true) then
      return nil, "managed route markers are incomplete; restore both markers before syncing"
    end
    return nil, "managed route markers are missing from VS Code keybindings.json", "unmanaged"
  end
  local fragment = "[\n" .. table.concat(vim.list_slice(lines, first + 1, last - 1), "\n") .. "\n]"
  local ok, objects = pcall(jsonc.objects, fragment)
  if not ok then
    return nil, "managed VS Code route block is invalid JSONC: " .. tostring(objects)
  end
  local routes, previous = {}, 1
  for _, item in ipairs(objects) do
    local binding = item.value
    local prefix = fragment:sub(previous, item.first - 1)
    local encoded = prefix:match("// NVIM SHARED ([^\r\n]+)")
    if encoded then
      local metadata_ok, values = pcall(vim.json.decode, encoded)
      if not metadata_ok or type(values) ~= "table" then
        return nil, "invalid managed route metadata: " .. tostring(values)
      end
      for _, field in ipairs(metadata_fields) do
        binding[field] = values[field]
      end
    end
    -- Changing a native command must change its Neovim meaning too, not retain
    -- stale metadata for the previous action. New supported entries need no tag.
    local inferred, inference_err = key_actions.infer(binding)
    if inferred then
      if binding.command ~= "vscode-neovim.send" and binding.nvim and binding.nvim ~= inferred then
        binding.description = nil
      end
      binding.nvim = inferred
    elseif not binding.nvim then
      return nil, "cannot share " .. tostring(binding.key) .. ": " .. inference_err
    end
    if binding.modes ~= nil and (type(binding.modes) ~= "table" or not vim.islist(binding.modes)) then
      return nil, "managed shortcut modes must be an array"
    end
    if binding.source ~= "vscode-user" then
      routes[#routes + 1] = binding
    elseif type(binding.replaced) == "table" and vim.islist(binding.replaced) then
      -- Recover the original route before replaying raw UI overrides. Removing
      -- an override must restore the previous action, not erase it permanently.
      for _, original in ipairs(binding.replaced) do
        if
          type(original) ~= "table"
          or type(original.key) ~= "string"
          or type(original.command) ~= "string"
          or type(original.nvim) ~= "string"
          or (original.modes ~= nil and (type(original.modes) ~= "table" or not vim.islist(original.modes)))
        then
          return nil, "invalid original shortcut saved in override metadata"
        end
        routes[#routes + 1] = original
      end
    end
    previous = item.last + 1
  end

  -- VS Code's Keyboard Shortcuts UI appends rules after the generated block.
  -- Import supported editor actions there, while leaving original JSONC intact.
  local suffix = "[\n" .. table.concat(vim.list_slice(lines, last + 1, #lines), "\n")
  suffix = suffix:gsub("^%[%s*,", "[")
  local suffix_ok, additions = pcall(jsonc.decode, suffix)
  if not suffix_ok then
    return nil, "VS Code shortcuts after the managed block are invalid JSONC: " .. tostring(additions)
  end
  M._import_warnings = {}
  for _, binding in ipairs(additions) do
    if type(binding) ~= "table" then
      return nil, "VS Code keybindings must contain shortcut objects"
    end
    if type(binding.command) == "string" and binding.command:sub(1, 1) ~= "-" then
      local inferred, inference_err = key_actions.infer(binding)
      local scope_ok, scope_err = key_actions.editor_scope(binding)
      local physical, key_err = M.to_nvim_key(binding.key)
      local is_leader = type(binding.key) == "string"
        and (binding.key:lower() == "space" or vim.startswith(binding.key:lower(), "space "))
      if inferred and scope_ok and physical and not is_leader then
        local route = route_view(binding)
        route.nvim, route.source = inferred, "vscode-user"
        route.modes = binding.when and binding.when:find("'visual'", 1, true) and { "x" } or { "n" }
        local replaced = {}
        -- Only replace the same modal scope; visual-only rules must not erase
        -- the normal route. Save original actions for later UI-rule removal.
        routes = vim.tbl_filter(function(existing)
          local overlaps = vim.tbl_contains(existing.modes or { "n" }, route.modes[1])
          if existing.key:lower() ~= route.key:lower() or not overlaps then
            return true
          end
          if existing.source == "vscode-user" then
            vim.list_extend(replaced, existing.replaced or {})
          else
            replaced[#replaced + 1] = route_view(existing)
          end
          return false
        end, routes)
        if #replaced > 0 then
          route.replaced = replaced
        end
        routes[#routes + 1] = route
      else
        M._import_warnings[#M._import_warnings + 1] = ("VS Code-only %s: %s"):format(
          tostring(binding.key),
          inference_err or scope_err or key_err or "Space chords must be added in shared_keymaps.lua"
        )
      end
    end
  end
  return routes
end

local function render_metadata(route)
  local fields = {}
  for _, field in ipairs(metadata_fields) do
    if route[field] ~= nil then
      fields[#fields + 1] = vim.json.encode(field) .. ":" .. vim.json.encode(route[field])
    end
  end
  return "  " .. route_metadata_prefix .. "{" .. table.concat(fields, ",") .. "}"
end

local function render_binding(route, is_last)
  local lines = { "  {" }
  local fields = {}
  for _, field in ipairs(binding_fields) do
    if route[field] ~= nil then
      fields[#fields + 1] = field
    end
  end
  for index, field in ipairs(fields) do
    local comma = index < #fields and "," or ""
    lines[#lines + 1] = ("    %s: %s%s"):format(vim.json.encode(field), vim.json.encode(route[field]), comma)
  end
  lines[#lines + 1] = is_last and "  }" or "  },"
  return lines
end

local function render_binding_block(routes, trailing)
  local lines = { "  " .. begin_marker }
  for index, route in ipairs(routes) do
    lines[#lines + 1] = render_metadata(route)
    vim.list_extend(lines, render_binding(route, index == #routes and not trailing))
  end
  lines[#lines + 1] = "  " .. end_marker
  return lines
end

local function replace_binding_block(routes)
  local raw, err = read_raw(M.keybindings_path)
  if not raw then
    if
      not M.keybindings_path
      or uv.fs_stat(M.keybindings_path)
      or not uv.fs_stat(vim.fs.dirname(M.keybindings_path))
    then
      return false, "cannot read VS Code keybindings: " .. tostring(err)
    end
    raw = "[\n]\n"
  end
  local lines, eol = normalize_lines(raw)
  local first, last = marker_range(lines)
  if not first or not last then
    if raw:find(begin_marker, 1, true) or raw:find(end_marker, 1, true) then
      return false, "managed route markers are incomplete; refusing to overwrite keybindings"
    end
    local ok, decoded = pcall(jsonc.decode, raw)
    if not ok or type(decoded) ~= "table" or not vim.islist(decoded) then
      return false, "VS Code keybindings must be a valid JSONC array before initializing shared routes"
    end
    local clean = jsonc.strip(raw)
    local close = clean:find("]%s*$")
    if not close then
      return false, "cannot locate the end of the VS Code keybindings array"
    end
    local prefix = raw:sub(1, close - 1)
    local comma = #decoded > 0 and not clean:sub(1, close - 1):match(",%s*$") and "  ,\n" or ""
    local block = table.concat(render_binding_block(routes), "\n")
    local inserted = prefix .. "\n" .. comma .. block .. "\n" .. raw:sub(close)
    -- Preserve CRLF exactly; prefix/suffix already use the original EOL.
    inserted = inserted:gsub("\r\n", "\n")
    if eol == "\r\n" then
      inserted = inserted:gsub("\n", "\r\n")
    end
    local written, write_err = write_raw(M.keybindings_path, inserted)
    return written, written and true or write_err
  end
  local output = {}
  for index = 1, first - 1 do
    output[#output + 1] = lines[index]
  end
  local suffix = table.concat(vim.list_slice(lines, last + 1, #lines), "\n")
  local suffix_clean = jsonc.strip(suffix):match("^%s*(.)")
  vim.list_extend(output, render_binding_block(routes, suffix_clean ~= "]" and suffix_clean ~= ","))
  for index = last + 1, #lines do
    output[#output + 1] = lines[index]
  end
  local normalized = table.concat(output, "\n")
  if eol == "\r\n" then
    normalized = normalized:gsub("\n", "\r\n")
  end
  local valid, decode_err = pcall(jsonc.decode, normalized)
  if not valid then
    return false, "refusing to write invalid VS Code JSONC: " .. tostring(decode_err)
  end
  if normalized == raw then
    return true, false
  end
  local ok, write_err = write_raw(M.keybindings_path, normalized)
  return ok, ok and true or write_err
end

local function same_bindings(manifest, bindings)
  if #manifest.routes ~= #bindings then
    return false
  end
  for index, route in ipairs(manifest.routes) do
    if not vim.deep_equal(route_view(route), route_view(bindings[index])) then
      return false
    end
  end
  return true
end

local function timestamp(path)
  local stat = path and uv.fs_stat(path) or nil
  return stat and stat.mtime or nil
end

local function newer(left, right)
  if not left then
    return false
  end
  if not right then
    return true
  end
  return left.sec > right.sec or (left.sec == right.sec and (left.nsec or 0) > (right.nsec or 0))
end

local base_names = {
  enter = "CR",
  ["return"] = "CR",
  escape = "Esc",
  esc = "Esc",
  backspace = "BS",
  delete = "Del",
  space = "Space",
  tab = "Tab",
  up = "Up",
  down = "Down",
  left = "Left",
  right = "Right",
  home = "Home",
  ["end"] = "End",
  pageup = "PageUp",
  pagedown = "PageDown",
}

local modifier_names = {
  ctrl = "C",
  control = "C",
  shift = "S",
  alt = "A",
  option = "A",
  cmd = "D",
  command = "D",
  meta = "M",
}

local function one_vscode_key(value)
  if value == "space" then
    return "<Space>"
  end
  local parts = vim.split(value, "+", { plain = true, trimempty = true })
  if #parts == 0 then
    return nil, "empty VS Code key"
  end
  local base = parts[#parts]:lower()
  local modifiers = {}
  for index = 1, #parts - 1 do
    local modifier = modifier_names[parts[index]:lower()]
    if not modifier then
      return nil, "unsupported VS Code modifier: " .. parts[index]
    end
    modifiers[#modifiers + 1] = modifier
  end
  if #modifiers == 1 and modifiers[1] == "C" and base == "6" then
    return "<C-^>"
  end
  base = base_names[base] or (base:match("^f%d+$") and base:upper()) or base
  if #modifiers == 0 then
    return #base == 1 and base or ("<" .. base .. ">")
  end
  return "<" .. table.concat(modifiers, "-") .. "-" .. base .. ">"
end

function M.to_nvim_key(value)
  if type(value) ~= "string" or value == "" then
    return nil, "VS Code key must be a non-empty string"
  end
  local keys = {}
  for _, part in ipairs(vim.split(value, " ", { plain = true, trimempty = true })) do
    local converted, err = one_vscode_key(part)
    if not converted then
      return nil, err
    end
    keys[#keys + 1] = converted
  end
  return table.concat(keys)
end

function M.to_vscode_key(value)
  value = value:gsub("<leader>", vim.g.mapleader or "\\")
  local modifiers = { C = "ctrl", S = "shift", A = "alt", M = "alt", D = "cmd" }
  local names = { CR = "enter", Esc = "escape", BS = "backspace", Del = "delete", Space = "space" }
  local keys = {}
  local index = 1
  while index <= #value do
    if value:sub(index, index) == "<" then
      local close = value:find(">", index, true)
      if not close then
        return nil, "unterminated Neovim key token"
      end
      local token = value:sub(index + 1, close - 1)
      local parts = {}
      while token:match("^[CSAMD]%-") do
        parts[#parts + 1] = modifiers[token:sub(1, 1)]
        token = token:sub(3)
      end
      if token == "^" then
        token = "6"
      end
      parts[#parts + 1] = names[token] or token:lower()
      keys[#keys + 1] = table.concat(parts, "+")
      index = close + 1
    else
      local character = value:sub(index, index)
      keys[#keys + 1] = character == " " and "space" or character
      index = index + 1
    end
  end
  return table.concat(keys, " ")
end

local function target_for(route)
  if type(route.nvim) == "string" and route.nvim ~= "" then
    return route.nvim
  end
  if route.command == "vscode-neovim.send" and type(route.args) == "string" then
    return route.args
  end
end

local function same_key(left, right)
  if not left or not right then
    return false
  end
  local left_codes = vim.api.nvim_replace_termcodes(left, true, true, true)
  local right_codes = vim.api.nvim_replace_termcodes(right, true, true, true)
  return left_codes == right_codes
end

local function validate_manifest(manifest)
  local errors = {}
  local seen = {}
  if #manifest.routes == 0 then
    errors[#errors + 1] = "shared key manifest has no routes"
    return errors
  end
  for index, route in ipairs(manifest.routes) do
    local prefix = ("route %d"):format(index)
    if type(route) ~= "table" then
      errors[#errors + 1] = prefix .. " must be an object"
    else
      if type(route.key) ~= "string" or route.key == "" then
        errors[#errors + 1] = prefix .. " needs a non-empty key string"
      end
      if type(route.command) ~= "string" or route.command == "" then
        errors[#errors + 1] = prefix .. " needs a non-empty command string"
      end
      if route.when ~= nil and type(route.when) ~= "string" then
        errors[#errors + 1] = prefix .. " has a non-string when clause"
      end
      if route.description ~= nil and type(route.description) ~= "string" then
        errors[#errors + 1] = prefix .. " has a non-string description"
      end
      if route.modes ~= nil then
        if type(route.modes) ~= "table" or not vim.islist(route.modes) or #route.modes == 0 then
          errors[#errors + 1] = prefix .. " modes must be a non-empty array"
        else
          for _, mode in ipairs(route.modes) do
            if mode ~= "n" and mode ~= "x" and mode ~= "i" and mode ~= "t" then
              errors[#errors + 1] = prefix .. " has unsupported mode " .. tostring(mode)
            end
          end
        end
      end
      if route.source ~= nil and type(route.source) ~= "string" then
        errors[#errors + 1] = prefix .. " source must be a string"
      end
      if route.replaced ~= nil and (type(route.replaced) ~= "table" or not vim.islist(route.replaced)) then
        errors[#errors + 1] = prefix .. " replaced routes must be an array"
      end

      if type(route.key) == "string" and route.key ~= "" then
        local identity = route.key:lower() .. "\0" .. tostring(route.when)
        if seen[identity] then
          errors[#errors + 1] = prefix .. " duplicates managed route " .. route.key
        end
        seen[identity] = true
        local _, key_err = M.to_nvim_key(route.key)
        if key_err then
          errors[#errors + 1] = prefix .. ": " .. key_err
        end
      end

      local target = target_for(route)
      if not target then
        errors[#errors + 1] = prefix .. " has no Neovim semantic target"
      end
      if route.command == "vscode-neovim.send" then
        if type(route.args) ~= "string" or route.args == "" then
          errors[#errors + 1] = prefix .. " must send a non-empty Neovim key string"
        elseif type(route.nvim) ~= "string" or not same_key(route.nvim, route.args) then
          errors[#errors + 1] = prefix .. " sends a key different from its Neovim target"
        end
      end
    end
  end
  return errors
end

local function key_identity(key)
  key = key:gsub("<leader>", vim.g.mapleader or "\\")
  return vim.api.nvim_replace_termcodes(key, true, true, true)
end

function M.global_maps(mode)
  local mappings = {}
  for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
    mappings[key_identity(mapping.lhs)] = mapping
  end
  return mappings
end

function M.mapping_options(mapping, desc)
  return {
    desc = desc or mapping.desc,
    expr = mapping.expr == 1,
    nowait = mapping.nowait == 1,
    remap = mapping.noremap == 0,
    replace_keycodes = mapping.replace_keycodes == 1,
    silent = mapping.silent == 1,
  }
end

function M.restore_mapping(mode, lhs, mapping)
  pcall(vim.keymap.del, mode, lhs)
  if not mapping or vim.tbl_isempty(mapping) then
    return
  end
  local rhs = mapping.callback or mapping.rhs
  if rhs == nil then
    return
  end
  vim.keymap.set(mode, lhs, rhs, M.mapping_options(mapping))
end

function M.clear_aliases()
  for _, alias in pairs(M._aliases or {}) do
    M.restore_mapping(alias.mode, alias.lhs, alias.original)
  end
  M._aliases = {}
end

function M.apply_aliases(manifest)
  M.clear_aliases()
  manifest = manifest or select(1, read_manifest())
  if not manifest then
    return
  end
  local baselines = {}
  for _, mode in ipairs({ "n", "x", "i", "t" }) do
    baselines[mode] = M.global_maps(mode)
  end
  for _, route in ipairs(manifest.routes) do
    local physical = M.to_nvim_key(route.key)
    local target = target_for(route)
    if physical and target and not same_key(physical, target) then
      for _, mode in ipairs(route.modes or { "n" }) do
        local identity = mode .. "\0" .. key_identity(physical)
        M._aliases[identity] = { mode = mode, lhs = physical, original = baselines[mode][key_identity(physical)] }
        local target_mapping = baselines[mode][key_identity(target)]
        local desc = route.description or (target_mapping and target_mapping.desc) or ("Shared route to " .. target)
        if target_mapping then
          -- Capture the original implementation, not an alias-to-alias chain.
          -- Key swaps must swap their actions without infinite remap recursion.
          vim.keymap.set(
            mode,
            physical,
            target_mapping.callback or target_mapping.rhs,
            M.mapping_options(target_mapping, desc)
          )
        else
          vim.keymap.set(mode, physical, target, { remap = false, silent = true, desc = desc })
        end
      end
    end
  end
end

function M.is_alias(mode, lhs)
  return M._aliases and M._aliases[mode .. "\0" .. key_identity(lhs)] ~= nil
end

function M.set_custom_routes(routes)
  local manifest, err = read_manifest()
  if not manifest then
    return false, err
  end
  local before = vim.deepcopy(manifest.routes)
  local previous = {}
  local kept = {}
  for _, route in ipairs(manifest.routes) do
    if route.source and vim.startswith(route.source, "shared_keymaps:") then
      previous[route.source] = route
    else
      kept[#kept + 1] = route
    end
  end
  for _, route in ipairs(routes) do
    -- A VS Code edit of a generated physical key survives reloads/restarts.
    -- The shared Lua file still owns the underlying action's implementation.
    local old = previous[route.source]
    if old and old.command == route.command and old.args == route.args then
      local updated = vim.deepcopy(route)
      updated.key = old.key
      kept[#kept + 1] = updated
    else
      kept[#kept + 1] = old or route
    end
  end
  manifest.routes = kept
  local errors = validate_manifest(manifest)
  if #errors > 0 then
    return false, table.concat(errors, "; ")
  end
  if vim.deep_equal(before, kept) then
    return true
  end
  local rendered = render_manifest(manifest)
  if read_raw(M.manifest_path) ~= rendered then
    return write_raw(M.manifest_path, rendered)
  end
  return true
end

function M.add(key, target, opts)
  opts = opts or {}
  if type(key) ~= "string" or type(target) ~= "string" then
    return false, "shared key and Neovim target must be strings"
  end
  if key:sub(1, 1) == "<" then
    key = M.to_vscode_key(key)
  end
  local physical, key_err = M.to_nvim_key(key)
  if not physical then
    return false, key_err
  end
  if key:lower() == "space" or vim.startswith(key:lower(), "space ") then
    return false, "Add leader shortcuts in :SharedKeysEdit so VS Code's Space menu remains available"
  end
  local reconciled, reconcile_err = M.sync()
  if not reconciled then
    return false, reconcile_err
  end
  local manifest, err = read_manifest()
  if not manifest then
    return false, err
  end
  local when = opts.when or "editorTextFocus && neovim.init && neovim.mode == 'normal' && !lazygitFocus"
  manifest.routes = vim.tbl_filter(function(route)
    return route.key:lower() ~= key:lower() or route.when ~= when
  end, manifest.routes)
  manifest.routes[#manifest.routes + 1] = {
    key = key,
    command = "vscode-neovim.send",
    args = target,
    nvim = target,
    when = when,
    description = opts.description,
    modes = opts.modes or { "n" },
  }
  local errors = validate_manifest(manifest)
  if #errors > 0 then
    return false, table.concat(errors, "; ")
  end
  local written, write_err = write_raw(M.manifest_path, render_manifest(manifest))
  if not written then
    return false, write_err
  end
  if not M.keybindings_path or not uv.fs_stat(vim.fs.dirname(M.keybindings_path)) then
    M.apply_aliases(manifest)
    return true
  end
  return M.push(opts)
end

function M.push(opts)
  opts = opts or {}
  local manifest, err = read_manifest()
  if not manifest then
    return false, err
  end
  local validation_errors = validate_manifest(manifest)
  if #validation_errors > 0 then
    return false, table.concat(validation_errors, "; ")
  end
  local ok, result = replace_binding_block(manifest.routes)
  if not ok then
    return false, result
  end
  M.apply_aliases(manifest)
  if opts.notify then
    vim.notify(result and "Shared keys pushed to VS Code" or "Shared keys already match VS Code")
  end
  return true, result
end

function M.pull(opts)
  opts = opts or {}
  local manifest, manifest_err = read_manifest()
  if not manifest then
    return false, manifest_err
  end
  local bindings, binding_err = read_managed_bindings()
  if not bindings then
    return false, binding_err
  end
  if same_bindings(manifest, bindings) then
    M.apply_aliases(manifest)
    if opts.notify then
      vim.notify("Shared keys already match Neovim")
    end
    return true, false
  end
  local routes = {}
  for _, binding in ipairs(bindings) do
    local route = route_view(binding)
    if binding.command == "vscode-neovim.send" and type(binding.args) == "string" then
      route.nvim = binding.args
    end
    routes[#routes + 1] = route
  end
  manifest.routes = routes
  local validation_errors = validate_manifest(manifest)
  if #validation_errors > 0 then
    return false, "refusing invalid VS Code pull: " .. table.concat(validation_errors, "; ")
  end
  local rendered = render_manifest(manifest)
  local current = read_raw(M.manifest_path)
  if rendered ~= current then
    local ok, write_err = write_raw(M.manifest_path, rendered)
    if not ok then
      return false, "cannot update shared key manifest: " .. tostring(write_err)
    end
  end
  M.apply_aliases(manifest)
  if opts.notify then
    vim.notify("Shared keys pulled from VS Code")
  end
  return true, true
end

function M.sync(opts)
  opts = opts or {}
  local manifest, manifest_err = read_manifest()
  if not manifest then
    return false, manifest_err
  end
  local validation_errors = validate_manifest(manifest)
  if #validation_errors > 0 then
    return false, table.concat(validation_errors, "; ")
  end
  if not M.keybindings_path or not uv.fs_stat(M.keybindings_path) then
    M.apply_aliases(manifest)
    if opts.notify then
      vim.notify("Neovim shared keys loaded; VS Code keybindings are not installed on this host", vim.log.levels.INFO)
    end
    return true, false
  end
  local bindings, binding_err, status = read_managed_bindings()
  if not bindings and status ~= "unmanaged" then
    return false, binding_err
  end
  if bindings and same_bindings(manifest, bindings) then
    M.apply_aliases(manifest)
    if opts.notify then
      vim.notify("Shared keys are synchronized")
    end
    return true, false
  end
  local manifest_time = timestamp(M.manifest_path)
  local keybindings_time = timestamp(M.keybindings_path)
  if bindings and newer(keybindings_time, manifest_time) then
    return M.pull(opts)
  end
  return M.push(opts)
end

function M.health()
  local report = { ok = false, errors = {}, warnings = {}, routes = 0, aliases = 0 }
  local manifest, manifest_err = read_manifest()
  if not manifest then
    report.errors[#report.errors + 1] = manifest_err
    return report
  end
  report.routes = #manifest.routes
  vim.list_extend(report.errors, validate_manifest(manifest))
  for _, route in ipairs(manifest.routes) do
    local physical = type(route.key) == "string" and M.to_nvim_key(route.key) or nil
    local target = target_for(route)
    if physical and target and not same_key(physical, target) then
      report.aliases = report.aliases + 1
    end
  end
  if M.keybindings_path and uv.fs_stat(M.keybindings_path) then
    local bindings, binding_err = read_managed_bindings()
    if not bindings then
      report.errors[#report.errors + 1] = binding_err
    elseif not same_bindings(manifest, bindings) then
      report.errors[#report.errors + 1] = "VS Code managed routes differ from the shared manifest; run :SharedKeysSync"
    end
  else
    report.warnings[#report.warnings + 1] = "VS Code keybindings.json is unavailable on this host"
  end
  report.ok = #report.errors == 0 and report.routes > 0
  vim.list_extend(report.warnings, M._import_warnings or {})
  local custom = package.loaded["config.custom_keys"]
  if custom then
    vim.list_extend(report.errors, custom.errors or {})
    report.ok = report.ok and #(custom.errors or {}) == 0
  end
  return report
end

function M.show_health()
  local report = M.health()
  local lines = {
    ("Shared key sync: %s"):format(report.ok and "PASS" or "FAIL"),
    ("Routes: %d | shared aliases: %d"):format(report.routes, report.aliases),
  }
  for _, message in ipairs(report.errors) do
    lines[#lines + 1] = "ERROR: " .. message
  end
  for _, message in ipairs(report.warnings) do
    lines[#lines + 1] = "WARN: " .. message
  end
  vim.notify(table.concat(lines, "\n"), report.ok and vim.log.levels.INFO or vim.log.levels.ERROR)
end

local function watch(path, callback)
  if not path or not uv.fs_stat(vim.fs.dirname(path)) then
    return
  end
  local watcher = uv.new_fs_event()
  local basename = vim.fs.basename(path)
  local generation = 0
  local started = watcher:start(
    vim.fs.dirname(path),
    {},
    vim.schedule_wrap(function(err, changed)
      if err or (changed and vim.fs.basename(vim.fs.normalize(changed)):lower() ~= basename:lower()) then
        return
      end
      generation = generation + 1
      local current = generation
      vim.defer_fn(function()
        if current ~= generation or vim.v.exiting ~= vim.NIL then
          return
        end
        local expected = M._expected_writes[path]
        if expected then
          local content = read_raw(path)
          if content == expected.content and uv.hrtime() <= expected.expires then
            return
          end
          M._expected_writes[path] = nil
        end
        local ok, sync_err = callback()
        if not ok and sync_err then
          vim.notify(sync_err, vim.log.levels.ERROR, { title = "Shared key sync" })
        end
      end, 180)
    end)
  )
  if not started then
    watcher:close()
    return
  end
  M._watchers[#M._watchers + 1] = watcher
end

function M.setup()
  if M._setup then
    return
  end
  M._setup = true
  M._watchers = {}
  M._aliases = {}
  M._expected_writes = {}
  local custom = require("config.custom_keys")
  custom.setup()

  vim.api.nvim_create_user_command("SharedKeysAdd", function(args)
    if #args.fargs >= 2 then
      local ok, err = M.add(args.fargs[1], args.fargs[2], {
        description = #args.fargs > 2 and table.concat(args.fargs, " ", 3) or nil,
        notify = true,
      })
      if not ok then
        vim.notify(err, vim.log.levels.ERROR)
      end
      return
    end
    vim.ui.input({ prompt = "Shared key (e.g. ctrl+alt+k): " }, function(key)
      if not key or key == "" then
        return
      end
      vim.ui.input({ prompt = "Existing Neovim action (e.g. <F2> or <leader>fn): " }, function(target)
        if not target or target == "" then
          return
        end
        local ok, err = M.add(key, target, { notify = true })
        if not ok then
          vim.notify(err, vim.log.levels.ERROR)
        end
      end)
    end)
  end, { nargs = "*", desc = "Add a physical shortcut in both editors", force = true })

  vim.api.nvim_create_user_command("SharedKeysSync", function()
    local ok, err = M.sync({ notify = true })
    if not ok then
      vim.notify(err, vim.log.levels.ERROR, { title = "Shared key sync" })
    end
  end, { desc = "Synchronize the newer shared key source", force = true })
  vim.api.nvim_create_user_command("SharedKeysPush", function()
    local ok, err = M.push({ notify = true })
    if not ok then
      vim.notify(err, vim.log.levels.ERROR, { title = "Shared key sync" })
    end
  end, { desc = "Push the Neovim shared key manifest to VS Code", force = true })
  vim.api.nvim_create_user_command("SharedKeysPull", function()
    local ok, err = M.pull({ notify = true })
    if not ok then
      vim.notify(err, vim.log.levels.ERROR, { title = "Shared key sync" })
    end
  end, { desc = "Pull VS Code's managed routes into Neovim", force = true })
  vim.api.nvim_create_user_command("SharedKeysHealth", M.show_health, {
    desc = "Audit bidirectional VS Code and Neovim key synchronization",
    force = true,
  })

  vim.schedule(function()
    local ok, err = custom.reload()
    if not ok and err then
      vim.notify(err, vim.log.levels.ERROR, { title = "Shared key sync" })
    end
  end)

  watch(M.manifest_path, function()
    return M.sync()
  end)
  watch(M.keybindings_path, function()
    return M.sync()
  end)
  watch(custom.path, function()
    return custom.reload()
  end)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("shared_key_sync_cleanup", { clear = true }),
    callback = function()
      M.clear_aliases()
      for _, watcher in ipairs(M._watchers) do
        pcall(watcher.stop, watcher)
        pcall(watcher.close, watcher)
      end
      M._watchers = {}
      M._expected_writes = {}
    end,
    desc = "Stop shared key file watchers",
  })
end

return M
