local M = {}

local api = vim.api
local raster = require("config.png")
local active

local BACKGROUND = { 26, 27, 38 }
local BRAILLE_WEIGHTS = { 1, 8, 2, 16, 4, 32, 64, 128 }
local MAX_SOURCE_BYTES = 16 * 1024 * 1024

local function normalized(path)
  if not path or path == "" then
    return nil
  end
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function is_svg(path)
  return path and path:lower():match("%.svg$") ~= nil
end

local function remove_temp(preview)
  if preview and preview.temp then
    vim.uv.fs_unlink(preview.temp)
    preview.temp = nil
  end
end

local function close(refocus)
  local preview = active
  if not preview then
    return
  end
  active = nil
  if preview.process then
    pcall(preview.process.kill, preview.process, 15)
  end
  if preview.win and api.nvim_win_is_valid(preview.win) then
    api.nvim_win_close(preview.win, true)
  elseif preview.buf and api.nvim_buf_is_valid(preview.buf) then
    api.nvim_buf_delete(preview.buf, { force = true })
  end
  remove_temp(preview)
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
  local width = math.max(24, math.floor(vim.o.columns * 0.96))
  local height = math.max(8, math.floor((vim.o.lines - 2) * 0.94))
  width = math.min(220, width, math.max(12, vim.o.columns - 2))
  height = math.min(70, height, math.max(6, vim.o.lines - 3))
  return width, height
end

local renderer_specs = {
  {
    name = "rsvg-convert",
    format = "png",
    needs_zlib = true,
    command = function(executable, path, width, height)
      return {
        executable,
        "--format",
        "png",
        "--width",
        tostring(width),
        "--height",
        tostring(height),
        "--keep-aspect-ratio",
        "--background-color",
        "#1a1b26",
        path,
      }
    end,
  },
  {
    name = "magick",
    format = "ppm",
    command = function(executable, path, width, height)
      local size = ("%dx%d"):format(width, height)
      return {
        executable,
        path,
        "-background",
        "#1a1b26",
        "-alpha",
        "remove",
        "-alpha",
        "off",
        "-depth",
        "8",
        "-resize",
        size,
        "-gravity",
        "center",
        "-extent",
        size,
        "ppm:-",
      }
    end,
  },
  {
    name = "convert",
    format = "ppm",
    command = function(executable, path, width, height)
      local size = ("%dx%d"):format(width, height)
      return {
        executable,
        path,
        "-background",
        "#1a1b26",
        "-alpha",
        "remove",
        "-alpha",
        "off",
        "-depth",
        "8",
        "-resize",
        size,
        "-gravity",
        "center",
        "-extent",
        size,
        "ppm:-",
      }
    end,
  },
  {
    name = "inkscape",
    format = "png",
    needs_zlib = true,
    command = function(executable, path, width, height)
      return {
        executable,
        path,
        "--export-type=png",
        "--export-filename=-",
        "--export-width=" .. width,
        "--export-height=" .. height,
      }
    end,
  },
}

function M.renderer_command(path, width, height)
  for _, spec in ipairs(renderer_specs) do
    local executable = vim.fn.exepath(spec.name)
    local is_windows_system_convert = vim.fn.has("win32") == 1 and spec.name == "convert"
    if not is_windows_system_convert and executable ~= "" and (not spec.needs_zlib or raster.available()) then
      return spec.command(executable, path, width, height), spec.format, spec.name
    end
  end
end

local function canvas(image, width, height)
  local result = {}
  for row = 1, height do
    result[row] = {}
    for column = 1, width do
      result[row][column] = BACKGROUND
    end
  end

  local left = math.max(0, math.floor((width - image.width) / 2))
  local top = math.max(0, math.floor((height - image.height) / 2))
  for row = 1, math.min(image.height, height) do
    for column = 1, math.min(image.width, width) do
      result[top + row][left + column] = image.pixels[row][column]
    end
  end
  return result
end

local function color(value)
  return {
    math.min(255, math.floor(value[1] / 4) * 4),
    math.min(255, math.floor(value[2] / 4) * 4),
    math.min(255, math.floor(value[3] / 4) * 4),
  }
end

local function same_color(left, right)
  return left and right and left[1] == right[1] and left[2] == right[2] and left[3] == right[3]
end

local function distance(left, right)
  local red = left[1] - right[1]
  local green = left[2] - right[2]
  local blue = left[3] - right[3]
  return red * red + green * green + blue * blue
end

