fu interactive_lists#all_matches_in_buffer() abort "{{{1
    " Alternative:
    "
    "         keepj g//#

    let id = win_getid()
    let view = winsaveview()
    try
        " Why `:exe`?{{{
        "
        " It removes excessive spaces in the title of the qf window, between the
        " colon and the rest of the command.
        "}}}
        " Why is it necessary?{{{
        "
        " Because Vim copies the indentation of the command.
        "
        " MWE:
        "     nno  cd  :lvim /./ % <bar> lopen<cr>
        "
        "     cd
        "     :lopen
        "     title = ':lvim /./ %'    ✔~
        "
        "     nno  cd  :call Func()<cr>
        "     fu Func() abort
        "         lvim /./ %
        "         lopen
        "     endfu
        "
        "     cd
        "     title = ':    lvim /./ %'~
        "               ^^^^
        "               ✘ because `:lvim` is executed from a line~
        "                 with a level of indentation of 4 spaces~
        "
        "     nno  cd  :call Func()<cr>
        "     fu Func() abort
        "         try
        "             lvim /./ %
        "             lopen
        "         endtry
        "     endfu
        "
        "     cd
        "     title = ':        lvim /./ %'~
        "               ^^^^^^^^
        "                ✘ because `:lvim` is executed from a line~
        "                  with a level of indentation of 8 spaces~
        "}}}
        " Is there an alternative?{{{
        "
        " Yes, but it's more complicated:
        "
        "     if &bt is# 'quickfix'
        "         let w:quickfix_title = ':'.matchstr(w:quickfix_title, ':\s*\zs\S.*')
        "     endif
        "}}}
        exe 'noa lvim //gj %'
        "                │
        "                └ don't jump to the first entry;
        "                  stay in the qf window
        lwindow
        if &bt is# 'quickfix'
            call qf#set_matches('vimrc:all_matches_in_buffer', 'Conceal', 'location')
            call qf#create_matches()
        endif
    catch
        return lg#catch_error()
    finally
        call win_gotoid(id)
        call winrestview(view)
    endtry
    if getbufvar(winbufnr(winnr('#')), '&bt', '') is# 'quickfix'
        wincmd p
    endif
endfu

fu s:capture(cmd) abort "{{{1
    if a:cmd is# 'args'
        let list = argv()
        call map(list, {_,v -> {
            \ 'filename': v,
            \ 'text': fnamemodify(v, ':t'),
            \ }})

    elseif a:cmd is# 'changes'
        let list = s:capture_cmd_local_to_window('changes', '^\%(\s\+\d\+\)\{3}')

    elseif a:cmd is# 'jumps'
        let list = s:capture_cmd_local_to_window('jumps', '^')

    elseif a:cmd is# 'ls'
        let list = range(1, bufnr('$'))

    elseif a:cmd is# 'marks'
        let list = s:capture_cmd_local_to_window('marks', '^\s\+\S\+\%(\s\+\d\+\)\{2}')

    elseif a:cmd is# 'number'
        let pos = getcurpos()
        let list = split(execute('keepj '..getcmdline(), ''), '\n')
        call setpos('.', pos)

    elseif a:cmd is# 'oldfiles'
        let list = split(execute('old'), '\n')

    elseif a:cmd is# 'registers'
        let list =<< trim END
            "
            +
            -
            *
            /
            =
        END
        call extend(list, map(range(48,57)+range(97,122), {_,v -> nr2char(v,1)}))
    endif
    return list
endfu

