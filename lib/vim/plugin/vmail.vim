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
    call s:RunVmail()
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
    if !has('ruby')
        echoerr "Vim must be compiled with Ruby support to run Vmail."
        return 0
    endif
    return 1
endfu

let &cpo = s:savecpo
unlet s:savecpo
