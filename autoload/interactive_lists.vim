if exists('g:autoloaded_interactive_lists')
    finish
endif
let g:autoloaded_interactive_lists = 1

fu! s:capture(cmd) abort "{{{1
    if a:cmd ==# 'args'
        let list = argv()
        call map(list, { i,v -> {
        \                         'filename': v,
        \                         'text': fnamemodify(v, ':t'),
        \                       } })

    elseif a:cmd ==# 'changes'
        let list = s:capture_cmd_local_to_window('changes', '\v^%(\s+\d+){3}')

    elseif a:cmd ==# 'ls'
        let list = range(1, bufnr('$'))

    elseif a:cmd ==# 'marks'
        let list = s:capture_cmd_local_to_window('marks', '\v^\s+\S+%(\s+\d+){2}')

    elseif a:cmd ==# 'number'
        let pos = getpos('.')
        let list = split(execute('keepj '.getcmdline(), ''), '\n')
        call setpos('.', pos)

    elseif a:cmd ==# 'oldfiles'
        let list = split(execute('old'), '\n')

    elseif a:cmd ==# 'registers'
        let list = [ '"', '+', '-', '*', '/', '=' ]
        call extend(list, map(range(48,57)+range(97,122), { i,v -> nr2char(v,1) }))
    endif
    return list
endfu

fu! s:capture_cmd_local_to_window(cmd, pat) abort "{{{1
    " The changelist  is local  to a  window.
    " If we  are in a  location window,  `g:c` will show  us the changes  in the
    " latter.   But, we  are NOT  interested in  them. We want  the ones  in the
    " associated window. Same thing for the local marks.
    if &buftype ==# 'quickfix'
        noautocmd call qf#focus_window('loc', 0)
        let list = split(execute(a:cmd), '\n')
        noautocmd wincmd p
    else
        let list = split(execute(a:cmd), '\n')
    endif
    return filter(list, { i,v -> v =~ a:pat })
endfu