fu s:capture_cmd_local_to_window(cmd, pat) abort "{{{1
    " The changelist is local to a window.
    " If we  are in a  location window,  `g:c` will show  us the changes  in the
    " latter.   But, we  are NOT  interested in  them. We want  the ones  in the
    " associated window. Same thing for the jumplist and the local marks.
    if a:cmd is# 'jumps'
        if &bt is# 'quickfix'
            noa call lg#window#qf_open_or_focus('loc')
            let jumplist = get(getjumplist(), 0, [])
            call map(jumplist, {_,v -> extend(v,
                \ {'text': bufnr('%') == v.bufnr ? getline(v.lnum) : bufname(v.bufnr)})})
            noa wincmd p
            return jumplist
        else
            let jumplist = get(getjumplist(), 0, [])
            return map(jumplist, {_,v -> extend(v,
                \ {'text': bufnr('%') == v.bufnr ? getline(v.lnum) : bufname(v.bufnr)})})
        endif

    elseif a:cmd is# 'changes'
        if &bt is# 'quickfix'
            noa call lg#window#qf_open_or_focus('loc')
            let changelist = get(getchangelist('%'), 0, [])
            let bufnr = bufnr('%')
            for entry in changelist
                call extend(entry, {'text': getline(entry.lnum), 'bufnr': bufnr})
            endfor
            noa wincmd p
        else
            let changelist = get(getchangelist('%'), 0, [])
            let bufnr = bufnr('%')
            for entry in changelist
                call extend(entry, {'text': getline(entry.lnum), 'bufnr': bufnr})
            endfor
        endif
        " all entries should show some text, otherwise it's impossible to know
        " what changed, and they're useless
        call filter(changelist, {_,v -> !empty(v.text)})
        return changelist

    elseif a:cmd is# 'marks'
        if &bt is# 'quickfix'
            noa call lg#window#qf_open_or_focus('loc')
            let list = split(execute(a:cmd), '\n')
            noa wincmd p
        else
            let list = split(execute(a:cmd), '\n')
        endif
        return filter(list, {_,v -> v =~ a:pat})
    endif
endfu

