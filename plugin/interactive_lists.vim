if exists('g:loaded_interactive_lists')
    finish
endif
let g:loaded_interactive_lists = 1

com!       -bar  LArgs      echo interactive_lists#largs()
com!       -bar  LChanges   echo interactive_lists#lchanges()
com! -bang -bar  LLS        echo interactive_lists#lls(<bang>0)
com! -bang -bar  LMarks     echo interactive_lists#lmarks(<bang>0)
com!       -bar  LReg       echo interactive_lists#lreg()
