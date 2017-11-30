if exists('g:autoloaded_interactive_lists')
    finish
endif
let g:autoloaded_interactive_lists = 1

fu! s:capture(cmd) abort "{{{1
    if a:cmd ==# 'args'
        let list = argv()
        call map(list, { k,v -> { 'filename': v } })

    elseif a:cmd ==# 'changes'
        let list = split(execute('changes'), '\n')
        call filter(list, { k,v -> v =~ '\v^%(\s+\d+){3}' })

    elseif a:cmd ==# 'ls'
        let list = range(1, bufnr('$'))

    elseif a:cmd ==# 'marks'
        let list = split(execute('marks'), '\n')
        call filter(list, { k,v -> v =~ '\v^\s+\S+%(\s+\d+){2}' })

    elseif a:cmd ==# 'number'
        let pos = getpos('.')
        let list = split(execute('keepj '.getcmdline(), ''), '\n')
        call setpos('.', pos)

    elseif a:cmd ==# 'oldfiles'
        let list = split(execute('old'), '\n')

    elseif a:cmd ==# 'registers'
        let list = [ '"', '+', '-', '*', '/', '=' ]
        call extend(list, map(range(48,57)+range(97,122), { k,v -> nr2char(v,1) }))
    endif
    return list
endfu

fu! s:color_as_filename(pat) abort "{{{1
    if hlexists('qfFileName')
        call matchadd('qfFileName', a:pat, 0, -1)
    endif
endfu

fu! s:conceal(pat) abort "{{{1
    setl cocu=nc cole=3
    call matchadd('Conceal', a:pat, 0, -1, { 'conceal': 'x' })
endfu

