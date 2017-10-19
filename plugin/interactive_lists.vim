if exists('g:loaded_interactive_lists')
    finish
endif
let g:loaded_interactive_lists = 1

" Commands {{{1

com!       -bar  LArgs      echo interactive_lists#largs()
com!       -bar  LChanges   echo interactive_lists#lchanges()
com! -bang -bar  LLS        echo interactive_lists#lls(<bang>0)
com! -bang -bar  LMarks     echo interactive_lists#lmarks(<bang>0)
com!       -bar  LReg       echo interactive_lists#lreg()

" Mappings {{{1

nno <silent>    g:a    :<c-u>LArgs<cr>
nno <silent>    g:c    :<c-u>LChanges<cr>
nno <silent>    g:l    :<c-u>LLS<cr>
nno <silent>    g:m    :<c-u>LMarks<cr>
nno <silent>    g:r    :<c-u>LReg<cr>


