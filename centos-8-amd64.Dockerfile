FROM tgagor/centos:stream8

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=C.UTF-8
ENV ARCH=x64
ENV CPU=x86_64
ENV OS=linux
# CXXFLAGS environment setting resolves dual ABI issues caused by BOTAN libraries with the version of GCC installed at 'tgagor/centos:stream8'
# https://gcc.gnu.org/onlinedocs/gcc-5.2.0/libstdc++/manual/manual/using_dual_abi.html
ENV CXXFLAGS=-D_GLIBCXX_USE_CXX11_ABI=0
# For libiconv
ENV LD_LIBRARY_PATH=/usr/local/lib

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN dnf -y update && dnf -y install sudo wget git epel-release 'dnf-command(config-manager)'         && \
    dnf config-manager --set-enabled powertools                                                      && \
    rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages.pub                     && \
    rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages-next.pub                && \
    wget https://github.com/riboseinc/yum/raw/master/ribose.repo -O /etc/yum.repos.d/ribose.repo     && \
    dnf -y install json-c-devel clang gcc gcc-c++ make autoconf libtool gzip bzip2 bzip2-devel          \
                   gettext-devel ncurses-devel zlib-devel python3 asciidoctor                           \
                   openssl-devel bison byacc cmake gpg botan2 botan2-devel perl-Digest-SHA

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python' && \
    /opt/tools/tools.sh build_and_install_automake                                    && \
    /opt/tools/tools.sh build_and_install_libiconv                                    && \
    /opt/tools/tools.sh build_and_install_gpg lts                                     && \
    /opt/tools/tools.sh build_and_install_gpg stable                                  && \
    /opt/tools/tools.sh build_and_install_botan 2.18.2
