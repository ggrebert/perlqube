FROM gcr.io/distroless/base

COPY perlqube /usr/local/bin/perlqube

ENTRYPOINT [ "perlqube" ]

CMD [ "--help" ]
