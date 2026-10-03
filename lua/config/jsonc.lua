local M = {}

-- Strip comments without touching strings (URLs, Windows paths, quotes), and
-- preserve byte positions so callers can safely insert into the original file.
function M.strip(raw)
  local out, index, quoted = {}, 1, false
  if raw:sub(1, 3) == "\239\187\191" then
    out[#out + 1], index = "   ", 4
  end
  while index <= #raw do
    local char, pair = raw:sub(index, index), raw:sub(index, index + 1)
    if quoted then
      out[#out + 1] = char
      if char == "\\" then
        index = index + 1
        out[#out + 1] = raw:sub(index, index)
      elseif char == '"' then
        quoted = false
      end
    elseif char == '"' then
      quoted = true
      out[#out + 1] = char
    elseif pair == "//" or pair == "/*" then
      local stop
      if pair == "//" then
        stop = raw:find("\n", index + 2, true) or (#raw + 1)
      else
        local close = raw:find("*/", index + 2, true)
        if not close then
          error("Unterminated JSONC block comment")
        end
        stop = close + 2
      end
      out[#out + 1] = raw:sub(index, stop - 1):gsub("[^\r\n]", " ")
      index = stop - 1
    else
      out[#out + 1] = char
    end
    index = index + 1
  end
  return table.concat(out)
end

function M.decode(raw)
  local clean = M.strip(raw)
  local out, index, quoted = {}, 1, false
  while index <= #clean do
    local char = clean:sub(index, index)
    if quoted then
      out[#out + 1] = char
      if char == "\\" then
        index = index + 1
        out[#out + 1] = clean:sub(index, index)
      elseif char == '"' then
        quoted = false
      end
    elseif char == '"' then
      quoted = true
      out[#out + 1] = char
    elseif char ~= "," or not clean:sub(index + 1):match("^%s*[%]}]") then
      out[#out + 1] = char
    end
    index = index + 1
  end
  return vim.json.decode(table.concat(out))
end

return M
