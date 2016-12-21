call pathogen#infect()

set tabstop=4
set shiftwidth=4
set softtabstop=4
set shiftround
set expandtab
set ruler
set visualbell

set listchars=eol:␤,tab:␉␣,trail:␢,extends:»,precedes:«,space:␣

set path=.,/usr/include,,src/main/scala,src/main/java,src/main

set cmdheight=2

set encoding=utf8

let g:Perl_AuthorName = 'Sterling Hanenkamp'
let g:Perl_AuthorRef  = 'ASH'
let g:Perl_Email      = 'hanenkamp@cpan.org'

"map q :e #
nmap ,b :buffers<CR>

nmap ,m :0read !new-module -mp5.10 %<CR>
nmap ,r :.w !bash<CR>
nmap ,p :.w !present<CR>

"set autoindent
"set smartindent

set nocompatible
set backspace=indent,eol,start

set nowrap

nnoremap j gj
nnoremap k gk
vnoremap j gj
vnoremap k gk
nnoremap <Down> gj
nnoremap <Up> gk
vnoremap <Down> gj
vnoremap <Up> gk
inoremap <Down> <C-o>gj
inoremap <Up> <C-o>gk
inoremap = =

set pastetoggle=<F2>

vmap # :<BS><BS><BS><BS><BS>set paste<CR>gvI# <Esc>:set nopaste<CR>

" noremap <C-v> :set paste<CR><C-v>
" inoremap <Esc> <Esc>:set nopaste<CR>
" cnoremap <Esc> <Esc>:set nopaste<CR>

set hlsearch

set showmatch
set matchtime=2

set tw=80
set formatoptions=crqn

filetype indent on

" GUI Options
"set guifontset=-*-*-medium-r-normal--17-*-*-*-m-*-*-*
"set guioptions=aci

"set guifont=LucidaTypewriter\ 12
set guifont=Monaco:h10

syntax enable
highlight Normal guibg=black guifg=white
set bg=dark

if !exists("*Eatchar")
   func Eatchar(pat)
      let c = nr2char(getchar(0))
      return (c =~ a:pat) ? '' : c
   endfunc
endif

autocmd FileType perl,perl6,json autocmd BufWritePre <buffer> :%s/\s\+$//e

" Git
autocmd BufNewFile,BufRead *.git/COMMIT_EDITMSG setf gitcommit
autocmd BufNewFile,BufRead *.git/config,.gitconfig,.gitmodules setf gitconfig
autocmd BufNewFile,BufRead git-rebase-todo      setf gitrebase
autocmd BufNewFile,BufRead .msg.[0-9]*
      \ if getline(1) =~ '^From.*# This line is ignored.$' |
      \   setf gitsendemail |
      \ endif
