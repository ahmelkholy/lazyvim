local M = {}

local uv = vim.uv or vim.loop
local begin_marker = "// BEGIN NVIM SHARED KEY ROUTES"
local end_marker = "// END NVIM SHARED KEY ROUTES"
local route_metadata_prefix = "// NVIM SHARED "
local manifest_fields = { "key", "command", "args", "when", "nvim", "description" }
local binding_fields = { "key", "command", "args", "when" }
local metadata_fields = { "nvim", "description" }

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
  if type(decoded) ~= "table" or decoded.version ~= 1 or type(decoded.routes) ~= "table" then
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
    return nil, "managed route markers are missing from VS Code keybindings.json"
  end
  local fragment = {}
  local metadata = {}
  for index = first + 1, last - 1 do
    local value = trim(lines[index])
    if vim.startswith(value, route_metadata_prefix) then
      local encoded = value:sub(#route_metadata_prefix + 1)
      local metadata_ok, decoded_metadata = pcall(vim.json.decode, encoded)
      if not metadata_ok or type(decoded_metadata) ~= "table" then
        return nil, "invalid managed route metadata: " .. tostring(decoded_metadata)
      end
      metadata[#metadata + 1] = decoded_metadata
    elseif value ~= "" and value:sub(1, 2) ~= "//" then
      fragment[#fragment + 1] = lines[index]
    end
  end
  local ok, decoded = pcall(vim.json.decode, "[\n" .. table.concat(fragment, "\n") .. "\n]")
  if not ok or type(decoded) ~= "table" then
    return nil, "managed VS Code route block is invalid JSON: " .. tostring(decoded)
  end
  if #metadata ~= #decoded then
    return nil,
      ("managed VS Code routes need one NVIM SHARED metadata comment each (%d routes, %d comments)"):format(
        #decoded,
        #metadata
      )
  end
  for index, values in ipairs(metadata) do
    for _, field in ipairs(metadata_fields) do
      decoded[index][field] = values[field]
    end
  end
  return decoded
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

local function render_binding_block(routes)
  local lines = { "  " .. begin_marker }
  for index, route in ipairs(routes) do
    lines[#lines + 1] = render_metadata(route)
    vim.list_extend(lines, render_binding(route, index == #routes))
  end
  lines[#lines + 1] = "  " .. end_marker
  return lines
end

local function replace_binding_block(routes)
  local raw, err = read_raw(M.keybindings_path)
  if not raw then
    return false, "cannot read VS Code keybindings: " .. tostring(err)
  end
  local lines, eol = normalize_lines(raw)
  local first, last = marker_range(lines)
  if not first or not last then
    return false, "managed route markers are missing from VS Code keybindings.json"
  end
  local output = {}
  for index = 1, first - 1 do
    output[#output + 1] = lines[index]
  end
  vim.list_extend(output, render_binding_block(routes))
  for index = last + 1, #lines do
    output[#output + 1] = lines[index]
  end
  local normalized = table.concat(output, "\n")
  if eol == "\r\n" then
    normalized = normalized:gsub("\n", "\r\n")
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

local function restore_mapping(lhs, mapping)
  pcall(vim.keymap.del, "n", lhs)
  if not mapping or vim.tbl_isempty(mapping) then
    return
  end
  local rhs = mapping.callback or mapping.rhs
  if rhs == nil or rhs == "" then
    return
  end
  vim.keymap.set("n", lhs, rhs, {
    desc = mapping.desc,
    expr = mapping.expr == 1,
    nowait = mapping.nowait == 1,
    remap = mapping.noremap == 0,
    replace_keycodes = mapping.replace_keycodes == 1,
    silent = mapping.silent == 1,
  })
end

local function clear_aliases()
  for lhs, mapping in pairs(M._aliases or {}) do
    restore_mapping(lhs, mapping)
  end
  M._aliases = {}
end

function M.apply_aliases(manifest)
  if vim.g.vscode then
    return
  end
  clear_aliases()
  manifest = manifest or select(1, read_manifest())
  if not manifest then
    return
  end
  for _, route in ipairs(manifest.routes) do
    local physical = M.to_nvim_key(route.key)
    local target = target_for(route)
    if physical and target and not same_key(physical, target) then
      local original = vim.fn.maparg(physical, "n", false, true)
      M._aliases[physical] = vim.tbl_isempty(original) and false or original
      local target_mapping = vim.fn.maparg(target, "n", false, true)
      vim.keymap.set("n", physical, target, {
        remap = true,
        silent = true,
        desc = route.description or target_mapping.desc or ("Shared route to " .. target),
      })
    end
  end
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
  local bindings = read_managed_bindings()
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
  return report
end

function M.show_health()
  local report = M.health()
  local lines = {
    ("Shared key sync: %s"):format(report.ok and "PASS" or "FAIL"),
    ("Routes: %d | standalone aliases: %d"):format(report.routes, report.aliases),
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
  watcher:start(
    vim.fs.dirname(path),
    {},
    vim.schedule_wrap(function(err, changed)
      if err or (changed and changed ~= basename) then
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
    local ok, err = M.sync()
    if not ok and err then
      vim.notify(err, vim.log.levels.ERROR, { title = "Shared key sync" })
    end
  end)

  watch(M.manifest_path, function()
    return M.push()
  end)
  watch(M.keybindings_path, function()
    return M.pull()
  end)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("shared_key_sync_cleanup", { clear = true }),
    callback = function()
      clear_aliases()
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
