FROM fedora:36

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

RUN dnf -y update                                                                                 && \
    dnf -y install sudo wget git openssl-devel bison byacc cmake python perl-Digest-SHA              \
                   json-c-devel clang gcc gcc-c++ make autoconf libtool gzip bzip2 bzip2-devel       \
                   gettext-devel ncurses-devel zlib-devel asciidoctor botan2 botan2-devel

RUN /opt/tools/tools.sh build_and_install_libiconv                                                  && \
    /opt/tools/tools.sh build_and_install_gpg lts                                                   && \
    /opt/tools/tools.sh build_and_install_gpg stable                                                && \
    /opt/tools/tools.sh build_and_install_botan 3.1.1
