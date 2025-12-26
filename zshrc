for RC in $HOME/.zsh/rc/*(n); do
    source $RC
done

PATH="/Users/sterling/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/Users/sterling/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/Users/sterling/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/Users/sterling/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/Users/sterling/perl5"; export PERL_MM_OPT;
