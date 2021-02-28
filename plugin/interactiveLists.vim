vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# TODO:
# `:clist`  `:llist` (with all possible syntaxes)
# `:dlist`  `:ilist`
# `:tags`   `:tselect`
# `:undolist`

# TODO: Replace `^J` with a real linefeed, so that we can copy the register faithfully; possible?
# Update: How  about installing  custom mappings  in the  qf window  which would
# replace `^J` with a linefeed when yanking a register?

# Purpose:{{{
#
# useful to display the subset of lines in the buffer containing the last search pattern
# equivalent to:
#
#     :Ilist pattern    without slash around pattern
#                       because our custom implementation of
#                       `:ilist` doesn't add anchors (\<, \>)
#                       contrary to the default `:ilist`
#}}}
nno <unique> g:: <cmd>call interactiveLists#allmatchesinbuffer()<cr>

nno <unique> g:a <cmd>call interactiveLists#main('args')<cr>
nno <unique> g:c <cmd>call interactiveLists#main('changes')<cr>
nno <unique> g:j <cmd>call interactiveLists#main('jumps')<cr>
nno <unique> g:l <cmd>call interactiveLists#main('ls')<cr>
nno <unique> g:L <cmd>call interactiveLists#main('ls', v:true)<cr>
nno <unique> g:m <cmd>call interactiveLists#main('marks')<cr>
nno <unique> g:M <cmd>call interactiveLists#main('marks', v:true)<cr>
nno <unique> g:o <cmd>call interactiveLists#main('oldfiles')<cr>
nno <unique> g:r <cmd>call interactiveLists#main('registers')<cr>

cno <unique> <c-\>n <c-\>e interactiveLists#main('number')<cr>

# Why?{{{
#
# When we load a buffer, we have an autocmd (`:au jump_last_position`) which
# moves the cursor to the last edit performed in that buffer.
# Unfortunately, it doesn't work when we load a file with a global mark.
# Indeed, the global mark contains several info (`:marks`):
#
#    - path to file
#    - line nr
#    - column nr
#
# When we load a file with a global mark, Vim will position the cursor on the
# line where we saved the mark.
# But that's not what we want.  We want the cursor to be on the last edit.
# To fix this,  we override all the  `'A`, ..., `'Z` commands so  that after the
# loading of a marked file, Vim presses g`.
#
# Also, Vim may erase a global mark when it has to execute `:bwipe`.  It happens
# when we execute  `:vimgrep` to look for a  pattern in a set of  files, and the
# latter contains a file with a global mark which doesn't contain the pattern:
#
# https://github.com/vim/vim/issues/2166
#
# So, all in all, the global marks system is pretty broken.
#
# We re-implement it completely and save the paths in a bookmark file.
#
# Don't rely on the existing mechanism, it's fucked up beyond any repair.
# Don't even rely on `~/.viminfo`.  It's another can of worms.
#}}}
nno <unique> m <cmd>call interactiveLists#setorgotomark('set')<cr>
nno <unique> ' <cmd>call interactiveLists#setorgotomark('go')<cr>
