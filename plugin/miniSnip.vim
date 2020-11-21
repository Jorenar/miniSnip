" miniSnip - lightweight and minimal snippet plugin
" Maintainer:  Jorengarenar <https://joren.ga>

if exists('g:loaded_miniSnip') | finish | endif
let s:cpo_save = &cpo | set cpo&vim

let g:miniSnip_dirs     = get(g:, 'miniSnip_dirs', [])
let g:miniSnip_trigger  = get(g:, 'miniSnip_trigger', '<Tab>')
let g:miniSnip_complkey = get(g:, 'miniSnip_complkey', '<C-x><C-u>')
let g:miniSnip_extends  = get(g:, 'miniSnip_extends', {})
let g:miniSnip_ext      = get(g:, 'miniSnip_ext', 'snip')
let g:miniSnip_local    = get(g:, 'miniSnip_local', ".miniSnip")

let g:miniSnip_delimChg = get(g:, 'miniSnip_delimChg', '$' )
let g:miniSnip_descmark = get(g:, 'miniSnip_descmark', '?' )
let g:miniSnip_opening  = get(g:, 'miniSnip_opening',  '<{')
let g:miniSnip_closing  = get(g:, 'miniSnip_closing' , '}>')
let g:miniSnip_refmark  = get(g:, 'miniSnip_refmark',  '~' )
let g:miniSnip_evalmark = get(g:, 'miniSnip_evalmark', '!' )
let g:miniSnip_finalTag = get(g:, 'miniSnip_finalTag', '+' )
let g:miniSnip_noskip   = get(g:, 'miniSnip_noskip',   '`' )
let g:miniSnip_named    = get(g:, 'miniSnip_named',    '@' )

inoremap <silent> <script> <expr> <Plug>(miniSnip) miniSnip#trigger()
snoremap <silent> <script> <expr> <Plug>(miniSnip) miniSnip#trigger()

if !empty(g:miniSnip_trigger)
  execute "imap <unique> ".g:miniSnip_trigger." <Plug>(miniSnip)"
  execute "smap <unique> ".g:miniSnip_trigger." <Plug>(miniSnip)"
endif

if g:miniSnip_complkey == '<C-x><C-u>'
  set completefunc=miniSnip#completeFunc
elseif !empty(g:miniSnip_complkey)
  execute 'inoremap <expr> '.g:miniSnip_complkey
        \ .' pumvisible() ? "\<C-n>" : "\<C-r>=miniSnip#completeMapping()\<CR>"'
endif

augroup miniSnip
  au!
  execute "au BufRead,BufNewFile *.".g:miniSnip_ext." setf snip"
  au FileType snip setlocal noexpandtab
  au FileType snip exec "inoremap <buffer> ".g:miniSnip_trigger." ".g:miniSnip_trigger
  au FileType snip exec "snoremap <buffer> ".g:miniSnip_trigger." ".g:miniSnip_trigger
  au FileType snip exec "syntax match Comment /^".g:miniSnip_descmark.".*/"
  au FileType snip exec "syntax match Comment /^".g:miniSnip_delimChg.".*/"
  au FileType snip exec "syntax match Keyword /" . g:miniSnip_opening . "/"
  au FileType snip exec "syntax match Keyword /" . g:miniSnip_closing . "/"
augroup END

command -nargs=1 -complete=customlist,miniSnip#completeCommand MiniSnip call miniSnip#edit("<args>")
command -nargs=1 -complete=customlist,miniSnip#completeCommand MiniSnipDelete call miniSnip#delete("<args>")

let g:loaded_miniSnip = 1
let &cpo = s:cpo_save | unlet s:cpo_save
