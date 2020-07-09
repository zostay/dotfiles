if did_filetype()
    finish
endif

if getline(1) =~# '#!.*\<raku'
    set ft=raku
endif
