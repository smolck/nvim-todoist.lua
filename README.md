# nvim-todoist.lua - Todoist plugin for NeoVim inspired by [todoist.nvim](https://github.com/romgrk/todoist.nvim)

## Setup + Installation

### Requirements
* [NeoVim 0.5.0 (nightly)](https://github.com/neovim/neovim/releases/tag/nightly)

Use your plugin manager of choice, like [vim-plug](junegunn/vim-plug) or
[packer.nvim](wbthomason/packer.nvim). Here's an example with vim-plug:

```vim
" Dependency
Plug 'norcalli/neovim-plugin', {'commit': '41ee2803d4a1cf38b9448bbfb936bfff23caed47'}
Plug 'nvim-lua/plenary.nvim'

Plug 'smolck/nvim-todoist.lua'
```

Just make sure that no matter what package manager you use, 
you install [neovim-plugin@41ee280](https://github.com/norcalli/neovim-plugin/commit/41ee2803d4a1cf38b9448bbfb936bfff23caed47) 
and [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) along with this plugin.

After you've done that, make sure to add this to your `init.vim` (after the `Plug` lines):

```vim
lua EOF <<
require'nvim-todoist'.neovim_stuff.use_defaults()
EOF
```

If you don't do that, none of this plugin's functions, like `:Todoist`, will work!

### API Token

First, get your Todoist API token from https://todoist.com/prefs/integrations. After that, set the `$TODOIST_API_KEY` environmental variable to
that token.

## Usage

Call `:Todoist` from within Neovim, and you'll be greeted by a floating window with your `Inbox` tasks. Alternatively, you can call `:Todoist <project name>`, e.g. `:Todoist Welcome`, to view tasks from a specific project.

### Mappings
| Command                                         | Default Mapping | Result                                                 |
|-------------------------------------------------|-----------------|--------------------------------------------------------|
| `:TodoistMoveCursorDown`/`:TodoistMoveCursorUp` | `j`/`k`         | Moves up and down between tasks                        |
| `:TodoistToggleTask`                            | `x`             | Closes/opens task under cursor                         |
| `:TodoistDeleteTask`                            | `dd`            | Deletes task under cursor                              |
| `:TodoistRefresh`                               | `r`             | Fetches latest tasks/projects & updates todoist buffer |
| `:TodoistCreateTask`                            | `c`             | Creates a new task after asking for content & date     |


## Contributing

Just create an issue or open a PR! Contributions are welcome and appreciated ;)
