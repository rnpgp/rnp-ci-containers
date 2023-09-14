FROM i386/debian:10

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

RUN apt-get update  &&                                                \
    apt-get -y install git sudo wget bash software-properties-common  \
           build-essential gettext libbz2-dev libssl-dev  pkg-config  \
           zlib1g-dev autoconf automake libtool asciidoctor clang gpg

# Using system-shipped version of gpg (2.1.2)
# Otherwise
#   apt-get install curl
#   /opt/tools/tools.sh build_and_install_gpg <version>
#   selected version will be installed to /opt/gpg/<version>
#
#   for example, /opt/tools/tools.sh build_and_install_gpg stable
#   installs to /opt/gpg/stable
#

RUN /opt/tools/tools.sh install_cmake                   &&  \
    /opt/tools/tools.sh build_and_install_automake      &&  \
    /opt/tools/tools.sh build_and_install_python        &&  \
    /opt/tools/tools.sh build_and_install_jsonc         &&  \
    /opt/tools/tools.sh build_and_install_botan
