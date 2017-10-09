fu! interactive_lists#largs() abort "{{{1
    let list = argv()
    call map(list, '{ "filename": v:val }')
    call setloclist(0, list)
    call setloclist(0, [], 'a', { 'title': ':args' })
    lopen
    if &ft ==# 'qf'
        setl cocu=nc cole=3
        call matchadd('Conceal', '|\s*|\s*$', 0, -1, { 'conceal': 'x' })
    endif
    return ''
endfu

fu! interactive_lists#lchanges() abort "{{{1
    let changes = split(execute('changes'), '\n')
    call filter(changes, 'v:val =~ ''\v^%(\s+\d+){3}''')
    call map(changes, '{
                     \   "lnum":  matchstr(v:val, ''\v^%(\s+\d+){1}\s+\zs\d+''),
                     \   "col":   matchstr(v:val, ''\v^%(\s+\d+){2}\s+\zs\d+''),
                     \   "text":  matchstr(v:val, ''\v^%(\s+\d+){3}\s+\zs.*''),
                     \   "bufnr": bufnr(""),
                     \ }')
    call setloclist(0, changes)
    call setloclist(0, [], 'a', { 'title': ':changes' })
    lopen
    if &ft == 'qf'
        norm coq
    endif
    return ''
endfu

fu! interactive_lists#lls(bang) abort "{{{1
    " [1, 2, 3, …]
    let list = range(1, bufnr('$'))
    " [2, 5, 6, 10, …]
    call filter(list, a:bang ? 'bufexists(v:val)' : 'buflisted(v:val)')
    " [{'bufnr': 2}, {'bufnr': 5}, {'bufnr': 6}, {'bufnr': 10}, …]
    call map(list, '{ "bufnr": v:val }')

    call setloclist(0, list)
    call setloclist(0, [], 'a', { 'title': ':ls'.(a:bang ? '!' : '') })
    lopen

    if &ft ==# 'qf'
        " make output less noisy by hiding ending `||`
        setl cocu=nc cole=3
        call matchadd('Conceal', '|\s*|\s*$', 0, -1, { 'conceal': 'x' })
    endif

    return ''
endfu

fu! interactive_lists#lmarks() abort "{{{1
    let marks = split(execute('marks'), '\n')
    call filter(marks, 'v:val =~ ''\v^\s+\S+%(\s+\d+){2}''')
    call map(marks, '{
                     \   "pattern":   matchstr(v:val, ''\S\+''),
                     \   "lnum":      matchstr(v:val, ''\v^\s*\S+\s+\zs\d+''),
                     \   "col":       matchstr(v:val, ''\v^\s*\S+%(\s+\zs\d+){2}''),
                     \   "text":      matchstr(v:val, ''\v^\s*\S+%(\s+\d+){2}\s+\zs.*''),
                     \   "filename":  matchstr(v:val, ''\v^\s*\S+%(\s+\d+){2}\s+\zs.*''),
                     \ }')

    "                                                      ┌─ it's important to expand the filename
    "                                                      │  otherwise, if there's a tilde (for $HOME),
    "                                                      │  clicking on the entry will load an empty
    "                                                      │  buffer (with the right filepath; weird …)
    "                                                      │
    let Global_mark = { item -> extend(item, { 'filename': expand(item.filename),
                                             \ 'text': item.pattern }) }
                                             "              │
                                             "              └─ we “abuse“ the `pattern` key
                                             "                 to store the name of a mark

    let Local_mark  = { item -> extend(item, { 'filename': expand('%:p'),
                                             \ 'text': item.pattern.'    '.item.text }) }

    call map(marks,'
    \               !filereadable(expand(v:val.filename))
    \              ?     Local_mark(v:val)
    \              :     Global_mark(v:val)
    \              ')

    call setloclist(0, marks)
    call setloclist(0, [], 'a', { 'title': ':marks' })
    lopen
    if &ft == 'qf'
        setl cocu=nc cole=3
        let pat = '\v^.{-}\zs\|.{-}\|\s*'
        call matchadd('Conceal', pat, 0, -1, { 'conceal': 'x' })
    endif
    return ''
endfu

fu! interactive_lists#lreg() abort "{{{1
    let registers = ['"', '+', '-', '*', '/', '=']
    call extend(registers, map(range(48,57)+range(97,122), 'nr2char(v:val)'))

    call map(registers, '{ "filename": v:val }')
    call map(registers, 'extend(v:val, { "text": substitute(getreg(v:val.filename), "\n", "^J", "g") })')
    call setloclist(0, registers)
    call setloclist(0, [], 'a', { 'title': ':reg' })
    lopen
    if &ft ==# 'qf'
        setl cocu=nc cole=3
        let pat = '\v^\S\s+\zs\|\s*\|'
        call matchadd('Conceal', pat, 0, -1, { 'conceal': 'x' })
    endif
    return ''
endfu
