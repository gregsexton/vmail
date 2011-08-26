"if exists("g:loaded_vmail") || v:version < 700
  "finish
"endif
"let g:loaded_vmail = 1

let s:savecpo = &cpo
set cpo&vim

command! -nargs=* Vmail call s:OpenVmail(shellescape(<q-args>))

fu! s:OpenVmail(...)
    "do nothing with the args for the moment.
    if !s:TestForCompatability()
        return
    endif
    vnew
    if exists("g:vmail_buffer_number")
        exec "buf " . g:vmail_buffer_number
    else
        call s:RunVmail()
    endif
endfu

fu! s:RunVmail()
    let buffer_path = s:StartForkedProcess()
    if buffer_path == ""
        return
    endif

    call s:WaitForBufferToBeWritten(buffer_path)

    if !filereadable(buffer_path)
        echoerr "Could not read vmail buffer."
        return
    endif
    let buffer = readfile(buffer_path)

    call s:ExtractEnvironmentVars(buffer)
    let script_path = s:ExtractScriptPath(buffer)

    if script_path == ""
        echoerr "Could not read initial script path from vmail buffer."
        return
    endif

    exec "e " . buffer_path
    exec "so " . script_path

    nnoremap <silent> <buffer> q :q<cr>
    augroup VmailExtension
        au! 
        autocmd VimLeavePre * call <SID>QuitVmail()
    augroup END

    let g:vmail_buffer_number = bufnr("%")
endfu

fu! s:WaitForBufferToBeWritten(buffer_path)
    let modified = getftime(a:buffer_path)
    while getftime(a:buffer_path) == modified
        sleep 200 m
    endwhile

    return
endfu

fu! s:ExtractEnvironmentVars(buffer)
    call s:AssignEnvironmentVar(a:buffer, '$DRB_URI')
    call s:AssignEnvironmentVar(a:buffer, '$VMAIL_BROWSER')
    call s:AssignEnvironmentVar(a:buffer, '$VMAIL_CONTACTS_FILE')
    call s:AssignEnvironmentVar(a:buffer, '$VMAIL_MAILBOX')
    call s:AssignEnvironmentVar(a:buffer, '$VMAIL_QUERY')
endfu

fu! s:AssignEnvironmentVar(buffer, var)
    let match = matchstr(a:buffer, '\'.a:var.'.*')
    if match == ""
        echoerr "Could not find environment variable: " . a:var
        return
    else
        exec "let " . match
    endif
endfu

fu! s:ExtractScriptPath(buffer)
    for line in a:buffer
        let matches = matchlist(line, '^INIT_SCRIPT=\(.*\)$')
        if !empty(matches)
            return matches[1]
        endif
    endfor
    return ""
endfu

fu! s:StartForkedProcess()
    "let output = system("vmail --fork")
    redir => output
    silent call s:ExecuteForkCommand()
    redir END
    if v:shell_error
        echoerr "Failed to start vmail server."
        return "fail"
    endif

    return s:GetBufferPath(output)
endfu

fu! s:ExecuteForkCommand()
    "seperated into function so can be called silently and still gives output.
    !vmail --fork
endfu

fu! s:GetBufferPath(output)
    let lines = split(a:output, '\r')
    for line in lines
        let match = matchlist(lines, 'Using buffer:\s\+\(.*\)$')
        if !empty(match)
            return match[1]
        endif
    endfor
    return "" 
endfu

fu! s:TestForCompatability()
    return 1
endfu

fu! s:QuitVmail()
    if exists("g:vmail_buffer_number")
        exec "bwipeout " . g:vmail_buffer_number
        call system("vmail_client " . shellescape($DRB_URI) . " close_and_exit")
        unlet g:vmail_buffer_number
    endif
endfu

let &cpo = s:savecpo
unlet s:savecpo
