if exists('g:autoloaded_interactive_lists')
    finish
endif
let g:autoloaded_interactive_lists = 1

fu! s:capture(cmd) abort "{{{1
    if a:cmd ==# 'args'
        let list = argv()
        call map(list, '{ "filename": v:val }')

    elseif a:cmd ==# 'changes'
        let list = split(execute('changes'), '\n')
        call filter(list, 'v:val =~ ''\v^%(\s+\d+){3}''')

    elseif a:cmd ==# 'ls'
        let list = range(1, bufnr('$'))

    elseif a:cmd ==# 'marks'
        let list = split(execute('marks'), '\n')
        call filter(list, 'v:val =~ ''\v^\s+\S+%(\s+\d+){2}''')

    elseif a:cmd ==# 'oldfiles'
        let list = split(execute('old'), '\n')

    elseif a:cmd ==# 'registers'
        let list = [ '"', '+', '-', '*', '/', '=' ]
        call extend(list, map(range(48,57)+range(97,122), 'nr2char(v:val)'))
    endif
    return list
endfu

fu! s:color_as_filename(pat) abort "{{{1
    call  matchadd('qfFileName', a:pat, 0, -1)
endfu

fu! s:conceal(pat) abort "{{{1
    setl cocu=nc cole=3
    call matchadd('Conceal', a:pat, 0, -1, { 'conceal': 'x' })
endfu

fu! s:convert(output, cmd, bang) abort "{{{1
    if a:cmd ==# 'ls'
        call filter(a:output, a:bang ? 'bufexists(v:val)' : 'buflisted(v:val)')
        call map(a:output, '{ "bufnr": v:val }')
        for item in a:output
            if empty(bufname(item.bufnr))
                let item.text = '[No Name]'
            endif
        endfor

    elseif a:cmd ==# 'changes'
        call map(a:output, '{
        \                     "lnum":  matchstr(v:val, ''\v^%(\s+\d+){1}\s+\zs\d+''),
        \                     "col":   matchstr(v:val, ''\v^%(\s+\d+){2}\s+\zs\d+''),
        \                     "text":  matchstr(v:val, ''\v^%(\s+\d+){3}\s+\zs.*''),
        \                     "bufnr": bufnr(""),
        \                   }')
        " all entries should show some text, otherwise it's impossible to know
        " what changed, and they're useless
        call filter(a:output, '!empty(v:val.text)')

    elseif a:cmd ==# 'marks'
        call map(a:output, '{
        \                     "mark_name":  matchstr(v:val, ''\S\+''),
        \                     "lnum":       matchstr(v:val, ''\v^\s*\S+\s+\zs\d+''),
        \                     "col":        matchstr(v:val, ''\v^\s*\S+%(\s+\zs\d+){2}''),
        \                     "text":       matchstr(v:val, ''\v^\s*\S+%(\s+\d+){2}\s+\zs.*''),
        \                     "filename":   matchstr(v:val, ''\v^\s*\S+%(\s+\d+){2}\s+\zs.*''),
        \                   }')

        "                                                      ┌─ it's important to expand the filename
        "                                                      │  otherwise, if there's a tilde (for $HOME),
        "                                                      │  clicking on the entry will load an empty
        "                                                      │  buffer (with the right filepath; weird …)
        "                                                      │
        let Global_mark = { item -> extend(item, { 'filename': expand(item.filename),
                                                 \ 'text': item.mark_name }) }

        "                           ┌─ `remove()` returns the removed item,
        "                           │  but `extend()` does NOT return the added item;
        "                           │  instead returns the new extended dictionary
        "                           │
        let Local_mark  = { item -> extend(item, { 'filename': expand('%:p'),
                                                 \ 'text': item.mark_name.'    '.item.text }) }

        call map(a:output, printf(
        \                          '%s ? %s : %s',
        \                          'filereadable(expand(v:val.filename))',
        \                          'Global_mark(v:val)',
        \                          a:bang ? 'Local_mark(v:val)' : '{}'
        \                        )
        \       )

        " remove possible empty dictionaries  which may have appeared after previous
        " `map()` invocation
        call filter(a:output, '!empty(v:val)')

        " if no bang was given, we're only interested in global marks, so remove
        " '0, …, '9 marks
        if !a:bang
            call filter(a:output, 'v:val.text !~# "\\d"')
        endif

        for mark in a:output
            " remove the `mark_name` key, it's not needed anymore
            call remove(mark, 'mark_name')
        endfor

    elseif a:cmd ==# 'oldfiles'
        call map(a:output, '{
        \                     "text"     : matchstr(v:val, ''\v^\d+\ze:\s.*''),
        \                     "filename" : matchstr(v:val, ''\v^\d+:\s\zs.*''),
        \                   }')

    elseif a:cmd ==# 'registers'
        " Do NOT use the `filename` key to store the name of the registers.
        " Why?
        " After executing `:LReg`, Vim would load buffers "a", "b", …
        " They would pollute the buffer list (`:ls!`).
        call map(a:output, '{ "text": v:val }')

        " We pass `1` as a 2nd argument to `getreg()`.
        " It's ignored  for most registers,  but useful for the  expression register.
        " It allows to get the expression  itself, not its current value which could
        " not exist anymore (ex: a:arg)
        call map(a:output, '
        \                    extend(v:val, {
        \                                    "text":  v:val.text
        \                                            ."    "
        \                                            .substitute(getreg(v:val.text, 1), "\n", "^J", "g")
        \                                  })
        \                  ')

    endif
    return a:output
endfu

fu! interactive_lists#main(cmd, bang) abort "{{{1
    try
        let output = s:capture(a:cmd)
        let list   = s:convert(output, a:cmd, a:bang ? 1 : 0)

        if empty(list) && a:cmd ==# 'args'
            return 'echoerr "No arguments"'
        endif

        call setloclist(0, list)
        call setloclist(0, [], 'a', { 'title': ':'.a:cmd.(a:bang ? '!' : '') })

        lopen
        let pat = {
        \           'args'      : '|\s*|\s*$',
        \           'changes'   : '^\v.{-}\|\s*\d+%(\s+col\s+\d+\s*)?\s*\|\s?',
        \           'ls'        : '\v\|\s*\|\s*%(\ze\[No Name\]\s*)?$',
        \           'marks'     : '\v^.{-}\zs\|.{-}\|\s*',
        \           'oldfiles'  : '|\s*|\s*',
        \           'registers' : '\v^\s*\|\s*\|\s*',
        \         }[a:cmd]

        call s:conceal(pat)
        if a:cmd ==# 'ls'
            call s:color_as_filename('\[No Name\]$')
        elseif a:cmd ==# 'registers'
            call s:color_as_filename('\v^\s*\|\s*\|\s*\zs\S+')
        endif
    catch
        return 'echoerr '.string(v:exception)
    endtry
    return ''
endfu
