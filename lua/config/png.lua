local M = {}

local ffi_ok, ffi = pcall(require, "ffi")
local zlib
local zlib_error

local function load_zlib()
  if zlib then
    return zlib
  end
  if zlib_error then
    return nil, zlib_error
  end
  if not ffi_ok then
    zlib_error = "this Neovim build does not provide LuaJIT FFI"
    return nil, zlib_error
  end

  pcall(
    ffi.cdef,
    [[
    int uncompress(
      unsigned char *dest,
      unsigned long *dest_len,
      const unsigned char *source,
      unsigned long source_len
    );
  ]]
  )

  local names
  if vim.fn.has("win32") == 1 then
    names = { "zlib1", "zlib", "libz" }
  elseif vim.uv.os_uname().sysname == "Darwin" then
    names = { "z", "/usr/lib/libz.dylib", "libz" }
  else
    names = { "z", "libz.so.1", "libz" }
  end

  for _, name in ipairs(names) do
    local ok, library = pcall(ffi.load, name)
    if ok then
      zlib = library
      return zlib
    end
  end
  zlib_error = "zlib is unavailable"
  return nil, zlib_error
end

local function big_endian_u32(data, offset)
  local a, b, c, d = data:byte(offset, offset + 3)
  if not d then
    error("incomplete PNG chunk")
  end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local function inflate(data, expected)
  local library, err = load_zlib()
  if not library then
    error(err)
  end

  local output = ffi.new("unsigned char[?]", expected)
  local output_length = ffi.new("unsigned long[1]", expected)
  local input = ffi.new("unsigned char[?]", #data)
  ffi.copy(input, data, #data)
  local code = library.uncompress(output, output_length, input, #data)
  if code ~= 0 or tonumber(output_length[0]) ~= expected then
    error(("could not decompress PNG data (zlib code %d)"):format(code))
  end
  return ffi.string(output, expected)
end

local function paeth(left, above, upper_left)
  local estimate = left + above - upper_left
  local left_distance = math.abs(estimate - left)
  local above_distance = math.abs(estimate - above)
  local corner_distance = math.abs(estimate - upper_left)
  if left_distance <= above_distance and left_distance <= corner_distance then
    return left
  end
  if above_distance <= corner_distance then
    return above
  end
  return upper_left
end

local function composite(red, green, blue, alpha, background)
  if alpha == 255 then
    return { red, green, blue }
  end
  local inverse = 255 - alpha
  return {
    math.floor((red * alpha + background[1] * inverse) / 255),
    math.floor((green * alpha + background[2] * inverse) / 255),
    math.floor((blue * alpha + background[3] * inverse) / 255),
  }
end

---@param data string
---@param background integer[]?
---@return { width: integer, height: integer, pixels: integer[][][] }
function M.decode(data, background)
  background = background or { 26, 27, 38 }
  if type(data) ~= "string" or data:sub(1, 8) ~= "\137PNG\r\n\26\n" then
    error("SVG rasterizer did not return a PNG")
  end

  local width, height, bit_depth, color_type, interlace
  local compressed = {}
  local offset = 9
  while offset + 11 <= #data do
    local length = big_endian_u32(data, offset)
    local kind = data:sub(offset + 4, offset + 7)
    local payload_start = offset + 8
    local payload_end = payload_start + length - 1
    if payload_end + 4 > #data then
      error("incomplete PNG payload")
    end
    local payload = data:sub(payload_start, payload_end)
    offset = payload_end + 5

    if kind == "IHDR" then
      width = big_endian_u32(payload, 1)
      height = big_endian_u32(payload, 5)
      bit_depth, color_type, _, _, interlace = payload:byte(9, 13)
    elseif kind == "IDAT" then
      compressed[#compressed + 1] = payload
    elseif kind == "IEND" then
      break
    end
  end

  local channels = ({ [0] = 1, [2] = 3, [4] = 2, [6] = 4 })[color_type]
  if not width or not height or bit_depth ~= 8 or interlace ~= 0 or not channels then
    error("unsupported PNG output; expected non-interlaced 8-bit RGB/RGBA")
  end
  if width > 2048 or height > 2048 then
    error("PNG dimensions exceed the safe preview limit")
  end

  local stride = width * channels
  local raw = inflate(table.concat(compressed), height * (stride + 1))
  local rows = {}
  local previous = {}
  for index = 1, stride do
    previous[index] = 0
  end

  local position = 1
  for row_index = 1, height do
    local filter_type = raw:byte(position)
    position = position + 1
    local scanline = { raw:byte(position, position + stride - 1) }
    position = position + stride

    for index = 1, stride do
      local left = index > channels and scanline[index - channels] or 0
      local above = previous[index]
      local upper_left = index > channels and previous[index - channels] or 0
      local predictor = 0
      if filter_type == 1 then
        predictor = left
      elseif filter_type == 2 then
        predictor = above
      elseif filter_type == 3 then
        predictor = math.floor((left + above) / 2)
      elseif filter_type == 4 then
        predictor = paeth(left, above, upper_left)
      elseif filter_type ~= 0 then
        error("unsupported PNG scanline filter")
      end
      scanline[index] = (scanline[index] + predictor) % 256
    end

    local row = {}
    for column = 1, width do
      local start = (column - 1) * channels + 1
      local red, green, blue, alpha
      if color_type == 0 then
        red, green, blue, alpha = scanline[start], scanline[start], scanline[start], 255
      elseif color_type == 2 then
        red, green, blue, alpha = scanline[start], scanline[start + 1], scanline[start + 2], 255
      elseif color_type == 4 then
        red, green, blue, alpha = scanline[start], scanline[start], scanline[start], scanline[start + 1]
      else
        red, green, blue, alpha = scanline[start], scanline[start + 1], scanline[start + 2], scanline[start + 3]
      end
      row[column] = composite(red, green, blue, alpha, background)
    end
    rows[row_index] = row
    previous = scanline
  end

  return { width = width, height = height, pixels = rows }
end

local function ppm_token(data, position)
  while position <= #data do
    local byte = data:byte(position)
    if byte == 35 then
      local newline = data:find("\n", position + 1, true)
      position = newline and newline + 1 or #data + 1
    elseif byte == 9 or byte == 10 or byte == 13 or byte == 32 then
      position = position + 1
    else
      break
    end
  end
  local start = position
  while position <= #data do
    local byte = data:byte(position)
    if byte == 9 or byte == 10 or byte == 13 or byte == 32 or byte == 35 then
      break
    end
    position = position + 1
  end
  return data:sub(start, position - 1), position
end

---@param data string
---@return { width: integer, height: integer, pixels: integer[][][] }
function M.decode_ppm(data)
  local magic, position = ppm_token(data, 1)
  local width_text
  width_text, position = ppm_token(data, position)
  local height_text
  height_text, position = ppm_token(data, position)
  local maximum_text
  maximum_text, position = ppm_token(data, position)

  local width = tonumber(width_text)
  local height = tonumber(height_text)
  local maximum = tonumber(maximum_text)
  if magic ~= "P6" or not width or not height or maximum ~= 255 then
    error("unsupported PPM output; expected 8-bit binary RGB")
  end
  if width > 2048 or height > 2048 then
    error("PPM dimensions exceed the safe preview limit")
  end

  if data:byte(position) == 13 and data:byte(position + 1) == 10 then
    position = position + 2
  elseif vim.tbl_contains({ 9, 10, 13, 32 }, data:byte(position)) then
    position = position + 1
  else
    error("invalid PPM header")
  end

  local expected = width * height * 3
  if #data - position + 1 < expected then
    error("incomplete PPM pixel data")
  end
  local rows = {}
  for row = 1, height do
    rows[row] = {}
    for column = 1, width do
      local red, green, blue = data:byte(position, position + 2)
      rows[row][column] = { red, green, blue }
      position = position + 3
    end
  end
  return { width = width, height = height, pixels = rows }
end

function M.available()
  return load_zlib() ~= nil
end

return M
