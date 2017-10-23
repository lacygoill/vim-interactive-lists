if exists('g:autoloaded_interactive_lists')
    finish
endif
let g:autoloaded_interactive_lists = 1

fu! interactive_lists#args() abort "{{{1
    try
        let list = s:capture('args')
        if empty(list)
            return 'echoerr "No arguments"'
        endif
        call setloclist(0, list)
        call setloclist(0, [], 'a', { 'title': ':args' })
        lopen
        call s:conceal('|\s*|\s*$')
    catch
        return 'echoerr '.string(v:exception)
    endtry
    return ''
endfu

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

    elseif a:cmd ==# 'old'
        let list = split(execute('old'), '\n')

    elseif a:cmd ==# 'registers'
        let list = [ '"', '+', '-', '*', '/', '=' ]
        call extend(list, map(range(48,57)+range(97,122), 'nr2char(v:val)'))
    endif
    return list
endfu

fu! interactive_lists#changes() abort "{{{1
    try
        let list = s:capture('changes')
        call map(list, '{
        \                 "lnum":  matchstr(v:val, ''\v^%(\s+\d+){1}\s+\zs\d+''),
        \                 "col":   matchstr(v:val, ''\v^%(\s+\d+){2}\s+\zs\d+''),
        \                 "text":  matchstr(v:val, ''\v^%(\s+\d+){3}\s+\zs.*''),
        \                 "bufnr": bufnr(""),
        \               }')
        " all entries should show some text, otherwise it's impossible to know
        " what changed, and they're useless
        call filter(list, '!empty(v:val.text)')
        call setloclist(0, list)
        call setloclist(0, [], 'a', { 'title': ':changes' })
        lopen
        call s:conceal('^\v.{-}\|\s*\d+%(\s+col\s+\d+\s*)?\s*\|\s?')
    catch
        return 'echoerr '.string(v:exception)
    endtry
    return ''
endfu

fu! s:color_as_filename(pat) abort "{{{1
    call  matchadd('qfFileName', a:pat, 0, -1)
endfu

fu! s:conceal(pat) abort "{{{1
    setl cocu=nc cole=3
    call matchadd('Conceal', a:pat, 0, -1, { 'conceal': 'x' })
endfu

" fu! s:format() abort "{{{1
"     setl nowrap
"     if !executable('column') || !executable('sed')
"         return
"     endif
"     setl modifiable
"     sil! exe "%!sed 's/|/\<c-a>|/1'"
"     sil! exe "%!sed 's/|/\<c-a>|/2'"
"     sil! exe "%!column -s '\<c-a>' -t"
"     setl nomodifiable nomodified
" endfu

fu! interactive_lists#ls(bang) abort "{{{1
    try
        let list = s:capture('ls')

        " [2, 5, 6, 10, …]
        call filter(list, a:bang ? 'bufexists(v:val)' : 'buflisted(v:val)')
        " [{'bufnr': 2}, {'bufnr': 5}, {'bufnr': 6}, {'bufnr': 10}, …]
        call map(list, '{ "bufnr": v:val }')

        for item in list
            if empty(bufname(item.bufnr))
                let item.text = '[No Name]'
            endif
        endfor

        call setloclist(0, list)
        call setloclist(0, [], 'a', { 'title': ':ls'.(a:bang ? '!' : '') })
        lopen
        " make output less noisy by hiding ending `||`
        call s:conceal('\v\|\s*\|\s*%(\ze\[No Name\]\s*)?$')
        call s:color_as_filename('\[No Name\]$')
    catch
        return 'echoerr '.string(v:exception)
    endtry
    return ''
endfu

fu! interactive_lists#marks(bang) abort "{{{1
    try
        let list = s:capture('marks')
        call map(list, '{
        \                 "mark_name":  matchstr(v:val, ''\S\+''),
        \                 "lnum":       matchstr(v:val, ''\v^\s*\S+\s+\zs\d+''),
        \                 "col":        matchstr(v:val, ''\v^\s*\S+%(\s+\zs\d+){2}''),
        \                 "text":       matchstr(v:val, ''\v^\s*\S+%(\s+\d+){2}\s+\zs.*''),
        \                 "filename":   matchstr(v:val, ''\v^\s*\S+%(\s+\d+){2}\s+\zs.*''),
        \               }')

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

        call map(list, printf(
        \                      '%s ? %s : %s',
        \                      'filereadable(expand(v:val.filename))',
        \                      'Global_mark(v:val)',
        \                      a:bang ? 'Local_mark(v:val)' : '{}'
        \                     )
        \       )

        " remove possible empty dictionaries  which may have appeared after previous
        " `map()` invocation
        call filter(list, '!empty(v:val)')

        " if no bang was given, we're only interested in global marks, so remove
        " '0, …, '9 marks
        if !a:bang
            call filter(list, 'v:val.text !~# "\\d"')
        endif

        for mark in list
            " remove the `mark_name` key, it's not needed anymore
            call remove(mark, 'mark_name')
        endfor

        call setloclist(0, list)
        call setloclist(0, [], 'a', { 'title': ':Marks'.(a:bang ? '!' : '') })
        lopen
        call s:conceal('\v^.{-}\zs\|.{-}\|\s*')
    catch
        return 'echoerr '.string(v:exception)
    endtry
    return ''
endfu

fu! interactive_lists#old() abort "{{{1
    let list = s:capture('old')
    return ''
endfu

fu! interactive_lists#reg() abort "{{{1
    try
        let list = s:capture('registers')

        " Do NOT use the `filename` key to store the name of the registers.
        " Why?
        " After executing `:LReg`, Vim would load buffers "a", "b", …
        " They would pollute the buffer list (`:ls!`).
        call map(list, '{ "text": v:val }')

        " We pass `1` as a 2nd argument to `getreg()`.
        " It's ignored  for most registers,  but useful for the  expression register.
        " It allows to get the expression  itself, not its current value which could
        " not exist anymore (ex: a:arg)
        call map(list, '
        \                extend(v:val, {
        \                                "text":  v:val.text
        \                                        ."    "
        \                                        .substitute(getreg(v:val.text, 1), "\n", "^J", "g")
        \                              })
        \              ')

        call setloclist(0, list)
        call setloclist(0, [], 'a', { 'title': ':reg' })
        lopen
        call s:conceal('\v^\s*\|\s*\|\s*')
        call s:color_as_filename('\v^\s*\|\s*\|\s*\zs\S+')
    catch
        return 'echoerr '.string(v:exception)
    endtry
    return ''
endfu
