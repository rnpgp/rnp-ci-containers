FROM i386/debian:11

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=.UTF-8
ENV ARCH=ia32
ENV CPU=i386
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN apt-get update  &&                                                              \
    apt-get -y install git sudo wget bash software-properties-common pkg-config     \
           build-essential gettext libbz2-dev libssl-dev zlib1g-dev                 \
           python3 python3-venv autoconf automake libtool asciidoctor clang gpg

# Using system-shipped version of gpg (2.2.27)
# Otherwise
#   ARG GPG_VERSION=stable (for example, see _gpg_install in tools.sh)
#   apt-get install curl
#   /opt/tools/tools.sh build_and_install_gpg

# Using system-shipped version of automake (1.16.3)
#    /opt/tools/tools.sh build_and_install_automake

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python' && \
    /opt/tools/tools.sh install_cmake                   &&  \
    /opt/tools/tools.sh build_and_install_jsonc         &&  \
    /opt/tools/tools.sh build_and_install_botan
