if exists('g:autoloaded_interactive_lists')
    finish
endif
let g:autoloaded_interactive_lists = 1

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
        call qf#my_conceal('location')
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

    for item in list
        if empty(bufname(item.bufnr))
            let item.text = '[No Name]'
        endif
    endfor

    call setloclist(0, list)
    call setloclist(0, [], 'a', { 'title': ':ls'.(a:bang ? '!' : '') })
    lopen

    if &ft ==# 'qf'
        " make output less noisy by hiding ending `||`
        setl cocu=nc cole=3
        let pat = '\v\|\s*\|\s*%(\ze\[No Name\]\s*)?$'
        call matchadd('Conceal', pat, 0, -1, { 'conceal': 'x' })
    endif

    return ''
endfu

fu! interactive_lists#lmarks(bang) abort "{{{1
    let marks = split(execute('marks'), '\n')
    call filter(marks, 'v:val =~ ''\v^\s+\S+%(\s+\d+){2}''')
    call map(marks, '{
                     \   "mark_name":  matchstr(v:val, ''\S\+''),
                     \   "lnum":       matchstr(v:val, ''\v^\s*\S+\s+\zs\d+''),
                     \   "col":        matchstr(v:val, ''\v^\s*\S+%(\s+\zs\d+){2}''),
                     \   "text":       matchstr(v:val, ''\v^\s*\S+%(\s+\d+){2}\s+\zs.*''),
                     \   "filename":   matchstr(v:val, ''\v^\s*\S+%(\s+\d+){2}\s+\zs.*''),
                     \ }')

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

    call map(marks,
    \'              filereadable(expand(v:val.filename))
    \?                  Global_mark(v:val)
    \:                  '.(a:bang ? "Local_mark(v:val)" : "{}")
    \       )

    " remove possible empty dictionaries  which may have appeared after previous
    " `map()` invocation
    call filter(marks, '!empty(v:val)')

    " if no bang was given, we're only interested in global marks, so remove
    " '0, …, '9 marks
    if !a:bang
        call filter(marks, 'v:val.text !~# "\\d"')
    endif

    for mark in marks
        " remove the `mark_name` key, it's not needed anymore
        call remove(mark, 'mark_name')
    endfor

    call setloclist(0, marks)
    call setloclist(0, [], 'a', { 'title': ':marks' })
    lopen
    if &ft ==# 'qf'
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
