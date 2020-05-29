let s:placeholder_texts = []

let s:opening = g:miniSnip_opening
let s:closing = g:miniSnip_closing

let s:pattern = '\V' . s:opening . '\.\{-}' . s:closing
let s:final_pattern = '\V' . g:miniSnip_finalOp . '\.\{-}' . g:miniSnip_finalEd

function! miniSnip#trigger(...) abort
  let s:ins = a:0
  silent! unlet! s:snippetfile
  let s:cword = matchstr(getline('.'), '\v\f+%' . col('.') . 'c')
  let s:begcol = virtcol('.')

  let l:dirs = join(s:directories(), ',')
  let l:all = globpath(l:dirs, s:cword.'.snip', 0, 1)

  if len(l:all) > 0
    let s:snippetfile = l:all[0]
    return 1
  endif

  return search(s:pattern . '\|' . s:final_pattern, 'e')
endfunction

function! miniSnip#expand() abort
  if exists('s:snippetfile')
    " Reset placeholder text history (for backrefs)
    let s:placeholder_texts = []
    let s:placeholder_text  = ''

    " Adjust the indentation, use the current line as reference
    let l:ws = matchstr(getline(line('.')), '^\s\+')

    let l:content = readfile(s:snippetfile)

    " Remove description
    if l:content[0] =~ '^'.g:miniSnip_descmark
      call remove(l:content, 0)
    endif

    " Check for delimeters changes
    if l:content[0] =~ '^\V'.g:miniSnip_delimChg
      let l:delims = matchlist(l:content[0], '`\(.\{-}\)` `\(.\{-}\)`')
      if !empty(l:delims)
        let s:opening = l:delims[1]
        let s:closing = l:delims[2]
      endif
      call remove(l:content, 0)
    else " reset delims
      let s:opening = g:miniSnip_opening
      let s:closing = g:miniSnip_closing
    endif

    let s:pattern = '\V' . s:opening . '\.\{-}' . s:closing " apply new/reseted delims

    let l:lns = l:content[:0] + map(l:content[1:], 'empty(v:val) ? v:val : l:ws.v:val') " indent

    " Go to the position at the beginning of the snippet
    execute 'normal! '.(s:begcol - strchars(s:cword)).'|'
    " Delete the snippet
    execute 'normal! '.strchars(s:cword).'"_x'

    if virtcol('.') >= (s:begcol - strchars(s:cword)) " there is something following the snippet
      let l:keepEndOfLine = 1
      let l:endOfLine = strpart(getline(line('.')), (col('.') - 1))
      normal! "_D
    else
      let l:keepEndOfLine = 0
    endif

    " Insert snippet
    execute "normal! a" . l:lns[0]
    if !empty(l:lns[1:])
      execute "normal! a\<CR>"
      for l in l:lns[1:-2]
        execute "normal! i" . l . "\<CR>"
      endfor
      execute "normal! i" . l:lns[-1]
    endif

    if l:keepEndOfLine == 1 " add the end of the line after the snippet
      call append((line('.')), l:endOfLine)
      join!
    endif

    " Go to the end of the last line of the snippet
    let l:last_line_len = len(l:lns[-1]) + s:begcol - strchars(s:cword) - 1
    execute 'normal! '.l:last_line_len.'|'

  else
    " Make sure '< mark is set so the normal command won't error out.
    if getpos("'<") == [0, 0, 0, 0]
      call setpos("'<", getpos('.'))
    endif

    " Save the current placeholder's text so it can be backref
    let l:old_s = @s
    normal! "syv`<
    let s:placeholder_text = @s
    let @s = l:old_s
  endif

  " jump to the first/next placeholder
  call s:selectPlaceholder()
endfunction

function! s:selectPlaceholder() abort
  let l:old_s = @s

  " Get the contents of the placeholder
  "  /e in case the cursor is already on it (e.g. when a snippet begins with a placeholder)
  "  keeppatterns to avoid clobbering the search history/highlighting all the other placeholders
  try
    " gn misbehaves when 'wrapscan' isn't set (see vim's #1683)
    let [l:ws, &wrapscan] = [&wrapscan, 1]
    silent keeppatterns execute 'normal! /' . s:pattern . "/e\<cr>gn\"sy"
    let l:slen = len(@s) " save length of entire placeholder for reference later
    " Remove the start and end delimiters
    let @s=substitute(@s, '\V' . s:opening, '', '')
    let @s=substitute(@s, '\V' . s:closing, '', '')
  catch /E486:/
    " There's no normal placeholder at all
    try
      silent keeppatterns execute 'normal! /' . s:final_pattern . "/e\<cr>gn\"sy"
      let l:slen = len(@s) " save length of entire placeholder for reference later
      " Remove the start and end delimiters
      let @s=substitute(@s, '\V' . g:miniSnip_finalOp, '', '')
      let @s=substitute(@s, '\V' . g:miniSnip_finalEd, '', '')
    catch /E486:/
      " There's no placeholder at all, enter insert mode
      call feedkeys('a', 'n')
      return
    finally
      let &wrapscan = l:ws
    endtry
  finally
    let &wrapscan = l:ws
  endtry

  call add(s:placeholder_texts, s:placeholder_text)

  let l:skip = 0
  if @s =~ '\V\^' . g:miniSnip_evalmark . '\|' . g:miniSnip_refmark
    let l:skip = 1
  elseif @s =~ '\V\^' . g:miniSnip_noskip . g:miniSnip_evalmark
    let @s=substitute(@s, '\V\^' . g:miniSnip_noskip , '', '')
  endif

  " If this placeholder marked as 'evaluate'
  if @s =~ '\V\^' . g:miniSnip_evalmark
    let @s = eval(substitute(@s, '\V\^' . g:miniSnip_evalmark, '', ''))
  endif

  " Substitute in any backrefs
  if @s =~ '\V\^' . g:miniSnip_refmark
    let @s = substitute(@s, '\V\^'.g:miniSnip_refmark.'\(\d\+\)',
          \ "\\=\"\".get(s:placeholder_texts, str2nr(submatch(1)), '').\"\"", 'g')
  endif

  if empty(@s)
    " The placeholder was empty, so just enter insert mode directly
    normal! gv"_d
    call feedkeys(col("'>") - l:slen >= col('$') - 1 ? 'a' : 'i', 'n')
  elseif l:skip == 1
    normal! gv"sp
    let @s = l:old_s
    call s:selectPlaceholder()
  else
    " Paste the placeholder's default value in and enter select mode on it
    execute "normal! gv\"spgv\<C-g>"
  endif

  let @s = l:old_s
endfunction

function! miniSnip#completeFunc(findstart, base) abort
  if a:findstart
    " Locate the start of the word
    let l:line = getline('.')
    let l:start = col('.') - 1
    while l:start > 0 && l:line[l:start - 1] =~ '\a'
      let l:start -= 1
    endwhile

    return l:start
  endif

  " Load all snippets that match.
  let l:dirs = join(s:directories(), ',')
  let l:all = globpath(l:dirs, a:base.'*.snip', 0, 1)
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

" vim: fen sw=2
