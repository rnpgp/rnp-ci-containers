FROM fedora:rawhide

ARG TARGETARCH=amd64

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=C.UTF-8
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN dnf -y --setopt=tsflags=nodocs install sudo wget git openssl-devel bison byacc cmake python     \
                   perl-Digest-SHA json-c-devel clang gcc gcc-c++ make autoconf libtool gzip bzip2   \
                   bzip2-devel gettext-devel ncurses-devel zlib-devel asciidoctor llvm gpg           \
                   pkgconf-pkg-config shadow-utils botan3 botan3-devel ccache                               && \
    dnf -y install /usr/bin/su                                                                     && \
    dnf clean all

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python'
