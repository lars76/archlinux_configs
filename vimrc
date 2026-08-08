" Must be first: 'nocompatible' enables line-continuation and modern behaviour.
" vim-sensible also sets it, but that plugin may not be installed yet on a fresh
" machine (or when started with `vim -u this-file`), so set it explicitly here.
set nocompatible

" =============================================================================
" §1. Plugin Manager: vim-plug
" =============================================================================
" Auto-install vim-plug if it's not present.
if empty(glob('~/.vim/autoload/plug.vim')) && $USER !=# 'root'
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

if !empty(glob('~/.vim/autoload/plug.vim'))
  call plug#begin('~/.vim/plugged')

  " --- Core & Appearance (Load on Startup) ---
  Plug 'tpope/vim-sensible'              " A collection of sensible default settings.
  Plug 'sheerun/vim-polyglot'             " A huge collection of language syntax packs.
  Plug 'vim-airline/vim-airline'          " Advanced status line.
  Plug 'vim-airline/vim-airline-themes'   " Themes for the status line.
  Plug 'jiangmiao/auto-pairs'            " Auto-close brackets and quotes.
  Plug 'catppuccin/vim', { 'as': 'catppuccin' }  " Catppuccin colorscheme (mocha).
  Plug 'airblade/vim-gitgutter'          " Git diff signs — loads eagerly so signs appear automatically.

  " --- Functionality (Lazy-Loaded for Speed) ---
  " These plugins will only be loaded when their command is first used.
  Plug 'tpope/vim-fugitive',   { 'on': ['G', 'Git'] }         " The best Git plugin for Vim.
  Plug 'preservim/nerdtree',    { 'on': 'NERDTreeToggle' }    " A file system explorer.
  Plug 'junegunn/fzf',         { 'do': { -> fzf#install() } } " Core fuzzy-finder program.
  Plug 'junegunn/fzf.vim',     { 'on': ['Files', 'Buffers', 'Rg'] } " Vim commands for FZF.

  call plug#end()
endif


" =============================================================================
" §2. Basic Setup & Appearance
" =============================================================================
" Let vim-sensible handle most defaults, we just add our preferences.
syntax on
filetype plugin indent on
set encoding=utf-8
" 24-bit "true colour" — REQUIRED for catppuccin to look right. Enable it ONLY
" when the terminal advertises it via $COLORTERM, so terminals that can't do it
" (notably macOS Terminal.app, which is 256-colour only) degrade gracefully
" instead of showing garbled RGB escapes (the teal-bg / wrong-cursorline / low-
" contrast mess). The t_8f/t_8b overrides declare the RGB sequences so it also
" works under tmux and TERM=xterm-256color. → For catppuccin, use a true-colour
" terminal like kitty; Terminal.app cannot display it correctly.
if has('termguicolors') && ($COLORTERM ==# 'truecolor' || $COLORTERM ==# '24bit')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

" Colorscheme: Catppuccin Mocha (with the matching airline statusline theme).
" `silent!` avoids an error on the very first launch — before vim-plug has
" installed the plugin — and the post-install re-source then applies it for real.
set background=dark
silent! colorscheme catppuccin_mocha
if !empty(globpath(&runtimepath, 'autoload/airline/themes/catppuccin_mocha.vim'))
  let g:airline_theme = 'catppuccin_mocha'
endif
set laststatus=2        " Always show the status line.
set showmatch           " Briefly jump to matching bracket.
set showcmd             " Show partial commands in the last line of the screen.
set mouse=a             " Enable mouse support in all modes.
set cursorline          " Highlight the current line.
set hidden              " Switch away from a modified buffer without saving first.
set scrolloff=8         " Keep 8 lines of context above/below the cursor.
set splitbelow          " Open horizontal splits below the current window,
set splitright          " and vertical splits to the right.
set updatetime=100      " Snappier CursorHold → responsive vim-gitgutter signs.
set signcolumn=yes      " Always show the sign column so signs don't shift text.

" Smart color column: on for code, off for prose.
set colorcolumn=80
augroup vimrc_colorcolumn
  autocmd!
  autocmd FileType markdown,text,gitcommit,help setlocal colorcolumn=0
augroup END


" =============================================================================
" §3. Line Numbers
" =============================================================================
" Use hybrid line numbers for easy navigation.
set number relativenumber


" =============================================================================
" §4. Tabs and Indentation
" =============================================================================
set expandtab           " Use spaces instead of tabs.
set tabstop=4           " Number of spaces a <Tab> in the file counts for.
set shiftwidth=4        " Number of spaces to use for auto-indent.
set autoindent          " Copy indent from current line (filetype indent handles the rest).


" =============================================================================
" §5. Searching
" =============================================================================
set hlsearch            " Highlight all search matches.
set incsearch           " Incrementally highlight search matches as you type.
set ignorecase          " Ignore case in searches...
set smartcase           " ...unless the search pattern contains uppercase letters.


" =============================================================================
" §6. File and Buffer Management
" =============================================================================
" Keep undo history persistent between sessions.
if !isdirectory($HOME . '/.vim/undo')
  call mkdir($HOME . '/.vim/undo', 'p')
endif
set undofile
set undodir=~/.vim/undo

" Disable swap files and backups for a cleaner experience.
set noswapfile
set nobackup
set nowritebackup

" Use the system clipboard for all yank/delete/paste operations.
" This checks for the 'unnamedplus' register (common on Linux) and falls back
" to 'unnamed' (correct for macOS and other systems) for portability.
if has('unnamedplus')
  set clipboard=unnamedplus
else
  set clipboard=unnamed
endif

" Hide build/vendor noise from file completion and :find.
set wildignore=*.o,*.obj,*.pyc,*.pyo,*.class,*.swp,*/.git/*,*/node_modules/*,*/__pycache__/*,*/.venv/*

" Reopen a file at the cursor position where you last left it (skip commit msgs).
augroup vimrc_last_position
  autocmd!
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") && &ft !~# 'commit' | execute "normal! g`\"" | endif
augroup END


" =============================================================================
" §7. Mappings (Custom Keyboard Shortcuts)
" =============================================================================
let mapleader = ","

" --- General Mappings ---
" Clear search highlight.
nnoremap <silent> <leader>c :nohlsearch<CR>
" Save and quit shortcuts.
nnoremap <silent> <leader>w :w<CR>
nnoremap <silent> <leader>q :q<CR>
nnoremap <silent> <leader>x :x<CR>
" Use Ctrl+S to save, a more universal shortcut.
noremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a

" --- Plugin Mappings ---
" Toggle NERDTree file explorer.
nnoremap <silent> <leader>n :NERDTreeToggle<CR>
" FZF fuzzy-finder mappings. NOTE: a comment must be on its OWN line here — a `"`
" after a :map is taken as part of the mapping, not a comment (:help map-comments).
" Find files in project:
nnoremap <silent> <leader>ff :Files<CR>
" Find open buffers:
nnoremap <silent> <leader>fb :Buffers<CR>
" Grep for text in project (ripgrep):
nnoremap <silent> <leader>fg :Rg<CR>