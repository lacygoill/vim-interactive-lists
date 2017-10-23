if exists('g:loaded_interactive_lists')
    finish
endif
let g:loaded_interactive_lists = 1

" TODO:
" :clist :llist (with all possible syntaxes)
" :dlist :ilist
" :oldfiles
" :g/^fu/#
"        ^
"
" Rename commands, and get rid of L?

" Commands {{{1

com!       -bar  Args      exe interactive_lists#largs()
com!       -bar  Changes   exe interactive_lists#lchanges()
com! -bang -bar  LS        exe interactive_lists#lls(<bang>0)
com! -bang -bar  Marks     exe interactive_lists#lmarks(<bang>0)
com!       -bar  Reg       exe interactive_lists#lreg()

" Mappings {{{1

nno <silent>    g:a    :<c-u>Args<cr>
nno <silent>    g:c    :<c-u>Changes<cr>
nno <silent>    g:l    :<c-u>LS<cr>
nno <silent>    g:m    :<c-u>Marks<cr>
nno <silent>    g:r    :<c-u>Reg<cr>
