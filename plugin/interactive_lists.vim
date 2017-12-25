if exists('g:loaded_interactive_lists')
    finish
endif
let g:loaded_interactive_lists = 1

" TODO:
" :clist :llist (with all possible syntaxes)
" :dlist :ilist
" :jumps
" :tags, :tselect
" :undolist

" TODO:
" replace ^J with a real linefeed, so that we can copy the register faithfully; possible?

" FIXME:
" After capturing output of `:jumps`, how  to distinguish a path to a file, from
" a text in the current buffer describing a path to a file.

" Mappings {{{1

nno  <silent><unique>  g:a  :<c-u>exe interactive_lists#main('args', 0)<cr>
nno  <silent><unique>  g:c  :<c-u>exe interactive_lists#main('changes', 0)<cr>
nno  <silent><unique>  g:l  :<c-u>exe interactive_lists#main('ls', 0)<cr>
nno  <silent><unique>  g:L  :<c-u>exe interactive_lists#main('ls', 1)<cr>
nno  <silent><unique>  g:m  :<c-u>exe interactive_lists#main('marks', 0)<cr>
nno  <silent><unique>  g:M  :<c-u>exe interactive_lists#main('marks', 1)<cr>
nno  <silent><unique>  g:o  :<c-u>exe interactive_lists#main('oldfiles', 0)<cr>
nno  <silent><unique>  g:r  :<c-u>exe interactive_lists#main('registers', 0)<cr>

" Why don't we use <expr>?{{{
"
" Even though we can capture `getcmdline()`, we don't seem to be able to capture
" its output (`execute(getcmdline(), '')`). The issue comes from an interaction
" between `execute()` and `<expr>`.

"         cno  <expr>  <c-x><c-x>  Func()
"
"         fu! Func() abort
"             let g:output = execute(getcmdline(), '')
"             return ''
"         endfu
"
"         :echo 'hello' C-x C-x
"         :echo output
"             → ∅    ✘

"         cno  <c-x><c-x>  <c-\>eFunc()<cr>
"
"         fu! Func() abort
"             let cmdline = getcmdline()
"             let g:output = execute(cmdline)
"             return cmdline
"         endfu
"
"         :echo 'hello' C-x C-x
"         :echo output
"             → hello    ✔
"
" Update:
"
"     https://github.com/vim/vim/releases/tag/v8.0.1425
"
" It's fixed in Vim 8.0.1425, but not yet in Neovim.

"}}}
cno  <unique>  <c-\>n  <c-\>einteractive_lists#main('number', 0)<cr>
