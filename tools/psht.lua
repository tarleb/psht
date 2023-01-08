--- Pandoc writer for ANSI terminals.
-- This writer uses new features added in pandoc 3, including writer
-- scaffolding and custom writer extensions.
PANDOC_VERSION:must_be_at_least '3.0'

local unpack = unpack or table.unpack
local format = string.format
local layout = pandoc.layout
local empty, cr, concat, blankline, space =
  layout.empty, layout.cr, layout.concat, layout.blankline, layout.space
local hang, nest, prefixed, real_length =
  layout.hang, layout.nest, layout.prefixed, layout.real_length
local to_roman = pandoc.utils.to_roman_numeral
local stringify = pandoc.utils.stringify
local List = pandoc.List

--- Like pandoc.layout.cblock, but adjusted to work with escape sequences.
-- Doesn't play nicely with other blocks though.
local center = function (doc, width)
  local block = doc:render(width)
  local lines = List{}
  for line in block:gmatch('[^\n]*') do
    local escape_chars = 0
    for seq in line:gmatch('\027%[[%d;]*%a') do
      escape_chars = escape_chars + #seq
    end
    local left_spaces = (width - real_length(line) + escape_chars) // 2
    lines:insert(string.rep(' ', left_spaces) .. line)
  end
  return table.concat(lines, '\n')
end

local footnotes

local format_number = {
  Decimal      = function (n) return format("%d", n) end,
  Example      = function (n) return format("%d", n) end,
  DefaultStyle = function (n) return format("%d", n) end,
  LowerAlpha   = function (n) return string.char(96 + (n % 26)) end,
  UpperAlpha   = function (n) return string.char(64 + (n % 26)) end,
  UpperRoman   = function (n) return to_roman(n) end,
  LowerRoman   = function (n) return to_roman(n):lower() end,
}