fu! s:convert(output, cmd, bang) abort "{{{1
    if a:cmd ==# 'ls'
        call filter(a:output, a:bang ? { i,v -> bufexists(v) } : { i,v -> buflisted(v) })
        call map(a:output, { i,v -> {
        \                             'bufnr': v,
        \                             'text': empty(bufname(v))
        \                                     ?    '[No Name]'
        \                                     :     fnamemodify(bufname(v), ':t'),
        \                           } })

    elseif a:cmd ==# 'changes'
        call map(a:output, { i,v -> {
        \                             'lnum':  matchstr(v, '\v^%(\s+\d+){1}\s+\zs\d+'),
        \                             'col':   matchstr(v, '\v^%(\s+\d+){2}\s+\zs\d+'),
        \                             'text':  matchstr(v, '\v^%(\s+\d+){3}\s+\zs.*'),
        \                             'bufnr': bufnr(''),
        \                           }
        \                  })
        " all entries should show some text, otherwise it's impossible to know
        " what changed, and they're useless
        call filter(a:output, { i,v -> !empty(v.text) })

    elseif a:cmd ==# 'marks'
        call map(a:output, { i,v -> {
        \                             'mark_name':  matchstr(v, '\S\+'),
        \                             'lnum':       matchstr(v, '\v^\s*\S+\s+\zs\d+'),
        \                             'col':        matchstr(v, '\v^\s*\S+%(\s+\zs\d+){2}'),
        \                             'text':       matchstr(v, '\v^\s*\S+%(\s+\d+){2}\s+\zs.*'),
        \                             'filename':   matchstr(v, '\v^\s*\S+%(\s+\d+){2}\s+\zs.*'),
        \                           }
        \                  })

        "                                                        ┌─ it's important to expand the filename
        "                                                        │  otherwise, if there's a tilde (for $HOME),
        "                                                        │  clicking on the entry will load an empty
        "                                                        │  buffer (with the right filepath; weird …)
        "                                                        │
        let l:Global_mark = { item -> extend(item, { 'filename': expand(item.filename),
        \                                            'text': item.mark_name.'    '
        \                                                   .fnamemodify(expand(item.filename), ':t') }
        \                                   )
        \                   }

        "                             ┌─ `remove()` returns the removed item,
        "                             │  but `extend()` does NOT return the added item;
        "                             │  instead returns the new extended dictionary
        "                             │
        let l:Local_mark  = { item -> extend(item, { 'filename': expand('%:p'),
        \                                            'text': item.mark_name.'    '.item.text }) }

        " :Marks  → global marks only
        " :Marks! → local marks only
        if a:bang
            call map(a:output, printf(
            \                          '%s ? %s : %s',
            \                          'v:val.mark_name !~# "^\\u$"',
            \                          'l:Local_mark(v:val)',
            \                          '{}',
            \                        )
            \       )
        else
            call map(a:output, printf(
            \                          '%s ? %s : %s',
            \                          'v:val.mark_name =~# "^\\u$"',
            \                          'l:Global_mark(v:val)',
            \                           '{}'
            \                        )
            \       )
        endif

        " remove possible empty dictionaries  which may have appeared after previous
        " `map()` invocation
        call filter(a:output, { i,v -> !empty(v) })

        " if no bang was given, we're only interested in global marks, so remove
        " '0, …, '9 marks
        if !a:bang
            call filter(a:output, { i,v -> v.mark_name !~# '^\d$' })
        endif

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

    elseif a:cmd ==# 'number'
        call map(a:output, { i,v -> {
        \                             'filename' : expand('%:p'),
        \                             'lnum'     : matchstr(v, '\v^\s*\zs\d+'),
        \                             'text'     : matchstr(v, '\v^\s*\d+\s\zs.*'),
        \                           }
        \                  })

    elseif a:cmd ==# 'oldfiles'
        call map(a:output, { i,v -> {
        \                             'filename' : expand(matchstr(v, '\v^\d+:\s\zs.*')),
        \                             'text'     : fnamemodify(matchstr(v, '\v^\d+:\s\zs.*'), ':t'),
        \                           }
        \                  })

    elseif a:cmd ==# 'registers'
        " Do NOT use the `filename` key to store the name of the registers.
        " Why?
        " After executing `:LReg`, Vim would load buffers "a", "b", …
        " They would pollute the buffer list (`:ls!`).
        call map(a:output, { i,v -> { 'text': v } })

        " We pass `1` as a 2nd argument to `getreg()`.
        " It's ignored  for most registers,  but useful for the  expression register.
        " It allows to get the expression  itself, not its current value which could
        " not exist anymore (ex: a:arg)
        call map(a:output, { i,v -> extend(v, {
        \                                       'text':  v.text
        \                                               .'    '
        \                                               .substitute(getreg(v.text, 1), '\n', '^J', 'g')
        \                                     })
        \                  })

    endif
    " Why setting the `valid` key in all entries?{{{
    "
    " For some commands,  the list may contain no valid  error. This is the case
    " for `:oldfiles`,  because it  doesn't give any  position. So Vim  will use
    " line 0, col 0 for all entries, which is not valid.
    "
    " If there's no valid error in  the list, `:lwindow` won't open it. `vim-qf`
    " uses `:lwindow`. So, we  need to make sure there's at  least 1 valid entry
    " in the list.
    "
    " Alternative:
    "         let a:output[0].valid = 1
    "}}}
    return map(a:output, { i,v -> extend(v, { 'valid': 1 }) })
endfu

fu! interactive_lists#main(cmd, bang) abort "{{{1
    try
        let cmdline = getcmdline()
        if a:cmd ==# 'number' && cmdline[-1:-1] !=# '#'
            return cmdline
        endif
        let output = s:capture(a:cmd)
        if a:cmd ==# 'number' && get(output, 0, '') =~# '^Pattern not found:'
            call timer_start(0, {-> feedkeys("\<cr>", 'in') })
            return 'echoerr "Pattern not found"'
        endif
        let list = s:convert(output, a:cmd, a:bang ? 1 : 0)

        if empty(list)
            return a:cmd ==# 'args'
            \?         'echoerr "No arguments"'
            \:     a:cmd ==# 'number'
            \?         cmdline
            \:         'echoerr "No output"'
        endif

        call setloclist(0, list)
        call setloclist(0, [], 'a', { 'title': a:cmd ==# 'marks'
        \                                    ?     ':Marks' .(a:bang ? '!' : '')
        \                                    : a:cmd ==# 'number'
        \                                    ?     ':'.cmdline
        \                                    :     ':'.a:cmd.(a:bang ? '!' : '')})

        if a:cmd ==# 'number'
            call timer_start(0, {-> s:open_qf('number') + feedkeys("\e", 'in')})
        else
            call s:open_qf(a:cmd)
        endif
    catch
        return a:cmd ==# 'number'
        \?         cmdline
        \:         my_lib#catch_error()
    endtry
    return ''
endfu

fu! s:open_qf(cmd) abort "{{{1
    " We don't want to open the qf  window directly, because it's the job of our
    " `vim-qf` plugin. The latter uses some logic to decide the position and the
    " size of the qf window.
    " `:lopen`  or  `:lwindow` would  just  open  the  window with  its  default
    " position/size without any custom logic.
    "
    " So,  we just  emit the  event `QuickFixCmdPost`.  `vim-qf` has  an autocmd
    " listening to it.
    doautocmd QuickFixCmdPost lgrep

    if &l:buftype !=# 'quickfix'
        return
    endif

    let pat = {
    \           'args'      : '.*|\s*|\s*',
    \           'changes'   : '^\v.{-}\|\s*\d+%(\s+col\s+\d+\s*)?\s*\|\s?',
    \           'ls'        : '\v.*\|\s*\|\s*\ze%(\[No Name\]\s*)?.*$',
    \           'marks'     : '\v^.{-}\|.{-}\|\s*',
    \           'number'    : '.*|\s*\d\+\s*|\s\?',
    \           'oldfiles'  : '.\{-}|\s*|\s*',
    \           'registers' : '\v^\s*\|\s*\|\s*',
    \         }[a:cmd]

    call qf#set_matches('interactive_lists:open_qf', 'Conceal', pat)

    if a:cmd ==# 'registers'
        call qf#set_matches('interactive_lists:open_qf', 'qfFileName',  'location')
    endif
    call qf#create_matches()
endfu
