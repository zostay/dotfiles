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

ENV HOME=/home/sterling
ENV UID=1000

RUN mkdir -p /home/sterling

VOLUME /home/sterling

WORKDIR /home/sterling

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
