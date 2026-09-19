" Minimalistic Vimrc without any plugins.
" Plain vanilla Vim, but with a more useful default configuration.

" Enable syntax highlighting
syntax on

" Enable line numbers
set number

" Set indentation options
set expandtab       " Use spaces instead of tabs
set shiftwidth=2    " Indent by 2 spaces
set tabstop=2       " A tab is 2 spaces
set softtabstop=2   " Backspace over spaces as if they were tabs
set autoindent      " Copy indentation from the previous line
set smartindent     " Automatically indent new lines

" Enable search enhancements
set incsearch       " Incremental search
set hlsearch        " Highlight search results
set ignorecase      " Case-insensitive search
set smartcase       " Case-sensitive if search includes uppercase

" Improve command-line completion
set wildmode=longest:full
set wildmenu        " Enhanced tab completion in command mode

" Enable hidden buffers (for switching files)
set hidden

" Enable mouse support
set mouse=a

" Set a better backspace behavior
set backspace=indent,eol,start

" Display matching parentheses and brackets
set showmatch

" Reduce delay when escaping insert mode
set timeoutlen=500 ttimeoutlen=10

" Enable clipboard support
set clipboard=unnamedplus " Use system clipboard

" Set color scheme (optional)
colorscheme evening
set background=dark

" Prevent annoying sound alerts
set noerrorbells
set visualbell

" Faster updates for better performance
set updatetime=300

"====[ make edit vim config easy ]======================================
nnoremap <leader>ev :edit $MYVIMRC<cr>
" auto reload when config has changed
augroup VimReload
    autocmd!
    autocmd BufWritePost $MYVIMRC source $MYVIMRC
augroup END



"====[ plugins ]========================================================

call plug#begin('~/.vim/plugged')

Plug 'junegunn/vim-plug'
Plug 'wellle/visual-split.vim'
Plug 'skywind3000/vim-quickui'

" Python plugins
Plug 'vim-scripts/indentpython.vim'
Plug 'hdima/python-syntax'
Plug '0x07CB/vim-hf-stt'

call plug#end()


"====[ dracula theme ]========================================
" syntax enable
" colorscheme darcula

