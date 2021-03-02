vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# TODO: Use `:h  quickfix-window-function` to get rid  of `qf#setMatches()` and
# `qf#createMatches()`.

import Catch from 'lg.vim'
import QfOpenOrFocus from 'lg/window.vim'

# Interface {{{1
def interactiveLists#main(cmd: string, bang = false): string #{{{2
    var cmdline: string
    try
        cmdline = getcmdline()
        if cmd == 'number' && cmdline[-1] != '#'
            return cmdline
        endif
        var output: list<any> = Capture(cmd, bang)
        if cmd == 'number' && get(output, 0, '') =~ '^Pattern not found:'
            timer_start(0, () => feedkeys("\<cr>", 'in'))
            Error('Pattern not found')
        endif
        var list: list<any> = Convert(output, cmd, bang)

        if empty(list)
            if cmd == 'args'
                Error('No arguments')
                return ''
            elseif cmd == 'number'
                return cmdline
            else
                Error('No output')
                return ''
            endif
        endif

        setloclist(0, [], ' ', {
            items: list
                    ->mapnew((_, v: any): dict<any> =>
                                has_key(v, 'lnum')
                                    ? extend(v, {lnum: v.lnum})
                                    : v
                    ),
            title: cmd == 'marks'
                    ?     ':Marks' .. (bang ? '!' : '')
                    : cmd == 'number'
                    ?     ':' .. cmdline
                    :     ':' .. cmd .. (bang ? '!' : ''),
        })

        if cmd == 'number'
            timer_start(0, () => [OpenQf('number'), feedkeys("\e", 'in')])
        else
            OpenQf(cmd)
        endif
    catch
        return cmd == 'number'
            ?     cmdline
            :     Catch()
    endtry
    return ''
enddef

def Error(msg: string)
    echohl ErrorMsg
    echom msg
    echohl NONE
enddef

def interactiveLists#allmatchesinbuffer() #{{{2
    # Alternative:
    #
    #     keepj g//#

    var id: number = win_getid()
    var view: dict<number> = winsaveview()
    try
        # Why `:exe`?{{{
        #
        # It removes excessive spaces in the title of the qf window, between the
        # colon and the rest of the command.
        #}}}
        #   Why is it necessary?{{{
        #
        # Because Vim copies the indentation of the command.
        #
        # MWE:
        #
        #     :nno cd <cmd>lvim /./ % <bar> lopen<cr>
        #
        #     " press:  cd
        #     :lopen
        #     title = ':lvim /./ %'    ✔~
        #
        #     nno cd <cmd>call Func()<cr>
        #     fu Func() abort
        #         lvim /./ %
        #         lopen
        #     endfu
        #
        #     " press:  cd
        #     title = ':    lvim /./ %'~
        #               ^--^
        #               ✘ because `:lvim` is executed from a line~
        #                 with a level of indentation of 4 spaces~
        #
        #     nno cd <cmd>call Func()<cr>
        #     fu Func() abort
        #         try
        #             lvim /./ %
        #             lopen
        #         endtry
        #     endfu
        #
        #     " press:  cd
        #     title = ':        lvim /./ %'~
        #               ^------^
        #                ✘ because `:lvim` is executed from a line~
        #                  with a level of indentation of 8 spaces~
        #}}}
        #   Is there an alternative?{{{
        #
        # Yes, but it's more complicated:
        #
        #     if &bt == 'quickfix'
        #         w:quickfix_title = ':' .. matchstr(w:quickfix_title, ':\s*\zs\S.*')
        #     endif
        #}}}
        exe 'lvim //gj %'
        #            │
        #            └ don't jump to the first entry;
        #              stay in the qf window
        lwindow
        if &bt == 'quickfix'
            sil! qf#setMatches('vimrc:allMatchesInBuffer', 'Conceal', 'location')
            sil! qf#createMatches()
        endif
    catch
        Catch()
        return
    finally
        win_gotoid(id)
        winrestview(view)
    endtry
    if winnr('#')->winbufnr()->getbufvar('&bt', '') == 'quickfix'
        wincmd p
    endif
