FROM centos:7
LABEL org.opencontainers.image.source = "https://github.com/maxirmx/rnp-ci-containers"

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LC_LANG=en_US.UTF-8
ENV ARCH=x64
ENV CPU=x86_64
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN yum -y update                                                                                    && \
    yum -y install sudo wget git                                                                     && \
    rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages.pub                     && \
    rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages-next.pub                && \
    wget https://github.com/riboseinc/yum/raw/master/ribose.repo -O /etc/yum.repos.d/ribose.repo     && \
    yum -y install epel-release centos-release-scl centos-sclo-rh                                    && \
    yum -y update                                                                                    && \
    yum -y install llvm-toolset-7.0 json-c12-devel clang gcc gcc-c++ make autoconf libtool gzip         \
                   bzip2 bzip2-devel gettext-devel ncurses-devel zlib-devel python3 asciidoctor         \
                   botan2 botan2-devel openssl-devel bison byacc

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python'               && \
    /opt/tools/tools.sh install_cmake                                                               && \
    /opt/tools/tools.sh build_and_install_automake                                                  && \
    /opt/tools/tools.sh build_and_install_gpg stable
