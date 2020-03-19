# I borrowed the basis for this from Tony O's rakudo-nightly and then
# embellished it to serve my own needs. Thanks, Tony.

FROM ubuntu

ARG RAKU_VERSION=2020.02.1

WORKDIR /usr/local/src

RUN apt-get update
RUN apt-get install -y curl gnupg2 git build-essential zsh libssl-dev

RUN git clone \
    --single-branch --branch $RAKU_VERSION \
    https://github.com/rakudo/rakudo.git \
    /usr/local/src/rakudo

RUN cd /usr/local/src/rakudo \
    && perl Configure.pl --gen-moar --gen-nqp --backends=moar --prefix=/usr/local \
    && make \
    && make install

RUN git clone \
    --single-branch \
    https://github.com/ugexe/zef.git \
    /usr/local/src/zef

RUN ln -s "$(cd /usr/local/src/zef; raku -I. bin/zef install . | egrep -A 1 'script .*? installed to:' | tail -n 1)/zef" /usr/local/bin/zef

RUN zef install --/force-test \
    Base64 \
    HTTP::Request::FormData \
    HTTP::UserAgent \
    JSON::Fast \
    META6

ENV HOME=/home/user

RUN mkdir -p /home/user

VOLUME /home/user
WORKDIR /home/user

CMD ["raku"]
