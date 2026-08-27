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

-- Russian JCUKEN letters occupy the same physical letter keys on the common
-- Linux, macOS, and Windows layouts. Mapping only non-ASCII output keeps every
-- English punctuation command unchanged when the OS layout is English.
add_alphabet("йцукенгшщзхъфывапролджэячсмитьбю", "qwertyuiop[]asdfghjkl;'zxcvbnm,.")
add_alphabet("ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ", 'QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>')

local system_name = (vim.uv or vim.loop).os_uname().sysname
local russian_variant = vim.g.russian_keyboard_variant or (system_name == "Darwin" and "mac" or "standard")
if russian_variant == "mac" then
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
  if russian_variant == "mac" then
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
    })
  end
end

return M