local function average(values)
  local red, green, blue = 0, 0, 0
  for _, value in ipairs(values) do
    red = red + value[1]
    green = green + value[2]
    blue = blue + value[3]
  end
  return {
    math.floor(red / #values),
    math.floor(green / #values),
    math.floor(blue / #values),
  }
end

local function bit_count(value)
  local count = 0
  while value > 0 do
    count = count + value % 2
    value = math.floor(value / 2)
  end
  return count
end

local function braille(mask)
  local codepoint = 0x2800 + mask
  return string.char(
    0xE0 + math.floor(codepoint / 0x1000),
    0x80 + math.floor(codepoint / 0x40) % 0x40,
    0x80 + codepoint % 0x40
  )
end

local function braille_cell(pixels)
  local foreground = pixels[1]
  local background = pixels[2]
  for index = 2, #pixels do
    if distance(foreground, pixels[index]) > distance(foreground, background) then
      background = pixels[index]
    end
  end

  if distance(foreground, background) < 36 then
    local uniform = color(average(pixels))
    return " ", uniform, uniform
  end

  local assignments = {}
  for _ = 1, 2 do
    local foreground_group = {}
    local background_group = {}
    for index, pixel in ipairs(pixels) do
      assignments[index] = distance(pixel, foreground) <= distance(pixel, background)
      local group = assignments[index] and foreground_group or background_group
      group[#group + 1] = pixel
    end
    if #foreground_group > 0 then
      foreground = average(foreground_group)
    end
    if #background_group > 0 then
      background = average(background_group)
    end
  end

  local mask = 0
  for index, selected in ipairs(assignments) do
    if selected then
      mask = mask + BRAILLE_WEIGHTS[index]
    end
  end
  if bit_count(mask) > 4 then
    mask = 255 - mask
    foreground, background = background, foreground
  end
  return braille(mask), color(foreground), color(background)
end

function M.render_ansi(image, rows)
  local output = { "\27[?25l\27[2J" }
  local columns = math.floor(#image[1] / 2)
  for row = 1, rows do
    output[#output + 1] = ("\27[%d;1H"):format(row)
    local foreground
    local background
    local top = (row - 1) * 4 + 1
    for column = 1, columns do
      local left = (column - 1) * 2 + 1
      local character, next_foreground, next_background = braille_cell({
        image[top][left],
        image[top][left + 1],
        image[top + 1][left],
        image[top + 1][left + 1],
        image[top + 2][left],
        image[top + 2][left + 1],
        image[top + 3][left],
        image[top + 3][left + 1],
      })
      if not same_color(next_foreground, foreground) then
        output[#output + 1] = ("\27[38;2;%d;%d;%dm"):format(next_foreground[1], next_foreground[2], next_foreground[3])
        foreground = next_foreground
      end
      if not same_color(next_background, background) then
        output[#output + 1] = ("\27[48;2;%d;%d;%dm"):format(next_background[1], next_background[2], next_background[3])
        background = next_background
      end
      output[#output + 1] = character
    end
    output[#output + 1] = "\27[0m"
  end
  output[#output + 1] = "\27[?25h"
  return table.concat(output)
end

local function decode(data, format)
  if format == "ppm" then
    return raster.decode_ppm(data)
  end
  return raster.decode(data, BACKGROUND)
end

local function show_error(preview, message)
  if active ~= preview or not api.nvim_buf_is_valid(preview.buf) then
    return
  end
  local text = tostring(message):gsub("[%z\1-\8\11\12\14-\31]", " ")
  api.nvim_chan_send(preview.channel, "\27[2J\27[H\27[31mSVG preview failed:\27[0m " .. text)
end

function M.open(path)
  path = normalized(path or api.nvim_buf_get_name(0))
  local current = normalized(api.nvim_buf_get_name(0))
  local stat = path and vim.uv.fs_stat(path)
  if not is_svg(path) or not (stat or (current == path and vim.bo.modified)) then
    vim.notify("Open or select an SVG file first", vim.log.levels.WARN, { title = "SVG Preview" })
    return
  end
  if stat and stat.size > MAX_SOURCE_BYTES then
    vim.notify("SVG preview is limited to 16 MB source files", vim.log.levels.ERROR, { title = "SVG Preview" })
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
  -- Braille provides a 2x4 pixel grid in every terminal cell.
  local pixel_width, pixel_height = width * 2, height * 4
  local command, format, renderer = M.renderer_command(source, pixel_width, pixel_height)
  if not command then
    remove_temp({ temp = temp })
    vim.notify("SVG preview requires rsvg-convert, ImageMagick, or Inkscape", vim.log.levels.ERROR, {
      title = "SVG Preview",
    })
    return
  end

  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = (" SVG Preview (%s): %s "):format(renderer, vim.fs.basename(path)),
    title_pos = "center",
  })
  local channel = api.nvim_open_term(buf, {})
  local preview = {
    buf = buf,
    channel = channel,
    path = path,
    source_win = source_win,
    temp = temp,
    win = win,
  }
  active = preview

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

  api.nvim_chan_send(channel, ("\27[2J\27[HRendering %dx%d SVG samples with Lua…"):format(pixel_width, pixel_height))
  preview.process = vim.system(command, { text = false, timeout = 12000 }, function(result)
    vim.schedule(function()
      remove_temp(preview)
      if active ~= preview then
        return
      end
      if result.code ~= 0 then
        local message = result.stderr and result.stderr ~= "" and result.stderr
          or "rasterizer exited with code " .. result.code
        show_error(preview, message)
        return
      end
      local ok, decoded = pcall(decode, result.stdout, format)
      if not ok then
        show_error(preview, decoded)
        return
      end
      local ok_render, output = pcall(M.render_ansi, canvas(decoded, pixel_width, pixel_height), height)
      if not ok_render then
        show_error(preview, output)
        return
      end
      if active == preview and api.nvim_buf_is_valid(buf) then
        api.nvim_chan_send(channel, output)
      end
    end)
  end)
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
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    pattern = { "*.svg", "*.SVG" },
    callback = function(args)
      map_buffer(args.buf)
    end,
    desc = "Enable high-resolution Lua SVG previews",
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      if active and tonumber(args.match) == active.win then
        close(false)
      end
    end,
    desc = "Clean up Lua SVG previews",
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
