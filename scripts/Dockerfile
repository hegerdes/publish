FROM debian:bullseye

# Install dev deps
RUN apt-get update
RUN apt-get install -y \
    make curl git gcc build-essential pkgconf libtool libsystemd-dev \
    libprotobuf-c-dev libcap-dev libseccomp-dev libyajl-dev \
    go-md2man libtool autoconf python3 automake

# Install wasmedge
RUN curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash

WORKDIR /builder
SHELL ["/bin/bash", "-c"]

RUN git clone https://github.com/containers/crun.git
RUN source $HOME/.wasmedge/env \
    && cd crun \
    && ./autogen.sh \
    && ./configure --with-wasmedge \
    && make -j $(nproc) \
    && mkdir -p wasmlibs \
    && cp $HOME/.wasmedge/lib/libwasmedge.so.0.0.1 wasmlibs/libwasmedge.so.0.0.1 \
    && ln -s wasmlibs/libwasmedge.so.0.0.1 wasmlibs/libwasmedge.so.0 \
    && ln -s wasmlibs/libwasmedge.so.0 wasmlibs/libwasmedge.so \
    && tar czvf "crun-$(git rev-parse --short HEAD).tar.gz" crun COPYING NEWS README.md wasmlibs/*

RUN cp crun/crun*.tar.gz .
