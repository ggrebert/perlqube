FROM debian:stable-slim

COPY perlqube /usr/local/bin/perlqube

RUN apt-get update -qq \
    && apt-get install -qqy git \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/*

CMD [ "perlqube", "--help" ]
