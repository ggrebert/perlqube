FROM debian

COPY perlqube /usr/local/bin/perlqube

RUN apt-get update -qq \
    && apt-get install -qqy git
