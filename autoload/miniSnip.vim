" Script's global variables:
"   s:pattern
"   s:pattern_final
"   s:op
"   s:ed
"   s:begcol
"   s:ph_begin
"   s:placeholders_count

let s:pattern  = ""

function! miniSnip#trigger() abort
  let l:cword = matchstr(getline('.'), '\v\f+%' . col('.') . 'c')

  let s:begcol = col('.') - len(l:cword)

  let l:files = globpath(join(s:directories(), ','), l:cword.'.'.g:miniSnip_ext, 0, 1)

  let l:file = "''"
  if len(l:files) > 0
    let l:file = "'".l:files[0]."'"
  elseif empty(s:pattern)
    return eval('"' . escape(g:miniSnip_trigger, '\"<') . '"')
  endif

  return "\<Esc>:call miniSnip#expand(" . l:file . ")\<CR>"
endfunction

function! s:updatePattern(str) abort
  let l:custom = 0

  " Check for delimeters changes
  if a:str =~ '^\V'.g:miniSnip_delimChg
    let l:custom = 1
    let l:delims = matchlist(a:str, "\v`(.{-})` `(.{-})`")
    if !empty(l:delims)
      let s:op = l:delims[1]
      let s:ed = l:delims[2]
    endif
  else " reset delims
    let s:op = g:miniSnip_opening
    let s:ed = g:miniSnip_closing
  endif

  " Apply delims
  let s:pattern = '\V\(' . s:op . '\[^' . g:miniSnip_finalTag . ']\{-}' . s:ed . '\)'
  let s:pattern_final = '\V\(' . s:op . g:miniSnip_finalTag . s:ed . '\)'

  return l:custom
endfunction

function! s:insertFile(snipfile) abort
  " Adjust the indentation, use the current line as reference
  let l:ws = matchstr(getline(line('.')), '^\s\+')

  let l:content = readfile(a:snipfile)

  " Remove description
  if l:content[0] =~ '^'.g:miniSnip_descmark
    call remove(l:content, 0)
  endif

  " If custom delims were applied, remove line with them
  if s:updatePattern(l:content[0])
    call remove(l:content, 0)
  endif

  let l:lns = l:content[:0] + map(l:content[1:], 'empty(v:val) ? v:val : l:ws.v:val') " indent

  " Delete snippet name
  exec 'normal! "_d'.s:begcol.'|"_x'

  if virtcol('.') >= s:begcol " there is something following the snippet
    let l:endOfLine = strpart(getline('.'), col('.')-1)
    normal! "_D
  endif

  " Insert snippet
  for l in l:lns
    execute "normal! a" . l . "\<CR>"
  endfor " and then remove last new (blank) line
  normal! "_dd

  if line('.') != line('$') " get back to last line of snippet
    normal! k
  endif

  if exists("l:endOfLine") " add the end of the line after the snippet
    call append((line('.')), l:endOfLine)
    join!
  endif

  " Go to the end of the last line of the snippet
  let l:last_line_len = len(l:lns[-1]) + s:begcol - 1
  execute 'normal! '.l:last_line_len.'|'

endfunction

function! s:replaceRefs() abort
  let l:s = getline('.')[s:ph_begin-1 : col('.')-1]
  let s:placeholders_count += 1
  let l:pos = getpos('.')
  silent! execute '%s/\V'.s:op.g:miniSnip_refmark.s:placeholders_count.s:ed.'/'.l:s.'/g'
  call setpos('.', l:pos)
  unlet s:ph_begin
endfunction

function! miniSnip#expand(snipfile) abort
  if !empty(a:snipfile)
    let s:placeholders_count = 0 " reset/init placeholder count (for refs)
    if exists("s:ph_begin") | unlet s:ph_begin | endif
    call s:insertFile(a:snipfile)
  endif

  if exists("s:ph_begin")
    call s:replaceRefs()
  endif

  call s:selectPlaceholder() " jump to the first/next placeholder
endfunction