autocmd BufNewFile,BufRead *.git/**
      \ if getline(1) =~ '^\x\{40\}\>\|^ref: ' |
      \   setf git |
      \ endif

autocmd BufNewFile,BufRead conf/*.conf
    \ setf yaml

autocmd BufNewFile,BufRead *.tt2
  \ setf tt2html |

autocmd BufNewFile,BufRead *.tt
  \ setf tt2html |

autocmd BufEnter */template/*
    \ setf tt2html

autocmd BufEnter */schema/changes/*
    \ setf sql

autocmd BufReadPost *
  \ if line("'\"") > 0 && line("'\"") <= line("$") |
  \   exe "normal g`\"" |
  \ endif

autocmd BufEnter *.p6w
    \ set ft=perl6

autocmd BufEnter *.mustache
    \ set ft=html

autocmd BufEnter *.module
    \ set ft=php

autocmd BufEnter *.install
    \ set ft=php

autocmd BufEnter *.notes
	\ set formatoptions=tcrqn |
	\ set ft=notes

autocmd FileType yaml
    \ setlocal si |
	\ setlocal tw=0 |
    \ setlocal tabstop=2 |
    \ setlocal shiftwidth=2 |
    \ setlocal softtabstop=2

autocmd BufEnter *.psgi
    \ set ft=perl

autocmd BufEnter *.pm6
    \ set ft=perl6

autocmd FileType tex,notes
	\ set formatoptions=tcrqn |
	\ setlocal tw=80 |
	\ setlocal wrap |
	\ setlocal lbr |
	\ setlocal noai |
	\ setlocal nosi

autocmd FileType markdown
    \ setlocal spell |
    \ setlocal spelllang=en_us

autocmd FileType mail
	\ set formatoptions=tcrqn |
	\ setlocal tw=78

autocmd FileType xml,xsl
	\ setlocal tw=0 |
	\ setlocal ts=2 |
	\ setlocal sw=2 |
    \ setlocal sts=2

autocmd FileType perl,pod
    \ setlocal wrap |
    \ setlocal lbr

autocmd FileType perl6
    \ setlocal wrap |
    \ setlocal lbr |
    \ setlocal nospell |
    \ iabbrev <silent> <buffer>  (>+)         ≽<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (<+)         ≼<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  !(>)         ⊅<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (>)          ⊃<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  !(>=)        ⊉<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (>=)         ⊇<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  !(<)         ⊄<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (<)          ⊂<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  !(<=)        ⊈<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (<=)         ⊆<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  !(cont)      ∌<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (cont)       ∋<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  !(elem)      ∉<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (elem)       ∈<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (union)      ∪<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (intersect)  ∩<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (diff)       ∖<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (symdiff)    ⊖<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (.)          ⊍<C-R>=Eatchar('\s')<CR> |
    \ iabbrev <silent> <buffer>  (+)          ⊎<C-R>=Eatchar('\s')<CR>

autocmd FileType php
    \ setlocal expandtab |
    \ setlocal tabstop=2 |
    \ setlocal shiftwidth=2 |
    \ setlocal autoindent |
    \ setlocal smartindent |
    \ setlocal softtabstop=2

autocmd FileType javascript
    \ setlocal autoindent |
    \ setlocal smartindent

autocmd FileType scala
    \ setlocal suffixesadd=.scala,.java |
    \ setlocal includeexpr=substitute(v:fname,'\\.','/','g')

autocmd FileType html,tt2html
    \ setlocal spell spelllang=en_us |
    \ setlocal wrap |
    \ setlocal lbr |
    \ setlocal si

autocmd FileType lua
    \ setlocal ts=2 |
    \ setlocal sw=2 |
    \ setlocal sts=2

autocmd FileType java
    \ setlocal suffixesadd=.scala,.java

set modeline
set modelines=10

filetype plugin on

let Tlist_Ctags_Cmd = '/usr/bin/exuberant-ctags'

let g:perldoc_program = '/usr/bin/perldoc'
au BufNewFile,BufRead *.pmc set ft=pmc
au BufNewFile,BufRead *.pasm set ft=pasm
au BufNewFile,BufRead *.imc,*.imcc set ft=imc

" Special stuff for Mac
map <S-Insert> <MiddleMouse>
map! <S-Insert> <MiddleMouse>

iab pmod  :r ~/projects/code-templates/perl/module.pmkdd
iab ptest :set ft=perl:r ~/projects/code-templates/perl/test.tkdd

" winsize 80 24
set guioptions+=c
set guioptions-=l
set guioptions-=L
set guioptions-=r
set guioptions-=R

set printoptions=left:0.5in,right:0.5in,top:0.5in,bottom:0.5in,syntax:y,number:y,paper:letter

set t_Co=256
colorscheme desert256

set statusline=\ #%n\ %<%f\ %h%w%m%r%{fugitive#statusline()}\%=%-8(%l,%c%V%)%p%%\
set laststatus=2

hi StatusLine ctermfg=57
hi StatusLineNC ctermfg=141
hi VertSplit ctermfg=141

if !exists("*GetCurrentYAMLPath")
    function GetCurrentYAMLPath()
        let filename = expand('%:t') " last path component
        let pos = getpos('.')

        let section = '^\s*\(\w\+\)\s*:.*'
        let lead_ws = '\(^\s*\).*'

        " look backwards for a line that looks like a yaml section header
        " count the spaces in front of it, and grab the section name
        call search(section, 'cWbs')
        let indent = len( substitute( getline('.'), lead_ws, '\1', 'g' ) )
        let curr_loc = substitute( getline('.'), section, '\1', 'g' )
        let last_indent = indent

        " work backwards, repeating the same steps for shorter and shorter indents
        while (indent > 0)
            call search(section, 'Wbs')
            let indent = len( substitute( getline('.'), lead_ws, '\1', 'g' ) )

            if (indent < last_indent)
                let curr_loc = substitute(getline('.'), section, '\1', 'g' ) . ' > ' . curr_loc
                let last_indent = indent
            endif
        endwhile

        " back from whence we came
        call setpos('.', pos )

        return curr_loc
    endfunction
endif

nmap ,y :echo GetCurrentYAMLPath()<CR>

let perl_include_pod = 1

nmap ,d :!mkdir -p %:p:h<CR>

highlight ColorColumn ctermbg=54
call matchadd('ColorColumn', '\%81v', 100)

finish
