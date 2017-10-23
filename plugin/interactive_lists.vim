if exists('g:loaded_interactive_lists')
    finish
endif
let g:loaded_interactive_lists = 1

" TODO:
"
" :clist :llist (with all possible syntaxes)
" :dlist :ilist
" :g/^fu/#
"        ^
" :jumps
" :oldfiles
" :tags, :tselect
" :undolist
"
" replace ^J with a real linefeed, so that we can copy the register faithfully; possible?

" FIXME:
" After capturing output of `:jumps`, how  to distinguish a path to a file, from
" a text in the current buffer describing a path to a file.

" Commands {{{1

com!       -bar  LArgs      exe interactive_lists#args()
com!       -bar  LChanges   exe interactive_lists#changes()
com! -bang -bar  LLs        exe interactive_lists#ls(<bang>0)
com! -bang -bar  LMarks     exe interactive_lists#marks(<bang>0)
com!       -bar  LOld       exe interactive_lists#old()
com!       -bar  LReg       exe interactive_lists#reg()

" Mappings {{{1

nno <silent>    g:a    :<c-u>LArgs<cr>
nno <silent>    g:c    :<c-u>LChanges<cr>
nno <silent>    g:l    :<c-u>LLs<cr>
nno <silent>    g:L    :<c-u>LLs!<cr>
nno <silent>    g:m    :<c-u>LMarks<cr>
nno <silent>    g:M    :<c-u>LMarks!<cr>
nno <silent>    g:o    :<c-u>LOld<cr>
nno <silent>    g:r    :<c-u>LReg<cr>
