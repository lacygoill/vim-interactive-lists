if exists('g:loaded_interactive_lists')
    finish
endif
let g:loaded_interactive_lists = 1

" TODO:
" `:clist`  `:llist` (with all possible syntaxes)
" `:dlist`  `:ilist`
" `:tags`   `:tselect`
" `:undolist`

" TODO: Replace `^J` with a real linefeed, so that we can copy the register faithfully; possible?
" Update: How  about installing  custom mappings  in the  qf window  which would
" replace `^J` with a linefeed when yanking a register?

" Purpose:{{{
"
" useful to display the subset of lines in the buffer containing the last search pattern
" equivalent to:
"                 :Ilist pattern    without slash around pattern
"                                   because our custom implementation of
"                                   `:ilist` doesn't add anchors (\<, \>)
"                                   contrary to the default `:ilist`
"}}}
nno <silent><unique> g:: :<c-u>call interactive_lists#all_matches_in_buffer()<cr>

nno <silent><unique> g:a :<c-u>exe interactive_lists#main('args', 0)<cr>
nno <silent><unique> g:c :<c-u>exe interactive_lists#main('changes', 0)<cr>
nno <silent><unique> g:j :<c-u>exe interactive_lists#main('jumps', 0)<cr>
nno <silent><unique> g:l :<c-u>exe interactive_lists#main('ls', 0)<cr>
nno <silent><unique> g:L :<c-u>exe interactive_lists#main('ls', 1)<cr>
nno <silent><unique> g:m :<c-u>exe interactive_lists#main('marks', 0)<cr>
nno <silent><unique> g:M :<c-u>exe interactive_lists#main('marks', 1)<cr>
nno <silent><unique> g:o :<c-u>exe interactive_lists#main('oldfiles', 0)<cr>
nno <silent><unique> g:r :<c-u>exe interactive_lists#main('registers', 0)<cr>

cno <unique> <c-\>n <c-\>e interactive_lists#main('number', 0)<cr>

" Why?{{{
"
" When we load a buffer, we have an autocmd (`:au jump_last_position`) which
" moves the cursor to the last edit performed in that buffer.
" Unfortunately, it doesn't work when we load a file with a global mark.
" Indeed, the global mark contains several info (`:marks`):
"
"    - path to file
"    - line nr
"    - column nr
"
" When we load a file with a global mark, Vim will position the cursor on the
" line where we saved the mark.
" But that's not what we want.  We want the cursor to be on the last edit.
" To fix this,  we override all the  `'A`, ..., `'Z` commands so  that after the
" loading of a marked file, Vim presses g`.
"
" Also, Vim may erase a global mark when it has to execute `:bwipe`.  It happens
" when we execute  `:vimgrep` to look for a  pattern in a set of  files, and the
" latter contains a file with a global mark which doesn't contain the pattern:
"
" https://github.com/vim/vim/issues/2166
"
" So, all in all, the global marks system is pretty broken.
"
" We re-implement it completely and save the paths in a bookmark file.
"
" Don't rely on the existing mechanism, it's fucked up beyond any repair.
" Don't even rely on `~/.viminfo`.  It's another can of worms.
"}}}
nno <silent><unique> m :<c-u>call interactive_lists#set_or_go_to_mark('set')<cr>
nno <silent><unique> ' :<c-u>call interactive_lists#set_or_go_to_mark('go')<cr>