function! s:evaluate(str) abort
  if a:str =~ '\V\^' . g:miniSnip_evalmark
    return eval(a:str[1:])
  elseif a:str =~ '\V\^' . g:miniSnip_noskip . g:miniSnip_evalmark
    return eval(a:str[2:])
  endif
  return a:str
endfunction

function! s:selectPlaceholder() abort
  let s:ph_begin = searchpos(s:pattern, 'pw')[1]

  let l:s = ""

  if s:ph_begin
    let l:ph_body_end = searchpos(s:pattern, 'cepwz')[1] - 1 - len(s:ed)
    let l:s = getline('.')[s:ph_begin-1+len(s:op) : l:ph_body_end]
  else
    let s:pattern = '' " empty makes nice flag variable
    let s:ph_begin = searchpos(s:pattern_final, 'pw')[1]
    if s:ph_begin
      call searchpos(s:pattern_final, 'cepwz')
    else
      unlet s:ph_begin
      call feedkeys('a', 'n')
      return
    endif
  endif

  let l:skip = l:s =~ '\V\^' . g:miniSnip_evalmark
  let l:s = s:evaluate(l:s)

  " Delete placeholder
  exec 'normal! "_d'.s:ph_begin.'|"_x'

  " Choose "append" if placeholder is the last element in a line
  let l:m = col('.') == s:ph_begin - 1 ? 'a' : 'i'

  if empty(l:s) " the placeholder was empty, so just enter insert mode directly
    startinsert
    if l:m == 'a'
      call feedkeys("\<Right>", 'i')
    endif
  elseif l:skip
    " Placeholder was evaluated and isn't marked 'noskip', so replace references and go to next
    exec 'normal! ' . l:m . l:s
    call s:replaceRefs()
    call s:selectPlaceholder()
  else " paste the placeholder's default value in and enter select mode on it
    exec 'normal! '. l:m . l:s . "\<Esc>v" . s:ph_begin . "|o\<C-g>"
  endif
endfunction

function! s:directories() abort
  let l:filetypes = []

  if !empty(&ft)
    let l:filetypes = [ &ft ]
    if has_key(g:miniSnip_extends, &ft)
      let l:filetypes += g:miniSnip_extends[&ft]
    endif
  endif

  let l:filetypes += [ "all" ]

  let l:dirs = []

  for l:dir in g:miniSnip_dirs
    let l:dirs += map(l:filetypes, {_, val -> l:dir.'/'.val})
  endfor

  return l:dirs
endfunction

" --- Completion

function! miniSnip#completeFunc(findstart, base) abort
  if a:findstart
    " Locate the start of the word
    let l:line = getline('.')
    let l:start = col('.') - 1
    while l:start > 0 && l:line[l:start - 1] =~ '\f'
      let l:start -= 1
    endwhile

    return l:start
  endif

  " Load all snippets that match.
  let l:dirs = join(s:directories(), ',')
  let l:all = globpath(l:dirs, a:base.'*.'.g:miniSnip_ext, 0, 1)
  call filter(l:all, {_, path -> filereadable(path)})
  call map(l:all, funcref('s:buildComp'))
  call sort(l:all, 'i')

  return l:all
endfunction

function! miniSnip#completeMapping() abort
  " Locate the start of the word
  let l:line = getline('.')
  let l:start = col('.') - 1
  while l:start > 0 && l:line[l:start - 1] =~? '\a'
    let l:start -= 1
  endwhile
  let l:base = l:line[l:start : col('.')-1]
  if l:base is# ' '
    let l:base = ''
  endif

  call complete(l:start + 1, miniSnip#completeFunc(0, l:base))
  return ''
endfunction

function! s:buildComp(_, path) abort
  let l:name = fnamemodify(a:path, ':t:r')
  let l:content = readfile(a:path)
  let l:description = ""

  if l:content[0] =~ '^'.g:miniSnip_descmark
    let l:description = substitute(l:content[0], '^'.g:miniSnip_descmark.'\s\?', '', '')
  endif

  return {
        \ 'word':  l:name,
        \ 'menu':  l:description,
        \ 'info':  join(l:content, "\n"),
        \ 'kind':  's',
        \ }
endfunction

" vim: fen sw=2