fu! s:convert(output, cmd, bang) abort "{{{1
    if a:cmd ==# 'ls'
        call filter(a:output, a:bang ? { k,v -> bufexists(v) } : { k,v -> buflisted(v) })
        call map(a:output, { k,v -> { 'bufnr': v } })
        for item in a:output
            if empty(bufname(item.bufnr))
                let item.text = '[No Name]'
            endif
        endfor

    elseif a:cmd ==# 'changes'
        call map(a:output, { k,v -> {
        \                             'lnum':  matchstr(v, '\v^%(\s+\d+){1}\s+\zs\d+'),
        \                             'col':   matchstr(v, '\v^%(\s+\d+){2}\s+\zs\d+'),
        \                             'text':  matchstr(v, '\v^%(\s+\d+){3}\s+\zs.*'),
        \                             'bufnr': bufnr(''),
        \                           }
        \                  })
        " all entries should show some text, otherwise it's impossible to know
        " what changed, and they're useless
        call filter(a:output, { k,v -> !empty(v.text) })

    elseif a:cmd ==# 'marks'
        call map(a:output, { k,v -> {
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
                                                   \ 'text': item.mark_name }) }

        "                             ┌─ `remove()` returns the removed item,
        "                             │  but `extend()` does NOT return the added item;
        "                             │  instead returns the new extended dictionary
        "                             │
        let l:Local_mark  = { item -> extend(item, { 'filename': expand('%:p'),
                                                   \ 'text': item.mark_name.'    '.item.text }) }

        " :Marks  → global marks only
        " :Marks! → local marks only
        if a:bang
            call map(a:output, printf('%s ? %s : %s',
            \                             { k,v -> v.mark_name !~# '^\u$' },
            \                             { k,v -> l:Local_mark(v) },
            \                             '{}',
            \                        )
            \       )
        else
            call map(a:output, printf('%s ? %s : %s',
            \                             { k,v -> v.mark_name =~# '^\u$' },
            \                             { k,v -> l:Global_mark(v) },
            \                             '{}'
            \                        )
            \       )
        endif

        " remove possible empty dictionaries  which may have appeared after previous
        " `map()` invocation
        call filter(a:output, { k,v -> !empty(v) })

        " if no bang was given, we're only interested in global marks, so remove
        " '0, …, '9 marks
        if !a:bang
            call filter(a:output, { k,v -> v.mark_name !~# '^\d$' })
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
        call map(a:output, { k,v -> {
        \                             'filename' : expand('%:p'),
        \                             'lnum'     : matchstr(v, '\v^\s*\zs\d+'),
        \                             'text'     : matchstr(v, '\v^\s*\d+\s\zs.*'),
        \                           }
        \                  })

    elseif a:cmd ==# 'oldfiles'
        call map(a:output, { k,v -> {
        \                             'text'     : fnamemodify(matchstr(v, '\v^\d+:\s\zs.*'), ':t'),
        \                             'filename' : expand(matchstr(v, '\v^\d+:\s\zs.*')),
        \                           }
        \                  })

    elseif a:cmd ==# 'registers'
        " Do NOT use the `filename` key to store the name of the registers.
        " Why?
        " After executing `:LReg`, Vim would load buffers "a", "b", …
        " They would pollute the buffer list (`:ls!`).
        call map(a:output, { k,v -> { 'text': v } })

        " We pass `1` as a 2nd argument to `getreg()`.
        " It's ignored  for most registers,  but useful for the  expression register.
        " It allows to get the expression  itself, not its current value which could
        " not exist anymore (ex: a:arg)
        call map(a:output, { k,v -> extend(v, {
        \                                       'text':  v.text
        \                                               .'    '
        \                                               .substitute(getreg(v.text, 1), '\n', '^J', 'g')
        \                                     })
        \                  })

    endif
    return a:output
endfu

fu! interactive_lists#main(cmd, bang) abort "{{{1
    try
        let output = s:capture(a:cmd)
        let list   = s:convert(output, a:cmd, a:bang ? 1 : 0)

        if empty(list)
            return a:cmd ==# 'args'
            \?         'echoerr "No arguments"'
            \:     a:cmd ==# 'number'
            \?         getcmdline()
            \:         'echoerr "No output"'
        endif

        call setloclist(0, list)
        call setloclist(0, [], 'a', { 'title': a:cmd ==# 'marks'
        \                                    ?     ':Marks' .(a:bang ? '!' : '')
        \                                    : a:cmd ==# 'number'
        \                                    ?     ':'.getcmdline()
        \                                    :     ':'.a:cmd.(a:bang ? '!' : '')})

        if a:cmd ==# 'number'
            call timer_start(0, {-> s:open_qf('number') + feedkeys("\e", 'in')})
        else
            call s:open_qf(a:cmd)
        endif
    catch
        return a:cmd ==# 'number'
        \?         getcmdline()
        \:         'echoerr '.string(v:exception)
    endtry
    return ''
endfu

fu! s:open_qf(cmd) abort "{{{1
    lopen
    let pat = {
    \           'args'      : '|\s*|\s*$',
    \           'changes'   : '^\v.{-}\|\s*\d+%(\s+col\s+\d+\s*)?\s*\|\s?',
    \           'ls'        : '\v\|\s*\|\s*%(\ze\[No Name\]\s*)?$',
    \           'marks'     : '\v^.{-}\zs\|.{-}\|\s*',
    \           'number'    : '.*|\s*\d\+\s*|\s\?',
    \           'oldfiles'  : '.\{-}|\s*|\s*',
    \           'registers' : '\v^\s*\|\s*\|\s*',
    \         }[a:cmd]

    if executable('column') && executable('sed')
        setl modifiable
        sil! exe "%!sed 's/|/\<c-a>|/1'"
        sil! exe "%!sed 's/|/\<c-a>|/2'"
        sil! exe "%!column -s '\<c-a>' -t"
        setl nomodifiable nomodified
    endif

    call s:conceal(pat)
    if a:cmd ==# 'ls'
        call s:color_as_filename('\[No Name\]$')
    elseif a:cmd ==# 'registers'
        call s:color_as_filename('\v^\s*\|\s*\|\s*\zs\S+')
    endif
endfu
