" Script's global variables:
"   s:pattern
"   s:pattern_final
"   s:op
"   s:ed
"   s:begcol
"   s:ph_begin
"   s:placeholders_count
"   s:named

let s:pattern  = ""

function! miniSnip#trigger() abort
  let l:cword = matchstr(getline('.'), '\v\f+%' . col('.') . 'c')

  let s:begcol = virtcol('.') - strchars(l:cword)

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

  let s:op = g:miniSnip_opening
  let s:ed = g:miniSnip_closing

  " Check for delimeters changes
  if a:str =~ '^\V'.g:miniSnip_delimChg
    let l:custom = 1
    let l:delims = matchlist(a:str, '\V`\(\.\{-}\)` `\(\.\{-}\)`')
    if !empty(l:delims)
      let s:op = l:delims[1]
      let s:ed = l:delims[2]
    endif
  endif

  " Apply delims
  let s:pattern = '\V' . s:op . '\(\(' . s:ed . '\)\|\(\[^' . g:miniSnip_finalTag . ']\.\{-}' .s:ed . '\)\)'
  let s:pattern_final = '\V' . s:op . g:miniSnip_finalTag . s:ed

  return l:custom
endfunction

function! s:insertFile(snipfile) abort
  let l:content = readfile(a:snipfile)

  " Remove description
  if l:content[0] =~ '^'.g:miniSnip_descmark
    call remove(l:content, 0)
  endif

  " If custom delims were applied, remove line with them
  if s:updatePattern(l:content[0])
    call remove(l:content, 0)
  endif

  " For adjusting the indentation (use the current line as reference)
  let l:ws = matchstr(getline(line('.')), '^\s\+')

  " Delete snippet name
  exec 'normal! "_d'.s:begcol.'|"_x'

  " Insert snippet
  execute "normal! " . (virtcol('.') < s:begcol ? "a" : "i") . l:content[0] . "\<CR>"
  for l in l:content[1:]
    execute "normal! i" . l:ws . l . "\<CR>"
  endfor
  normal! kJ

endfunction

function! s:replaceRefs() abort
  let l:s = getline('.')[s:ph_begin-1 : virtcol('.')-1]
  let s:placeholders_count += 1
  let l:pos = getpos('.')
  silent! execute '%s/\V'.s:op.g:miniSnip_refmark.s:placeholders_count.s:ed.'/'.l:s.'/g'
  if exists("s:named")
    " `s:named` already contains g:miniSnip_named
    silent! execute '%s/\V'.s:op.s:named.s:ed.'/'.l:s.'/g'
    unlet s:named
  endif
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

function! s:findPlaceholder(pat) " from: https://stackoverflow.com/a/8697727/10247460
  let [sl, sc] = searchpos(a:pat, 'w')
  let s:ph_begin = virtcol('.')
  let [el, ec] = searchpos(a:pat, 'cnew')
  let t = map(getline(sl ? sl : -1, el), 'v:val."\n"')
  if len(t) > 0
    let t[0] = t[0][sc-1:]
    let ec -= len(t) == 1 ? sc-1 : 0
    let t[-1] = t[-1][:matchend(t[-1], '.', ec-1)-1]
  end
  return join(t, '')
endfunction

function! s:selectPlaceholder() abort

  let l:s = s:findPlaceholder(s:pattern)

  if !empty(l:s)
    let l:len = strchars(l:s)
    let l:s = l:s[strchars(s:op) : l:len-strchars(s:ed)-1]
  else
    let l:s = s:findPlaceholder(s:pattern_final)
    if !empty(l:s)
      let l:len = strchars(l:s)
      let s:pattern = '' " empty makes nice flag variable
      let l:s = ""
    else
      unlet s:ph_begin
      call feedkeys('a', 'n')
      return
    endif
  endif

  if l:s =~ '\V\^' . g:miniSnip_named
    let s:named = l:s
    let l:s = l:s[1:]
  endif

  let l:skip = l:s =~ '\V\^' . g:miniSnip_evalmark
  let l:s = s:evaluate(l:s)

  " Delete placeholder
  exec 'normal! "_d'.l:len.'l'

  " Choose "append" if placeholder is the last element in a line
  let l:m = virtcol('.') == s:ph_begin - 1 ? 'a' : 'i'

  if empty(l:s) " the placeholder was empty, so just enter insert mode directly
    call feedkeys(l:m, 'n')
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

  let l:dirs = !empty(g:miniSnip_local) ? [ "./" . g:miniSnip_local ] : []

  if empty(g:miniSnip_dirs)
    let l:dirs += map(split(&runtimepath, ","), {_, val -> val."/miniSnip" })
  else
    let l:dirs += g:miniSnip_dirs
  endif

  let l:ft_dirs = []

  for l:dir in l:dirs
    for l:ft in l:filetypes
      let l:d = l:dir . "/" . l:ft
      if isdirectory(l:d)
        call add(l:ft_dirs, l:d)
      endif
    endfor
  endfor

  return l:ft_dirs
endfunction

" --- Completion

function! miniSnip#completeFunc(findstart, base) abort
  if a:findstart
    " Locate the start of the word
    let l:line = getline('.')
    let l:start = virtcol('.') - 1
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
  let l:line = matchstr(getline('.'), '\v\f+%' . col('.') . 'c')
  if l:line is# ' '
    let l:line = ''
  endif
  let l:start = virtcol('.') - len(l:line)

  call complete(l:start, miniSnip#completeFunc(0, l:line))
  return ''
endfunction

function! miniSnip#completeCommand(ArgLead, ...) abort
  let l:dirs = join(s:directories(), ',')
  let l:all = globpath(l:dirs, a:ArgLead.'*.'.g:miniSnip_ext, 0, 1)
  call filter(l:all, {_, path -> filereadable(path)})
  call map(l:all, 'fnamemodify(v:val, ":t:r")')
  call sort(l:all, 'i')
  return l:all
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

" --- Management

function! miniSnip#edit(name) abort
  let l:files = globpath(join(s:directories(), ','), a:name.'.'.g:miniSnip_ext, 0, 1)
  if len(l:files) > 0
    let l:file = l:files[0]
  else
    let l:ft = empty(&ft) ? "all" : &ft
    call mkdir(g:miniSnip_dirs[0]."/".l:ft, 'p')
    let l:file = g:miniSnip_dirs[0]."/".l:ft."/".a:name.".".g:miniSnip_ext
  endif
  exec "vnew ".l:file
endfunction

function! miniSnip#delete(name) abort
  let l:files = globpath(join(s:directories(), ','), a:name.'.'.g:miniSnip_ext, 0, 1)
  if len(l:files) > 0
    call delete(l:files[0])
  endif
endfunction

" vim: fen sw=2
