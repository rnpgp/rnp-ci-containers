FROM --platform=linux/386 debian:11

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=.UTF-8
ENV ARCH=ia32
ENV CPU=i386
ENV OS=linux
# System botan 2.17.3
ENV LD_LIBRARY_PATH=/usr/local/lib

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN apt-get update  &&                                                              \
    apt-get -y --no-install-recommends install git sudo wget bash software-properties-common pkg-config     \
           build-essential gettext libbz2-dev libssl-dev zlib1g-dev                 \
           python3 python3-venv autoconf automake libtool asciidoctor clang gpg gpg-agent libbotan-2-dev ccache &&  \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python' && \
    /opt/tools/tools.sh install_cmake                   &&  \
    /opt/tools/tools.sh build_and_install_jsonc
