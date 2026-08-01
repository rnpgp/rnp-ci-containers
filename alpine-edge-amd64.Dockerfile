FROM alpine:edge

ARG TARGETARCH=amd64

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=C.UTF-8
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN apk add --no-cache \
        sudo wget git bash pkgconf cmake \
        build-base gettext-dev bzip2-dev openssl-dev zlib-dev \
        python3 autoconf automake libtool asciidoctor clang \
        json-c-dev botan3-dev gnupg bison ncurses-dev \
        linux-headers samurai coreutils shadow ccache

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python'
