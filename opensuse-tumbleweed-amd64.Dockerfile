FROM opensuse/tumbleweed:latest

ARG TARGETARCH=amd64

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=C.UTF-8
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN zypper refresh
RUN zypper -n install sudo wget git libopenssl-devel bison byacc automake cmake python3 \
              libjson-c-devel clang gcc gcc-c++ make autoconf libtool gzip bzip2 libbz2-devel \
              gettext-tools ncurses-devel zlib-devel asciidoc libbotan-devel llvm gtest ccache \
              pkg-config gpg2 && \
    zypper clean -a

RUN /opt/tools/tools.sh ensure_symlink_to_target /usr/bin/python3 /usr/bin/python
