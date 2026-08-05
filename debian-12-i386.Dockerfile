FROM --platform=linux/386 debian:12

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LC_LANG=.UTF-8
ENV ARCH=ia32
ENV CPU=i386
ENV OS=linux
# For default botan version (2.18.3)
ENV LD_LIBRARY_PATH=/usr/local/lib

ARG CC=gcc
ARG CXX=g++

COPY tools /opt/tools

# Enable amd64 multiarch so GHA's amd64 node24 binary (mounted at /__e) can exec.
# Without this, the i386 container has no 64-bit loader and node24 fails with
# "no such file or directory" (ELF interpreter missing).
RUN dpkg --add-architecture amd64 && \
    apt-get update && \
    apt-get -y --no-install-recommends install libc6:amd64 libstdc++6:amd64 && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update  &&                                                              \
    apt-get -y --no-install-recommends install git sudo wget bash software-properties-common pkg-config     \
           build-essential gettext libbz2-dev libssl-dev zlib1g-dev                 \
           python3 python3-venv autoconf automake libtool asciidoctor clang libbotan-2-dev gpg gpg-agent ccache &&  \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN /opt/tools/tools.sh ensure_symlink_to_target '/usr/bin/python3' '/usr/bin/python' && \
    /opt/tools/tools.sh install_cmake                   &&  \
    /opt/tools/tools.sh build_and_install_jsonc
