local M = {}

local pairs_by_character = {}

local function add(from, to)
  if vim.fn.strchars(from) ~= 1 or vim.fn.strchars(to) ~= 1 then
    error(("langmap entries must be one character: %q -> %q"):format(from, to))
  end
  pairs_by_character[from] = to
end

local function add_alphabet(from, to)
  assert(vim.fn.strchars(from) == vim.fn.strchars(to), "langmap alphabets must have the same length")
  for index = 0, vim.fn.strchars(from) - 1 do
    add(vim.fn.strcharpart(from, index, 1), vim.fn.strcharpart(to, index, 1))
  end
end

local system_name = (vim.uv or vim.loop).os_uname().sysname
local russian_variant = vim.g.russian_keyboard_variant
  or vim.env.NVIM_RUSSIAN_LAYOUT
  or (system_name == "Darwin" and "phonetic" or "standard")
assert(vim.tbl_contains({ "phonetic", "mac", "standard" }, russian_variant), "Unknown NVIM_RUSSIAN_LAYOUT")
M.russian_variant = russian_variant
local russian_from, russian_to
if russian_variant == "phonetic" then
  -- Apple's Russian Phonetic, used by the Mac input-source cycle.
  russian_from, russian_to =
    "яшертыуиопюжасдфгчйклзхцвбнмщ", "qwertyuiop[]asdfghjklzxcvbnm`"
else
  russian_from, russian_to =
    "йцукенгшщзхъфывапролджэячсмитьбю", "qwertyuiop[]asdfghjkl;'zxcvbnm,."
end
add_alphabet(russian_from, russian_to)
local shifted = { ["["] = "{", ["]"] = "}", [";"] = ":", ["'"] = '"', [","] = "<", ["."] = ">", ["`"] = "~" }
local russian_upper = russian_to:gsub(".", function(c)
  return shifted[c] or c:upper()
end)
add_alphabet(vim.fn.toupper(russian_from), russian_upper)
if russian_variant == "phonetic" then
  -- Other phonetic layouts differ; select the variant explicitly on that host.
elseif russian_variant == "mac" then
  add("ё", "\\")
  add("Ё", "|")
else
  add("ё", "`")
  add("Ё", "~")
end

-- Standard Arabic (the layout shipped with Neovim). This lets Arabic layout
-- output drive the physical qwerty Vim command underneath it in Normal,
-- Visual, Select, and Operator-pending modes.
local arabic = {
  { "ض", "q" },
  { "ص", "w" },
  { "ث", "e" },
  { "ق", "r" },
  { "ف", "t" },
  { "غ", "y" },
  { "ع", "u" },
  { "ه", "i" },
  { "خ", "o" },
  { "ح", "p" },
  { "ج", "[" },
  { "د", "]" },
  { "ش", "a" },
  { "س", "s" },
  { "ي", "d" },
  { "ب", "f" },
  { "ل", "g" },
  { "ا", "h" },
  { "ت", "j" },
  { "ن", "k" },
  { "م", "l" },
  { "ك", ";" },
  { "ط", "'" },
  { "ئ", "z" },
  { "ء", "x" },
  { "ؤ", "c" },
  { "ر", "v" },
  { "ى", "n" },
  { "ة", "m" },
  { "و", "," },
  { "ز", "." },
  { "ظ", "/" },
  { "ذ", "`" },
  { "َ", "Q" },
  { "ً", "W" },
  { "ُ", "E" },
  { "ٌ", "R" },
  { "إ", "Y" },
  { "‘", "U" },
  { "÷", "I" },
  { "×", "O" },
  { "؛", "P" },
  { "ِ", "A" },
  { "ٍ", "S" },
  { "أ", "H" },
  { "ـ", "J" },
  { "،", "K" },
  { "ْ", "X" },
  { "آ", "N" },
  { "’", "M" },
  { "ّ", "~" },
  { "؟", "?" },
  -- Some OS layouts emit a presentation-form ligature for the physical
  -- b/T/G/B keys instead of the two logical LAM + ALEF codepoints.
  { "ﻻ", "b" },
  { "ﻼ", "b" },
  { "ﻹ", "T" },
  { "ﻺ", "T" },
  { "ﻷ", "G" },
  { "ﻸ", "G" },
  { "ﻵ", "B" },
  { "ﻶ", "B" },
}

for _, pair in ipairs(arabic) do
  add(pair[1], pair[2])
end
add_alphabet("١٢٣٤٥٦٧٨٩٠", "1234567890")
add_alphabet("۱۲۳۴۵۶۷۸۹۰", "1234567890")

