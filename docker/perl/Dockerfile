FROM perl

RUN cpanm \
        List::Util \
        Getopt::Long \
        Data::Printer \
        DateTime \
        File::Find::Rule \
        YAML::Tiny \
        File::Path \
        FindBin \
        Date::Parse \
        Email::Address \
        Email::MIME \
        Email::Sender \
        Try::Tiny

RUN apt-get update --yes
RUN apt-get install zsh --yes

ENV HOME=/home/user

RUN mkdir -p /home/user

VOLUME /home/user

WORKDIR /home/user
