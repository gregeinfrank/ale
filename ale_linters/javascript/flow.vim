" Author: Zach Perrault -- @zperrault
" Description: FlowType checking for JavaScript files

call ale#Set('javascript_flow_executable', 'flow')
call ale#Set('javascript_flow_use_global', 0)

let g:ale_javascript_flow_use_relative_paths =
\   get(g:, 'ale_javascript_flow_use_relative_paths', 0)

function! ale_linters#javascript#flow#GetExecutable(buffer) abort
    return ale#node#FindExecutable(a:buffer, 'javascript_flow', [
    \   'node_modules/.bin/flow',
    \])
endfunction

function! ale_linters#javascript#flow#GetCommand(buffer) abort
    let l:flow_config = ale#path#FindNearestFile(a:buffer, '.flowconfig')

    if empty(l:flow_config)
        " Don't run Flow if we can't find a .flowconfig file.
        return ''
    endif

    if ale#Var(a:buffer, 'javascript_flow_use_relative_paths')
        let l:substitution_char = '%r'
    else
        let l:substitution_char = '%s'
    endif

    return ale#Escape(ale_linters#javascript#flow#GetExecutable(a:buffer))
    \   . ' check-contents --respect-pragma --json --from ale ' . l:substitution_char
endfunction

function! ale_linters#javascript#flow#Handle(buffer, lines) abort
    let l:str = join(a:lines, '')

    if l:str ==# ''
        return []
    endif

    if ale#Var(a:buffer, 'javascript_flow_use_relative_paths')
        let l:buffer_path = expand('#' . a:buffer)
    else
        let l:buffer_path = expand('#' . a:buffer . ':p')
    endif

    let l:flow_output = json_decode(l:str)
    let l:output = []

    for l:error in get(l:flow_output, 'errors', [])
        " Each error is broken up into parts
        let l:text = ''
        let l:line = 0
        let l:col = 0

        for l:message in l:error.message
            " Comments have no line of column information, so we skip them.
            " In certain cases, `l:message.loc.source` points to a different path
            " than the buffer one, thus we skip this loc information too.
            if has_key(l:message, 'loc')
            \&& l:line ==# 0
            \&& ale#path#IsBufferPath(l:buffer_path, l:message.loc.source)
                let l:line = l:message.loc.start.line + 0
                let l:col = l:message.loc.start.column + 0
            endif

            if l:text ==# ''
                let l:text = l:message.descr . ':'
            else
                let l:text = l:text . ' ' . l:message.descr
            endif
        endfor

        if has_key(l:error, 'operation')
            let l:text = l:text . ' See also: ' . l:error.operation.descr
        endif

        call add(l:output, {
        \   'lnum': l:line,
        \   'col': l:col,
        \   'text': l:text,
        \   'type': l:error.level ==# 'error' ? 'E' : 'W',
        \})
    endfor

    return l:output
endfunction

call ale#linter#Define('javascript', {
\   'name': 'flow',
\   'executable_callback': 'ale_linters#javascript#flow#GetExecutable',
\   'command_callback': 'ale_linters#javascript#flow#GetCommand',
\   'callback': 'ale_linters#javascript#flow#Handle',
\})