fu s:convert(output, cmd, bang) abort "{{{1
    if a:cmd is# 'ls'
        call filter(a:output, a:bang ? {_,v -> bufexists(v)} : {_,v -> buflisted(v)})
        " Why is the first character in `printf()` a no-break space?{{{
        "
        " Because, by default, Vim reduces all leading spaces in the text to a single space.
        " We don't want that. We want them to be left as is, so that the buffer numbers are
        " right aligned in their field. So, we prefix the text with a character which is not
        " a whitespace, but looks like one.
        "}}}
        call map(a:output, {_,v -> {
            \ 'bufnr': v,
            \ 'text': printf(' %*d%s%s%s%s%s %s',
            \                 len(bufnr('$')), v,
            \                !buflisted(v) ? 'u': ' ',
            \                v == bufnr('%') ? '%' : v == bufnr('#') ? '#' : ' ',
            \                empty(win_findbuf(v)) ? 'h' : 'a',
            \                getbufvar(v, '&ma', 0) ? ' ' : '-',
            \                getbufvar(v, '&mod', 0) ? '+' : ' ',
            \                empty(bufname(v))
            \                  ?    '[No Name]'
            \                  :     fnamemodify(bufname(v), ':t')
            \ )}})

    elseif a:cmd is# 'changes'

    elseif a:cmd is# 'jumps'
        " Why?
        " For some reason, `getjumplist()` seems to include in the list an item
        " matching the location: (buffer, line, col) = (1, 0, 0)
        " The issue may  come from the fact  that when we start Vim,  we have an
        " unnamed and empty buffer. Then, Vim restores a session automatically.
        " In the process, this buffer n°1 is probably wiped.
        call filter(a:output, {_,v -> bufexists(v.bufnr)})

    " `:Marks!` → local marks only
    elseif a:cmd is# 'marks' && a:bang
        call map(a:output, {_,v -> {
            \ 'mark_name': matchstr(v, '\S\+'),
            \ 'lnum':      matchstr(v, '^\s*\S\+\s\+\zs\d\+'),
            \ 'col':       matchstr(v, '^\s*\S\+\%(\s\+\zs\d\+\)\{2}'),
            \ 'text':      matchstr(v, '^\s*\S\+\%(\s\+\d\+\)\{2}\s\+\zs.*'),
            \ 'filename':  matchstr(v, '^\s*\S\+\%(\s\+\d\+\)\{2}\s\+\zs.*'),
            \ }})

        "                             ┌ `remove()` returns the removed item,
        "                             │ but `extend()` does NOT return the added item;
        "                             │ instead returns the new extended dictionary
        "                             │
        let l:Local_mark  = { item -> extend(item, {
            \ 'filename': expand('%:p'),
            \ 'text': item.mark_name..'    '..item.text
            \ })}

        call map(a:output, printf(
            \ '%s ? %s : %s',
            \ 'v:val.mark_name !~# "^\\u$"',
            \ 'l:Local_mark(v:val)',
            \ '{}',
            \ ))

        " remove possible empty dictionaries  which may have appeared after previous
        " `map()` invocation
        call filter(a:output, {_,v -> !empty(v)})

        " When we iterate  over the dictionaries (`mark`)  stored in `a:output`,
        " we have access to the original dictionaries, not copies.
        " Otherwise,  removing  a  key  from   them  would  have  no  effect  on
        " `a:output`.  But it does.
        " This  is  because  Vim   passes  lists/dictionaries  to  functions  by
        " reference, not by value.
        for mark in a:output
            " remove the `mark_name` key, it's not needed anymore
            call remove(mark, 'mark_name')
        endfor

    " `:Marks`  → global marks only
    elseif a:cmd is# 'marks' && !a:bang
        if !filereadable($HOME..'/.vim/bookmarks')
            return []
        endif
        let bookmarks = readfile($HOME..'/.vim/bookmarks')

        call map(bookmarks, {_,v -> {
            \ 'text': v[0]..'  '..fnamemodify(matchstr(v, ':\zs.*'), ':t'),
            \ 'filename': expand(matchstr(v, ':\zs.*')),
            \ }})

        return bookmarks

    elseif a:cmd is# 'number'
        call map(a:output, {_,v -> {
            \ 'filename' : expand('%:p'),
            \ 'lnum'     : matchstr(v, '^\s*\zs\d\+'),
            \ 'text'     : matchstr(v, '^\s*\d\+\s\zs.*'),
            \ }})

    elseif a:cmd is# 'oldfiles'
        call map(a:output, {_,v -> {
            \ 'filename' : expand(matchstr(v, '^\d\+:\s\zs.*')),
            \ 'text' : fnamemodify(matchstr(v, '^\d\+:\s\zs.*'), ':t'),
            \ }})

    elseif a:cmd is# 'registers'
        " Do NOT use the `filename` key to store the name of the registers.
        " Why?
        " After pressing `g:r`, Vim would load buffers "a", "b", …
        " They would pollute the buffer list (`:ls!`).
        call map(a:output, {_,v -> {'text': v}})

        " We pass `1` as a 2nd argument to `getreg()`.
        " It's ignored  for most registers,  but useful for the  expression register.
        " It allows to get the expression  itself, not its current value which could
        " not exist anymore (ex: a:arg)
        call map(a:output, {_,v -> extend(v, {
            \ 'text':  v.text..'    '..getreg(v.text, 1)
            \ })})

    endif
    return a:output
endfu

fu interactive_lists#main(cmd, bang) abort "{{{1
    try
        let cmdline = getcmdline()
        if a:cmd is# 'number' && cmdline[-1:-1] isnot# '#'
            return cmdline
        endif
        let output = s:capture(a:cmd)
        if a:cmd is# 'number' && get(output, 0, '') =~# '^Pattern not found:'
            call timer_start(0, {_ -> feedkeys("\<cr>", 'in') })
            return 'echoerr "Pattern not found"'
        endif
        let list = s:convert(output, a:cmd, a:bang ? 1 : 0)

        if empty(list)
            return a:cmd is# 'args'
               \ ?     'echoerr "No arguments"'
               \ : a:cmd is# 'number'
               \ ?     cmdline
               \ :     'echoerr "No output"'
        endif

        call setloclist(0, [], ' ', {
            \ 'items': list,
            \ 'title': a:cmd is# 'marks'
            \         ?     ':Marks'..(a:bang ? '!' : '')
            \         : a:cmd is# 'number'
            \         ?     ':'..cmdline
            \         :     ':'..a:cmd..(a:bang ? '!' : '')})

        if a:cmd is# 'number'
            call timer_start(0, {_ -> s:open_qf('number') + feedkeys("\e", 'in')})
        else
            call s:open_qf(a:cmd)
        endif
    catch
        return a:cmd is# 'number'
           \ ?     cmdline
           \ :     lg#catch_error()
    endtry
    return ''