local option_escapes = {
  ["\\"] = "\\\\",
  [","] = "\\,",
  [";"] = "\\;",
  ['"'] = '\\"',
  ["|"] = "\\|",
}

local function option_character(character)
  return option_escapes[character] or character
end

function M.option_value()
  local entries = {}
  for from, to in pairs(pairs_by_character) do
    entries[#entries + 1] = option_character(from) .. option_character(to)
  end
  table.sort(entries)
  return table.concat(entries, ",")
end

function M.translate(character)
  return pairs_by_character[character] or character
end

function M.russian_keymap()
  if russian_variant == "phonetic" then
    return nil -- macOS owns phonetic typing; Neovim ships no exact input keymap.
  elseif russian_variant == "mac" then
    return "russian-jcukenmac"
  elseif system_name:match("Windows") then
    return "russian-jcukenwin"
  end
  return "russian-jcuken"
end

function M.setup()
  vim.opt.langremap = false
  vim.opt.langmap = M.option_value()

  -- The standard Arabic layout may emit logical two-codepoint LAM + ALEF
  -- sequences for four physical keys. Raw mappings are resolved before the
  -- per-character langmap, preserving their normal Vim commands.
  for sequence, command in pairs({
    ["لا"] = "b",
    ["لإ"] = "T",
    ["لأ"] = "G",
    ["لآ"] = "B",
  }) do
    vim.keymap.set({ "n", "x", "o" }, sequence, command, {
      desc = "Arabic layout: physical " .. command,
      silent = true,
      remap = true,
    })
  end
  local pending = false
  local function refresh()
    if pending then
      return
    end
    pending = true
    vim.schedule(function()
      pending = false
      M.refresh_aliases()
    end)
  end
  local group = vim.api.nvim_create_augroup("multilingual_mapping_aliases", { clear = true })
  vim.api.nvim_create_autocmd("User", { group = group, pattern = { "VeryLazy", "LazyLoad" }, callback = refresh })
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "LspAttach" }, { group = group, callback = refresh })
end

-- langmap handles built-in commands, but does not reliably resolve translated
-- multi-key user/plugin mappings. Derive aliases from the effective maps,
-- including buffer-local maps, without maintaining another shortcut list.
local alias_prefix = "Layout alias: "
local layouts = { arabic = {}, russian = {} }
for _, pair in ipairs(arabic) do
  if not layouts.arabic[pair[2]] then
    layouts.arabic[pair[2]] = pair[1]
  end
end
for command, sequence in pairs({ b = "لا", T = "لإ", G = "لأ", B = "لآ" }) do
  layouts.arabic[command] = sequence
end
for index = 0, vim.fn.strchars(russian_from) - 1 do
  layouts.russian[russian_to:sub(index + 1, index + 1)] = vim.fn.strcharpart(russian_from, index, 1)
  layouts.russian[russian_upper:sub(index + 1, index + 1)] = vim.fn.strcharpart(vim.fn.toupper(russian_from), index, 1)
end

local function translated(lhs, layout)
  local result, index = {}, 1
  while index <= #lhs do
    local token = lhs:sub(index):match("^<[^>]+>")
    if token then
      result[#result + 1] = token
      index = index + #token
    else
      local c = lhs:sub(index, index)
      result[#result + 1] = layout[c] or c
      index = index + 1
    end
  end
  return table.concat(result)
end

function M.refresh_aliases()
  for _, mode in ipairs({ "n", "x", "o" }) do
    for _, buffer in ipairs({ false, vim.api.nvim_get_current_buf() }) do
      local maps = buffer and vim.api.nvim_buf_get_keymap(buffer, mode) or vim.api.nvim_get_keymap(mode)
      local occupied = {}
      for _, mapping in ipairs(maps) do
        if (mapping.desc or ""):sub(1, #alias_prefix) == alias_prefix then
          pcall(vim.keymap.del, mode, mapping.lhs, buffer and { buffer = buffer } or {})
        else
          occupied[mapping.lhs] = true
        end
      end
      for _, mapping in ipairs(maps) do
        if
          not mapping.lhs:find("[^%z\1-\127]")
          and not mapping.lhs:find("<Plug>", 1, true)
          and (mapping.desc or ""):sub(1, #alias_prefix) ~= alias_prefix
        then
          for _, layout in pairs(layouts) do
            local alias = translated(mapping.lhs, layout)
            if alias ~= mapping.lhs and not occupied[alias] then
              vim.keymap.set(mode, alias, mapping.lhs, {
                remap = true,
                silent = mapping.silent == 1,
                buffer = buffer or nil,
                desc = alias_prefix .. (mapping.desc or mapping.lhs),
              })
              occupied[alias] = true
            end
          end
        end
      end
    end
  end
end

return M