enddef

def interactiveLists#setorgotomark(action: string) #{{{2
    # ask for a mark
    var mark: string = getchar()->nr2char(1)
    if mark == "\e"
        return
    endif

    # If it's not a global one, just type the keys as usual (with one difference):{{{
    #
    #    - mx
    #    - `x
    #      ^
    #      let's use backtick instead of a single quote, so that we land on the exact column
    #      rationale: the single quote key is easier to type
    #}}}
    if range(char2nr('A'), char2nr('Z'))->index(char2nr(mark)) == -1
        feedkeys((action == 'set' ? 'm' : "`") .. mark, 'in')
        return
    endif

    # now, we process a global mark
    # first, get the path to the file containing the bookmarks
    var book_file: string = $HOME .. '/.vim/bookmarks'
    if !filereadable(book_file)
        echo book_file .. ' is not readable'
        return
    endif

    # we *set* a global mark
    if action == 'set'
        var new_bookmarks: list<string> = book_file
            ->readfile()
            # eliminate old mark if it's present
            ->filter((_, v: string): bool => v[0] != mark)
            # and bookmark current file
            + [mark .. ':' .. expand('%:p')->substitute('\V' .. $HOME, '$HOME', '')]

        new_bookmarks
            ->sort()
            ->writefile(book_file)

    # we *jump* to a global mark
    else
        var lpath: list<string> = book_file
            ->readfile()
            ->filter((_, v: string): bool => v[0] == mark)
        if lpath == [] || lpath[0][2 :] == ''
            return
        endif
        var path: string = lpath[0][2 :]
        exe 'e ' .. path
        # '. may not exist
        try
            sil! norm! g`.zvzz
            #  │
            #  └ E20: mark not set
        catch
            Catch()
            return
        endtry
    endif
    # re-mark the file, to fix Vim's frequent and unavoidable lost marks
    feedkeys('m' .. mark, 'in')
enddef
#}}}1
# Core {{{1
def Capture(cmd: string, bang: bool): list<any> #{{{2
    var list: list<any>
    if cmd == 'args'
        list = argv()
            ->mapnew((_, v: string): dict<string> => ({
                filename: v,
                text: fnamemodify(v, ':t'),
                }))

    elseif cmd == 'changes'
        list = CaptureCmdLocalToWindow('changes', '^\%(\s\+\d\+\)\{3}')

    elseif cmd == 'jumps'
        list = CaptureCmdLocalToWindow('jumps', '^')

    elseif cmd == 'ls'
        list = range(1, bufnr('$'))
                ->filter(bang
                    ? (_, v: number): bool => bufexists(v)
                    : (_, v: number): bool => buflisted(v))

    elseif cmd == 'marks'
        if bang
            list = bufnr('%')->getmarklist()
        else
            # for global marks, we're only interested in the numbered ones
            list = getmarklist()
                    ->filter((_, v: dict<any>): bool => v.mark =~ '''\d')
        endif

    elseif cmd == 'number'
        var pos: list<number> = getcurpos()
        list = execute('keepj ' .. getcmdline()->substitute('#$', 'number', ''))->split('\n')
        setpos('.', pos)

    elseif cmd == 'oldfiles'
        list = execute('old')->split('\n')

    elseif cmd == 'registers'
        list =<< trim END
            #
            +
            -
            *
            /
            =
        END
        list->extend((range(48, 57) + range(97, 122))
            ->mapnew((_, v: number): string => nr2char(v)))
    endif
    return list
enddef

def CaptureCmdLocalToWindow(cmd: string, pat: string): list<any> #{{{2
# The changelist is local to a window.
# If we are in a location window, `g:c`  will show us the changes in the latter.
# But, we  are *not*  interested in them.   We want the  ones in  the associated
# window.  Same thing for the jumplist and the local marks.

    if cmd == 'jumps'
        var jumplist: list<any>
        if &bt == 'quickfix'
            noa QfOpenOrFocus('loc')
            jumplist = getjumplist()
                     ->get(0, [])
                     ->mapnew((_, v: dict<number>): dict<any> =>
                                extendnew(v, {
                                                text: bufnr('%') == v.bufnr
                                              ?     getline(v.lnum)
                                              :     bufname(v.bufnr)
                                             }))
            noa wincmd p
            return jumplist
        else
            return getjumplist()
                ->get(0, [])
                ->mapnew((_, v: dict<number>): dict<any> =>
                            extendnew(v, {
                                             text: bufnr('%') == v.bufnr
                                           ?     getline(v.lnum)
                                           :     bufname(v.bufnr)
                                         }))
        endif

    elseif cmd == 'changes'
        var changelist: list<any>
        if &bt == 'quickfix'
            noa QfOpenOrFocus('loc')
            changelist = getchangelist('%')->get(0, [])
            var bufnr: number = bufnr('%')
            for i in changelist->len()->range()
                changelist[i] = extendnew(changelist[i], {
                    text: getline(changelist[i]['lnum']),
                    bufnr: bufnr,
                    })
            endfor
            noa wincmd p
        else
            changelist = getchangelist('%')->get(0, [])
            var bufnr: number = bufnr('%')
            for i in changelist->len()->range()
                # Do *not* try to replace `changelist[i]` with a variable name.{{{
                #
                # You could  be tempted to  use it everywhere, including  in the
                # lhs of the assignment:
                #
                #     var item: dict<number> = changelist[i]
                #     item = extendnew(item, {
                #         text: getline(item.lnum),
                #         bufnr: bufnr,
                #         })
                #
                # That's wrong:
                #                      this is a reference to an item in the changelist (good)
                #                      v--v
                #     item = extendnew(item, {
                #     ^--^
                #     this is NOT a reference to an item in the changelist (bad);
                #     it's just a variable name
                #}}}
                changelist[i] = extendnew(changelist[i], {
                    text: getline(changelist[i]['lnum']),
                    bufnr: bufnr,
                    })
            endfor
        endif
        # all entries should show some text, otherwise it's impossible to know
        # what changed, and they're useless
        return changelist->filter((_, v: dict<any>): bool => !v.text->empty())
    endif
    return []
enddef

def Convert(arg_output: list<any>, cmd: string, bang: bool): list<any> #{{{2
    var output: list<any>
    if cmd == 'args' || cmd == 'changes'
        output = arg_output

    elseif cmd == 'ls'
        # Why is the first character in `printf()` a no-break space?{{{
        #
        # Because, by default,  Vim reduces all leading spaces in  the text to a
        # single space.  We don't want that.  We  want them to be left as is, so
        # that the  buffer numbers  are right  aligned in  their field.   So, we
        # prefix the text with a character  which is not a whitespace, but looks
        # like one.
        #}}}
        output = arg_output
            ->mapnew((_, v: number): dict<any> => ({
                bufnr: v,
                text: printf(' %*d%s%s%s%s%s %s',
                                bufnr('$')->len(), v,
                               !buflisted(v) ? 'u' : ' ',
                               v == bufnr('%') ? '%' : v == bufnr('#') ? '#' : ' ',
                               win_findbuf(v)->empty() ? 'h' : 'a',
                               getbufvar(v, '&ma', 0) ? ' ' : '-',
                               getbufvar(v, '&mod', 0) ? '+' : ' ',
                               bufname(v)->empty()
                                 ?    '[No Name]'
                                 :     bufname(v)->fnamemodify(':t'))
            }))

    elseif cmd == 'jumps'
        # Why?{{{
        #
        # For some reason, `getjumplist()` seems to include in the list an item
        # matching the location: (buffer, line, col) = (1, 0, 0)
        # The issue may  come from the fact  that when we start Vim,  we have an
        # unnamed and empty buffer.  Then, Vim restores a session automatically.
        # In the process, this buffer n°1 is probably wiped.
        #}}}
        output = arg_output
            ->filter((_, v: dict<any>): bool => bufexists(v.bufnr))

    # `:Marks!` → local marks only
    elseif cmd == 'marks' && bang
        output = arg_output
            ->map((_, v: dict<any>): dict<any> => ({
                    bufnr: v.pos[0],
                    lnum: v.pos[1],
                    col: v.pos[2],
                    text: v.mark .. '  ' .. getbufline(v.pos[0], v.pos[1])[0],
                    }))

    # `:Marks`  → global marks only
    elseif cmd == 'marks' && !bang
        if !filereadable($HOME .. '/.vim/bookmarks')
            return []
        endif
        var bookmarks: list<string> = readfile($HOME .. '/.vim/bookmarks')

        var enriched_bookmarks: list<dict<any>> = bookmarks
            ->mapnew((_, v: string): dict<string> => ({
                        text: v[0] .. '  ' .. matchstr(v, ':\zs.*')->fnamemodify(':t'),
                        filename: matchstr(v, ':\zs.*')->expand(),
                        }))

        output = arg_output
            ->map((_, v: dict<any>): dict<any> => ({
                    text: v.mark[1 : 1] .. '  ' .. fnamemodify(v.file, ':t'),
                    filename: v.file,
                    lnum: v.pos[1],
                    col: v.pos[2],
                    }))
        enriched_bookmarks += output
        return enriched_bookmarks

    elseif cmd == 'number'
        output = arg_output
            ->mapnew((_, v: string): dict<any> => ({
                        filename: expand('%:p'),
                        lnum: matchstr(v, '^\s*\zs\d\+')->str2nr(),
                        text: matchstr(v, '^\s*\d\+\s\zs.*'),
                        }))

    elseif cmd == 'oldfiles'
        output = arg_output
            ->mapnew((_, v: string): dict<string> => ({
                        filename: matchstr(v, '^\d\+:\s\zs.*')->expand(),
                        text: matchstr(v, '^\d\+:\s\zs.*')->fnamemodify(':t'),
                        }))

    elseif cmd == 'registers'
        # Do *not* use the `filename` key to store the name of the registers.{{{
        #
        # After pressing `g:r`, Vim would load buffers "a", "b", ...
        # They would pollute the buffer list (`:ls!`).
        #}}}
        output = arg_output
            ->mapnew((_, v: string): dict<string> => ({text: v}))

        # We pass `1` as a 2nd argument to `getreg()`.
        # It's ignored  for most registers,  but useful for the  expression register.
        # It allows to get the expression  itself, not its current value which could
        # not exist anymore (ex: arg)
        output->map((_, v: dict<string>): dict<string> =>
                        extend(v, {
                                    text: v.text .. '    ' .. getreg(v.text, true)
                                  }))

    endif
    return output
enddef

def OpenQf(cmd: string) #{{{2
    # We don't want to open the qf  window directly, because it's the job of our
    # `vim-qf` plugin.   The latter uses some  logic to decide the  position and
    # the size of the qf window.
    # `:lopen`  or  `:lwindow` would  just  open  the  window with  its  default
    # position/size without any custom logic.
    #
    # So,  we just  emit the  event `QuickFixCmdPost`.  `vim-qf` has  an autocmd
    # listening to it.
    do <nomodeline> QuickFixCmdPost lopen

    var pat: string = {
        args:      '.*|\s*|\s*',
        changes:   'location',
        jumps:     '^.\{-}\ze|',
        ls:        '.*|\s*|\s*\ze\%(\[No Name\]\s*\)\=.*$',
        marks:     '^.\{-}|.\{-}|\s*',
        number:    '.*|\s*\d\+\s*|\s\=',
        oldfiles:  '.\{-}|\s*|\s*',
        registers: '^\s*|\s*|\s*',
        }[cmd]

    sil! qf#setMatches('interactive_lists:OpenQf', 'Conceal', pat)

    if cmd == 'registers'
        sil! qf#setMatches('interactive_lists:OpenQf', 'qfFileName', '^\s*|\s*|\s\zs\S\+')
    endif
    sil! qf#createMatches()
enddef