endfu

fu s:open_qf(cmd) abort "{{{1
    " We don't want to open the qf  window directly, because it's the job of our
    " `vim-qf` plugin. The latter uses some logic to decide the position and the
    " size of the qf window.
    " `:lopen`  or  `:lwindow` would  just  open  the  window with  its  default
    " position/size without any custom logic.
    "
    " So,  we just  emit the  event `QuickFixCmdPost`.  `vim-qf` has  an autocmd
    " listening to it.
    do <nomodeline> QuickFixCmdPost lopen

    let pat = {
        \ 'args'      : '.*|\s*|\s*',
        \ 'changes'   : 'location',
        \ 'jumps'     : '^.\{-}\ze|',
        \ 'ls'        : '.*|\s*|\s*\ze\%(\[No Name\]\s*\)\=.*$',
        \ 'marks'     : '^.\{-}|.\{-}|\s*',
        \ 'number'    : '.*|\s*\d\+\s*|\s\=',
        \ 'oldfiles'  : '.\{-}|\s*|\s*',
        \ 'registers' : '^\s*|\s*|\s*',
        \ }[a:cmd]

    call qf#set_matches('interactive_lists:open_qf', 'Conceal', pat)

    if a:cmd is# 'registers'
        call qf#set_matches('interactive_lists:open_qf', 'qfFileName',  '^\s*|\s*|\s\zs\S\+')
    endif
    call qf#create_matches()
endfu

fu interactive_lists#set_or_go_to_mark(action) abort "{{{1
    " ask for a mark
    let mark = nr2char(getchar(),1)
    if mark is# "\e"
        return
    endif

    " If it's not a global one, just type the keys as usual (with one difference):{{{
    "
    "    - mx
    "    - `x
    "      ^
    "      let's use backtick instead of a single quote, so that we land on the exact column
    "      rationale: the single quote key is easier to type
    "}}}
    if index(range(char2nr('A'), char2nr('Z')), char2nr(mark)) == -1
        return feedkeys((a:action is# 'set' ? 'm' : "`")..mark, 'in')
    endif

    " now, we process a global mark
    " first, get the path to the file containing the bookmarks
    let book_file = $HOME..'/.vim/bookmarks'
    if !filereadable(book_file)
        echo book_file..' is not readable'
        return
    endif

    " we SET a global mark
    if a:action is# 'set'
        "                   ┌ eliminate old mark if it's present
        "                   │
        let new_bookmarks = filter(readfile(book_file), {_,v -> v[0] isnot# mark})
            \ + [mark..':'..substitute(expand('%:p'), $HOME, '$HOME', '')]
            " │
            " └ and bookmark current file
        call writefile(sort(new_bookmarks), book_file)

    " we JUMP to a global mark
    else
        let path = filter(readfile(book_file), {_,v -> v[0] is# mark})
        if empty(path)
            return
        endif
        let path = path[0][2:]
        exe 'e '..path
        " '. may not exist
        try
            sil! norm! g`.zvzz
            "  │
            "  └ E20: mark not set
        catch
            return lg#catch_error()
        endtry
    endif
    " re-mark the file, to fix Vim's frequent and unavoidable lost marks
    call feedkeys('m'..mark, 'in')
endfu
