FROM opensuse/tumbleweed:latest

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=C.UTF-8
ENV ARCH=x64
ENV CPU=x86_64
ENV OS=linux
# For libiconv
ENV LD_LIBRARY_PATH=/usr/local/lib

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN zypper refresh
RUN zypper -n install sudo wget git libopenssl-devel bison byacc automake cmake python3 \
              libjson-c-devel clang gcc gcc-c++ make autoconf libtool gzip bzip2 libbz2-devel \
              gettext-tools ncurses-devel zlib-devel asciidoc libbotan-devel llvm gtest
