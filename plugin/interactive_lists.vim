if exists('g:loaded_interactive_lists')
    finish
endif
let g:loaded_interactive_lists = 1

" TODO:
"
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

" Commands {{{1

com!       -bar  Largs      exe interactive_lists#main('args', 0)
com!       -bar  Lchanges   exe interactive_lists#main('changes', 0)
com! -bang -bar  Lls        exe interactive_lists#main('ls', <bang>0)
com! -bang -bar  Lmarks     exe interactive_lists#main('marks', <bang>0)
com!       -bar  Loldfiles  exe interactive_lists#main('oldfiles', 0)
com!       -bar  Lregisters exe interactive_lists#main('registers', 0)

" Mappings {{{1

nno <silent>    g:a    :<c-u>Largs<cr>
nno <silent>    g:c    :<c-u>Lchanges<cr>
nno <silent>    g:l    :<c-u>Lls<cr>
nno <silent>    g:L    :<c-u>Lls!<cr>
nno <silent>    g:m    :<c-u>Lmarks<cr>
nno <silent>    g:M    :<c-u>Lmarks!<cr>
nno <silent>    g:o    :<c-u>Loldfiles<cr>
nno <silent>    g:r    :<c-u>Lregisters<cr>

" Why don't we use <expr>?{{{
"
" Even though we can capture `getcmdline()`, we don't seem to be able to capture
" its output (`execute(getcmdline(), '')`). Maybe because the display is locked,
" and `execute()` needs the output to be displayed…
"
"         cno <expr> <c-x><c-x> Func()              ✘
"         cno        <c-x><c-x> <c-\>eFunc()<cr>    ✔
"
"         fu! Func() abort
"             let g:debug = execute(getcmdline(), '')
"             return ''
"         endfu
"}}}
cno <c-\>n <c-\>einteractive_lists#main('number', 0)<cr>