local list_elements = List{'BulletList', 'OrderedList', 'DefinitionList'}
local function is_tight_list(list)
  if not list_elements:includes(list.tag) then
    return false
  end
  for i, item in ipairs(list.content) do
    if not (#item == 1 and item[1].tag == "Plain") and
       not (#item == 2 and item[1].tag == "Plain" and
            list_elements:includes(item[2].tag)) then
      return false
    end
  end
  return true
end

local unicode_superscript = {
  ['0'] = '⁰', ['1'] = '¹', ['2'] = '²', ['3'] = '³', ['4'] = '⁴',
  ['5'] = '⁵', ['6'] = '⁶', ['7'] = '⁷', ['8'] = '⁸', ['9'] = '⁹',
  ['+'] = '⁺', ['-'] = '⁻', ['='] = '⁼', ['('] = '⁽', [')'] = '⁾',
}

local font_effects = setmetatable(
  {
    -- leading zeros make things symmetric and simplify centering.
    bold       = {'01', '22'},
    faint      = {'02', '22'},
    italic     = {'03', '23'},
    underline  = {'04', '24'},
    underlined = {'04', '24'},
    blink      = {'05', '25'},
    inverse    = {'07', '27'},
    strikeout  = {'09', '29'},
    black      = {'30', '39'},
    red        = {'31', '39'},
    green      = {'32', '39'},
    yellow     = {'33', '39'},
    blue       = {'34', '39'},
    magenta    = {'35', '39'},
    cyan       = {'36', '39'},
    white      = {'37', '39'},
    blackbg    = {'40', '49'},
    redbg      = {'41', '49'},
    greenbg    = {'42', '49'},
    yellowbg   = {'43', '49'},
    bluebg     = {'44', '49'},
    magentabg  = {'45', '49'},
    cyanbg     = {'46', '49'},
    whitebg    = {'47', '49'},
  },
  {
    __index = function (_, key)
     error('Unknown font effect ' .. tostring(key))
    end
  }
)
local function font (effects, b)
  effects = type(effects) == 'table' and effects or {effects}
  local start_codes, stop_codes = List{}, List{}
  for _, effect in ipairs(effects) do
    local start, stop = unpack(font_effects[effect])
    start_codes:insert(start)
    stop_codes:insert(stop)
  end
  return concat{
    format('\027[%sm', table.concat(start_codes, ';')),
    b,
    format('\027[%sm', table.concat(stop_codes, ';')),
  }
end

--- Get the number of terminal lines.
local function term_lines()
  return tonumber(pandoc.pipe('tput', {'lines'}, ''))
end

--- Get the number of terminal lines.
local function term_cols()
  return tonumber(pandoc.pipe('tput', {'cols'}, ''))
end

--- Display with figlet
local function figlet(contents, cols, args)
  cols = cols or term_cols()
  args = args or {}
  return pandoc.pipe(
    'figlet',
    List{'-c', ('-w%d'):format(cols)} .. args,
    stringify(contents)
  )
end

local function ensure_doc(d)
  return pandoc.utils.type(d) == 'Doc' and d or layout.literal(d)
end

local function ensure_string(s)
  return type(content) == 'string' and s or tostring(s)
end

local function hcenter(content, cols)
  cols = cols or term_cols()
  local strcontent = ensure_string(content)
  local maxlen = 0
  for line in strcontent:gsub('\027[[0-9;]*m', ''):gmatch('[^\n]*') do
    maxlen = math.max(maxlen, #line)
  end
  return nest(content, (cols - maxlen) // 2)
end

--- Center vertically
local function vcenter(content, lines)
  lines = lines or term_lines()
  content = ensure_string(content)
  local height = 1
  for _ in content:gmatch '\n' do
    height = height + 1
  end
  return ' ' .. string.rep('\n', (lines - height) // 2) .. content
end

--- Supported writer extensions
Extensions = {
  italic = false,
  unicode = false,
  color = true,
}


local ANSI = {
  Block = {},
  Inline = {},
}
local inlines = function (inlns, opts)
  local opts = opts or PANDOC_WRITER_OPTIONS
  local docs, cur = List{}, nil
  for i, inline in ipairs(inlns) do
    cur = ANSI.Inline[inline.t](inline, opts)
    if type(cur) == 'table' then
      docs:extend(cur)
    elseif type(cur) == 'string' then
      docs:insert(cur)
    elseif type(cur) == 'userdata' then -- Doc object
      docs:insert(cur)
    else
      local msg = "Unexpected result '%s' while rendering '%s'"
      error(msg:format(tostring(cur), inline.t))
    end
  end
  return concat(docs, sep)
end

local blocks = function (blks, sep, opts)
  local sep = sep or blankline
  local opts = opts or PANDOC_WRITER_OPTIONS
  local docs, cur = List{}, nil
  for i, block in ipairs(blks) do
    cur = ANSI.Block[block.t](block, opts)
    if type(cur) == 'table' then
      docs:extend(cur)
    elseif type(cur) == 'string' then
      docs:insert(cur)
    elseif type(cur) == 'userdata' then -- Doc object
      docs:insert(cur)
    else
      local msg = "Unexpected result '%s' while rendering '%s'"
      error(msg:format(tostring(cur), block.t))
    end
  end
  return concat(docs, sep)
end

ANSI.Pandoc = function (doc, opts)
  footnotes = List{}
  local d = blocks(doc.blocks, blankline)
  local notes = footnotes:map(function (note, i)
      local prefix = opts.extensions:includes 'unicode'
        and tostring(i):gsub('.', unicode_superscript) .. space
        or concat{format("[^%d]:", i), space}
      return hang(blocks(footnotes[i], blankline), 4, prefix)
  end)
  return concat{d, blankline, concat(notes, blankline)}
end

ANSI.Block.Para = function(el)
  return inlines(el.content)
end

ANSI.Block.Plain = function(el)
  return inlines(el.content)
end

ANSI.Block.BlockQuote = function(el)
  return prefixed(nest(blocks(el.content, blankline), 1), ">")
end

ANSI.Block.Header = function(h, opts)
  local texts
  if h.level < opts.slide_level then
    local centered = hcenter(inlines(h.content), opts.columns)
    return font({'bold'}, vcenter(centered))
  elseif h.level <= 1 then
    return center(
      font({'bold', 'underline'}, inlines(h.content)),
      opts.columns
    )
  elseif h.level <= 2 then
    return center(
      font({'bold'}, inlines(h.content)),
      opts.columns
    )
  elseif h.level <= 3 then
    return font({'bold', 'underline'}, inlines(h.content))
  elseif h.level <= 4 then
    return font('faint', inlines(h.content))
  else
    return font('bold', inlines(h.content))
  end
end

ANSI.Block.Div = function(div, opts)
  if div.classes:includes 'note' then
    -- omit notes
    return empty
  elseif div.classes:includes 'center' or div.classes:includes 'centered' then
    local content = blocks(div.content, blankline)
    local width = div.attributes.width or content:offset()
    local centered = nest(
      content:render(),
      (opts.columns - width) // 2
    )
    return {cr, centered, blankline}
  else
    return {cr, blocks(div.content, blankline), blankline}
  end
end

ANSI.Block.RawBlock = function(el)
  return empty
end

ANSI.Block.Null = function(el)
  return empty
end

ANSI.Block.LineBlock = function(el)
  return concat(el.content:map(inlines), cr)
end

ANSI.Block.Table = function(el)
  return 'table omitted'
end

ANSI.Block.DefinitionList = function(el)
  local function render_def (def)
    return concat{blankline, blocks(def), blankline}
  end
  local function render_item(item)
    local term, defs = unpack(item)
    local inner = concat(defs:map(render_def))
    return hang(inner, 2, concat{ inlines{pandoc.Strong(term)}, cr })
  end
  return concat(el.content:map(render_item), blankline)
end

ANSI.Block.BulletList = function(ul, opts)
  local bullet = opts.extensions:includes 'unicode' and '• ' or '- '
  bullet = font('red', bullet)
  local function render_item (item)
    return hang(blocks(item, blankline), 2, bullet):nest(2)
  end
  local sep = is_tight_list(ul) and cr or blankline
  return cr .. concat(ul.content:map(render_item), sep)
end

ANSI.Block.OrderedList = function(ol)
  local result = List{cr}
  local num = ol.start
  local maxnum = num + #ol.content
  local width =
    (List{'UpperRoman', 'LowerRoman'}:includes(ol.style) and 5) or
    (maxnum > 9 and 4) or
    3
  local delimfmt =
    (ol.delimiter == pandoc.OneParen and "%s)") or
    (ol.delimiter == pandoc.TwoParens and "(%s)") or
    "%s."
  local num_formatter = format_number[ol.style]
  for i, item in ipairs(ol.content) do
    local barenum = num_formatter(num)
    local numstr = format(delimfmt, barenum)
    local sps = width - #numstr
    local numsp = (sps < 1) and space or string.rep(" ", sps)
    result:insert(
      hang(
        blocks(ol.content[i], blankline),
        width,
        font('red', concat{numstr,numsp})
      ):nest(2)
    )
    num = num + 1
  end
  local sep = is_tight_list(ol) and cr or blankline
  return concat(result, sep)
end

ANSI.Block.CodeBlock = function(cb)
  return nest(concat { cr, cb.text, cr }, 4)
end

ANSI.Block.HorizontalRule = function(_, opts)
  local dinkus = opts.extensions:includes 'unicode'
    and '⁂'
    or '* * * * *'
  return cblock(dinkus, opts.columns)
end

ANSI.Inline.Str = function(el)
  return el.text
end

ANSI.Inline.Space = function ()
  return space
end

ANSI.Inline.SoftBreak = function(el, opts)
  return opts.wrap_text == "wrap-preserve" and cr or space
end

ANSI.Inline.LineBreak = cr

ANSI.Inline.RawInline = function()
  return empty
end

ANSI.Inline.Code = function(code)
  return font('bold', code.text)
end

ANSI.Inline.Emph = function(em, opts)
  local color = opts.extensions:includes 'color' and 'green' or nil
  return opts.extensions:includes 'italic'
    and font({'italic', color}, inlines(em.content))
    or font({'underline', color}, inlines(em.content))
end

ANSI.Inline.Strong = function(strong, opts)
  local color = opts.extensions:includes 'color' and 'red' or nil
  return font({'bold', color}, inlines(strong.content))
end

ANSI.Inline.Strikeout = function(el)
  return font('strikeout', inlines(el.content))
end

ANSI.Inline.Subscript = function(el)
  return { '~', inlines(el.content), '~'}
end

ANSI.Inline.Superscript = function(el, opts)
  local all_unicode = true
  local function tosuperscript (str)
    return str.text:gsub('.', function (c)
        local uc_char = unicode_superscript[c]
        if not uc_char then all_unicode = false end
        return uc_char
    end)
  end
  local result = el:walk {Str = tosuperscript}
  if opts.extensions:includes 'unicode' and all_unicode then
    return inlines(result.content)
  else
    return { '^', inlines(el.content), '^'}
  end
end

ANSI.Inline.SmallCaps = function(el)
  local function to_upper (str)
    return pandoc.text.upper(str.text)
  end
  return inlines(el.content:walk {Str = to_upper})
end

ANSI.Inline.Underline = function(u)
  return font('underline', inlines(u.content))
end

ANSI.Inline.Cite = function(el)
  return inlines(el.content)
end

ANSI.Inline.Math = function(el)
  local marker = el.mathtype == 'DisplayMath' and '$$' or '$'
  return { marker, Inline.Code(el) }
end

ANSI.Inline.Span = function(span)
  if span.classes:includes 'mark' then
    return font({'magentabg'}, inlines(span.content))
  end
  return inlines(span.content)
end

ANSI.Inline.Link = function(link)
  if link.target:match '^%#' then
    -- drop internal links
    return inlines(link.content)
  elseif link.target == stringify(link.content) then
    -- drop autolinks
    return inlines(link.content)
  else
    return inlines(link.content .. {pandoc.Note(pandoc.Plain{link.target})})
  end
end

ANSI.Inline.Image = function(el)
  return inlines(el.caption)
end

ANSI.Inline.Quoted = function(q)
  return q.quotetype == pandoc.DoubleQuote
    and inlines(q.content):double_quotes()
    or  inlines(q.content):quotes()
end

ANSI.Inline.Note = function(note, opts)
  footnotes:insert(note.content)
  local num = #footnotes
  return opts.extensions:includes 'unicode'
    and tostring(num):gsub('[%d]', unicode_superscript)
    or format("[^%d]", num)
end

local write_title_slide = function (meta)
  local lines = meta.lines or term_lines() or 24
  local cols = meta.cols or 80
  local author = inlines(meta.author)
  local title = meta.title or ''
  local titlestr = stringify(title)
  if titlestr ~= '' then
    title = figlet(titlestr, cols, {'-f', 'big'})
  end
  title = vcenter(font('magenta', title):render(), lines)
  local filename = ('_slides/000-%s'):format(titlestr)
  local fh = io.open(filename, 'w')
  fh:write('#!/usr/bin/tail -n+2\n')
  fh:write(font('italic', author):render())
  fh:write(title)
  fh:close()
  return filename
end

Writer = function (doc, opts)
  PANDOC_WRITER_OPTIONS = opts
  opts.slide_level = opts.slide_level or pandoc.structure.slide_level(doc)
  doc.blocks = pandoc.structure.make_sections(doc, opts)
  local split_opts = {
    path_template = '_slides/%n-%i.sh',
    chunk_level = opts.slide_level,
  }
  local chunked = pandoc.structure.split_into_chunks(doc, split_opts)
  local files = List{}
  for i, chunk in ipairs(chunked.chunks) do
    local fh = io.open(chunk.path, 'w')
    fh:write('#!/usr/bin/tail -n+2\n')
    fh:write(
      ANSI.Pandoc(pandoc.Pandoc(chunk.contents), opts)
      :render(opts.columns)
    )
    fh:close()
    files:insert(chunk.path)
  end

  local title_slide_name = write_title_slide(doc.meta)
  files:insert(1, title_slide_name)

  -- make slides executable
  files:map(function (fp)
      os.execute(('chmod +x "%s"'):format(fp))
  end)

  return 'The following slides were created:\n' ..
    table.concat(files, '\n')
end

