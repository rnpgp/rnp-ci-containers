FROM debian:sid

ARG TARGETARCH=amd64

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=.UTF-8
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN apt-get update  &&                                                      \
    apt-get -y install git sudo wget bash pkg-config cmake                  \
           build-essential gettext libbz2-dev libssl-dev zlib1g-dev         \
           python3 python3-venv autoconf automake libtool asciidoctor clang \
           libjson-c-dev libbotan-3-dev gpg ccache

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python'
