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

" Mappings {{{1

nno <silent>    g:a    :<c-u>exe interactive_lists#main('args', 0)<cr>
nno <silent>    g:c    :<c-u>exe interactive_lists#main('changes', 0)<cr>
nno <silent>    g:l    :<c-u>exe interactive_lists#main('ls', 0)<cr>
nno <silent>    g:L    :<c-u>exe interactive_lists#main('ls', 1)<cr>
nno <silent>    g:m    :<c-u>exe interactive_lists#main('marks', 0)<cr>
nno <silent>    g:M    :<c-u>exe interactive_lists#main('marks', 1)<cr>
nno <silent>    g:o    :<c-u>exe interactive_lists#main('oldfiles', 0)<cr>
nno <silent>    g:r    :<c-u>exe interactive_lists#main('registers', 0)<cr>

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
