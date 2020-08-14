nnoremap <buffer> l <nop>
nnoremap <buffer> h <nop>

nnoremap <buffer> j <cmd>lua require'todoist-nvim.ui'.move_cursor_down()<cr>
nnoremap <buffer> k <cmd>lua require'todoist-nvim.ui'.move_cursor_up()<cr>

nnoremap <buffer> x <cmd>lua require'todoist-nvim.ui'.check_or_uncheck_task()<cr>
