FROM fedora:35

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=C.UTF-8
ENV ARCH=x64
ENV CPU=x86_64
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN dnf -y update                                                                                 && \
    dnf -y install sudo wget git openssl-devel bison byacc cmake python                              \
                   json-c-devel clang gcc gcc-c++ make autoconf libtool gzip bzip2 bzip2-devel       \
                   gettext-devel ncurses-devel zlib-devel asciidoctor botan2 botan2-devel

RUN  /opt/tools/tools.sh build_and_install_automake
