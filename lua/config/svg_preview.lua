local M = {}

local api = vim.api
local active

local function normalized(path)
  if not path or path == "" then
    return nil
  end
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function is_svg(path)
  return path and path:lower():match("%.svg$") ~= nil
end

local function close(refocus)
  local preview = active
  if not preview then
    return
  end
  active = nil
  if preview.job then
    pcall(vim.fn.jobstop, preview.job)
  end
  if preview.win and api.nvim_win_is_valid(preview.win) then
    api.nvim_win_close(preview.win, true)
  elseif preview.buf and api.nvim_buf_is_valid(preview.buf) then
    api.nvim_buf_delete(preview.buf, { force = true })
  end
  if preview.temp then
    vim.uv.fs_unlink(preview.temp)
  end
  if refocus and preview.source_win and api.nvim_win_is_valid(preview.source_win) then
    api.nvim_set_current_win(preview.source_win)
  end
end

local function preview_source(path)
  local current = normalized(api.nvim_buf_get_name(0))
  if current ~= path or not vim.bo.modified then
    return path
  end

  local temp = vim.fn.tempname() .. ".svg"
  local ok, err = pcall(vim.fn.writefile, api.nvim_buf_get_lines(0, 0, -1, false), temp)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "SVG Preview" })
    return nil
  end
  return temp, temp
end

local function dimensions()
  local width = math.max(24, math.min(140, math.floor(vim.o.columns * 0.9)))
  local height = math.max(8, math.min(48, math.floor((vim.o.lines - 3) * 0.9)))
  width = math.min(width, math.max(12, vim.o.columns - 4))
  height = math.min(height, math.max(6, vim.o.lines - 4))
  return width, height
end

function M.open(path)
  path = normalized(path or api.nvim_buf_get_name(0))
  if
    not is_svg(path) or not (vim.uv.fs_stat(path) or (normalized(api.nvim_buf_get_name(0)) == path and vim.bo.modified))
  then
    vim.notify("Open or select an SVG file first", vim.log.levels.WARN, { title = "SVG Preview" })
    return
  end
  if vim.fn.executable("python3") ~= 1 or vim.fn.executable("rsvg-convert") ~= 1 then
    vim.notify("SVG preview requires python3 and rsvg-convert", vim.log.levels.ERROR, {
      title = "SVG Preview",
    })
    return
  end

  if active and active.path == path and active.win and api.nvim_win_is_valid(active.win) then
    close(true)
    return
  end
  close(false)

  local source, temp = preview_source(path)
  if not source then
    return
  end
  local source_win = api.nvim_get_current_win()
  local width, height = dimensions()
  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " SVG Preview: " .. vim.fs.basename(path) .. " ",
    title_pos = "center",
  })
  active = { buf = buf, path = path, source_win = source_win, temp = temp, win = win }

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"

  local function dismiss()
    close(true)
  end
  local function open_vector()
    close(true)
    local ok, _, err = pcall(vim.ui.open, path)
    if not ok or err then
      vim.notify(tostring(err or "Could not open the SVG viewer"), vim.log.levels.ERROR, { title = "SVG Preview" })
    end
  end
  for _, mode in ipairs({ "n", "t" }) do
    for _, key in ipairs({ "q", "<Esc>", "<C-b>" }) do
      vim.keymap.set(mode, key, dismiss, { buffer = buf, nowait = true, silent = true })
    end
    vim.keymap.set(mode, "v", open_vector, {
      buffer = buf,
      desc = "Open true vector SVG externally",
      nowait = true,
      silent = true,
    })
  end

  local script = vim.fn.stdpath("config") .. "/scripts/svg_preview.py"
  local command = { "python3", script, source, tostring(width), tostring(height) }
  local job
  api.nvim_buf_call(buf, function()
    job = vim.fn.jobstart(command, {
      term = true,
      on_exit = function()
        if active and active.buf == buf and active.temp then
          vim.uv.fs_unlink(active.temp)
          active.temp = nil
        end
      end,
    })
  end)
  if not job or job < 1 then
    close(true)
    vim.notify("Could not start the SVG preview renderer", vim.log.levels.ERROR, { title = "SVG Preview" })
  elseif active and active.buf == buf then
    active.job = job
  end
end

function M.toggle()
  M.open(api.nvim_buf_get_name(0))
end

local function map_buffer(buf)
  vim.keymap.set("n", "<C-b>", M.toggle, {
    buffer = buf,
    desc = "Preview SVG in terminal",
    nowait = true,
    silent = true,
  })
end

function M.setup()
  local group = api.nvim_create_augroup("svg_terminal_preview", { clear = true })
  api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    pattern = { "*.svg", "*.SVG" },
    callback = function(args)
      map_buffer(args.buf)
    end,
    desc = "Enable bounded terminal SVG previews",
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      if active and tonumber(args.match) == active.win then
        close(false)
      end
    end,
    desc = "Clean up terminal SVG previews",
  })

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(buf) and is_svg(api.nvim_buf_get_name(buf)) then
      map_buffer(buf)
    end
  end

  api.nvim_create_user_command("SvgPreview", function(args)
    M.open(args.args ~= "" and args.args or nil)
  end, { complete = "file", desc = "Preview an SVG inside Neovim", force = true, nargs = "?" })
end

return M
