FROM tgagor/centos:stream8

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=C.UTF-8
ENV ARCH=x64
ENV CPU=x86_64
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN dnf -y install sudo wget git epel-release                                                        && \
    dnf -y -q install 'dnf-command(config-manager)'                                                  && \
    dnf config-manager --set-enabled powertools                                                      && \
    dnf -y update                                                                                    && \
    rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages.pub                     && \
    rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages-next.pub                && \
    wget https://github.com/riboseinc/yum/raw/master/ribose.repo -O /etc/yum.repos.d/ribose.repo     && \
    dnf -y install json-c-devel clang gcc gcc-c++ make autoconf libtool gzip bzip2 bzip2-devel          \
                   gettext-devel ncurses-devel zlib-devel python3 asciidoctor botan2 botan2-devel       \
                   openssl-devel bison byacc


RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python' && \
    /opt/tools/tools.sh install_cmake                                                 && \
    /opt/tools/tools.sh build_and_install_automake                                    && \
    /opt/tools/tools.sh build_and_install_libiconv

RUN /opt/tools/tools.sh build_and_install_gpg stable && \
    /opt/tools/tools.sh build_and_install_gpg lts    && \
    /opt/tools/tools.sh build_and_install_gpg 2.3.1
