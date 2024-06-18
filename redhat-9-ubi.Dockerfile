FROM redhat/ubi9:9.4

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=C.UTF-8
ENV ARCH=x64
ENV CPU=x86_64
ENV OS=linux

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

RUN dnf -y update
RUN dnf -y install sudo wget git
RUN dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
RUN rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages.pub
RUN rpm --import https://github.com/riboseinc/yum/raw/master/ribose-packages-next.pub
RUN wget https://github.com/riboseinc/yum/raw/master/ribose.repo -O /etc/yum.repos.d/ribose.repo

RUN dnf -y install clang gcc gcc-c++ make autoconf libtool gzip bzip2 bzip2-devel      \
                   json-c13-devel gettext ncurses-devel zlib-devel python3 asciidoctor \
                   openssl openssl-devel cmake gpg perl-Digest-SHA

# Fix json-c13.pc, see the issue https://github.com/riboseinc/yum/issues/10
RUN sed -i 's|-I${includedir}/json-c$|-I${includedir}/json-c13|' /usr/lib64/pkgconfig/json-c13.pc

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python'
