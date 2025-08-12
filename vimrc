" =============================================================================
" §1. Plugin Manager: vim-plug
" =============================================================================
" Auto-install vim-plug if it's not present.
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

" --- Core & Appearance (Load on Startup) ---
Plug 'tpope/vim-sensible'              " A collection of sensible default settings.
Plug 'sheerun/vim-polyglot'             " A huge collection of language syntax packs.
Plug 'vim-airline/vim-airline'          " Advanced status line.
Plug 'vim-airline/vim-airline-themes'   " Themes for the status line.
Plug 'jiangmiao/auto-pairs'            " Auto-close brackets and quotes.

" --- Functionality (Lazy-Loaded for Speed) ---
" These plugins will only be loaded when their command is first used.
Plug 'tpope/vim-fugitive',   { 'on': ['G', 'Git'] }         " The best Git plugin for Vim.
Plug 'preservim/nerdtree',    { 'on': 'NERDTreeToggle' }    " A file system explorer.
Plug 'junegunn/fzf',         { 'do': { -> fzf#install() } } " Core fuzzy-finder program.
Plug 'junegunn/fzf.vim',     { 'on': ['Files', 'Buffers', 'Ag'] } " Vim commands for FZF.
Plug 'airblade/vim-gitgutter', { 'on': ['GitGutterEnable', 'GitGutterToggle'] } " Git diff signs in the gutter.

call plug#end()


" =============================================================================
" §2. Basic Setup & Appearance
" =============================================================================
" Let vim-sensible handle most defaults, we just add our preferences.
syntax on
filetype plugin indent on
set encoding=utf-8
set termguicolors       " Enable 24-bit RGB color in the terminal.
set laststatus=2        " Always show the status line.
set showmatch           " Briefly jump to matching bracket.
set showcmd             " Show partial commands in the last line of the screen.
set mouse=a             " Enable mouse support in all modes.
set cursorline          " Highlight the current line.

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
set smartindent         " Smart auto-indent on new lines.
set autoindent          " Copy indent from current line when starting a new line.


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
" FZF fuzzy-finder mappings.
nnoremap <silent> <leader>ff :Files<CR>    " Find files in project.
nnoremap <silent> <leader>fb :Buffers<CR>  " Find open buffers.
nnoremap <silent> <leader>fg :Ag<CR>       " Grep for text in project.