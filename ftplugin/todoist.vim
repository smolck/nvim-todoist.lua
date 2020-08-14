nnoremap <buffer> l <nop>
nnoremap <buffer> h <nop>

nnoremap <buffer> j <cmd>lua require'todoist-nvim.ui'.move_cursor(false)<cr>
nnoremap <buffer> k <cmd>lua require'todoist-nvim.ui'.move_cursor(true)<cr>

nnoremap <buffer> x <cmd>lua require'todoist-nvim.ui'.check_or_uncheck_task()<cr>
