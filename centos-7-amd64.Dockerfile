FROM centos:7

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LC_LANG=en_US.UTF-8
ENV ARCH=x64
ENV CPU=x86_64
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN yum -y install http://opensource.wandisco.com/centos/7/git/x86_64/wandisco-git-release-7-2.noarch.rpm   && \
    yum -y update                                                                                           && \
    yum -y install sudo wget git                                                                            && \
    rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages.pub                            && \
    rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages-next.pub                       && \
    wget https://github.com/riboseinc/yum/raw/master/ribose.repo -O /etc/yum.repos.d/ribose.repo            && \
    yum -y install epel-release centos-release-scl centos-sclo-rh                                           && \
    yum -y install llvm-toolset-7.0 json-c12-devel make autoconf libtool gzip  gcc gcc-c++                     \
                   bzip2 bzip2-devel gettext-devel ncurses-devel zlib-devel python3 asciidoctor                \
                   openssl-devel bison byacc gpg botan2 botan2-devel perl-Digest-SHA

# /opt/rh/llvm-toolset-7.0/enable
ENV PATH=/opt/rh/llvm-toolset-7.0/root/usr/bin:/opt/rh/llvm-toolset-7.0/root/usr/sbin${PATH:+:${PATH}}
ENV LD_LIBRARY_PATH=/opt/rh/llvm-toolset-7.0/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
ENV PKG_CONFIG_PATH=/opt/rh/llvm-toolset-7.0/root/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python'               && \
    /opt/tools/tools.sh install_cmake                                                               && \
    /opt/tools/tools.sh build_and_install_automake                                                  && \
    /opt/tools/tools.sh build_and_install_gpg lts                                                   && \
    /opt/tools/tools.sh build_and_install_gpg stable
