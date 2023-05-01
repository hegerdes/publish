FROM debian:bullseye

# Install dev deps
RUN apt-get update && apt-get install -y \
    make curl git gcc build-essential pkgconf libtool libsystemd-dev \
    libprotobuf-c-dev libcap-dev libseccomp-dev libyajl-dev libyajl2 \
    libprotobuf-c-dev protobuf-c-compiler protobuf-compiler \
    python3-protobuf go-md2man libtool autoconf python3 automake \
    golang-github-checkpoint-restore-go-criu-dev

# Build Args
ARG WasmEdgeApiVersion=2
ARG CrunVersion=main

# Install wasmedge
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# See https://wasmedge.org/book/en/quick_start/install.html
RUN curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- -e all
# RUN curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- -e all -v 0.11.2

WORKDIR /builder
RUN git clone --branch ${CrunVersion} https://github.com/containers/crun.git
RUN source $HOME/.wasmedge/env \
    && cd crun \
    && ./autogen.sh \
    && ./configure --with-wasmedge \
    && make -j $(nproc) \
    && mkdir -p wasmlibs \
    && cp $HOME/.wasmedge/lib/libwasmedge.so.0.0.${WasmEdgeApiVersion} wasmlibs/libwasmedge.so.0.0.${WasmEdgeApiVersion} \
    && ln -s wasmlibs/libwasmedge.so.0.0.1 wasmlibs/libwasmedge.so.0 \
    && ln -s wasmlibs/libwasmedge.so.0 wasmlibs/libwasmedge.so \
    && tar czvf "crun-$(git rev-parse --short HEAD)_$(uname -m).tar.gz" crun COPYING NEWS README.md wasmlibs/* \
    && if [ "$(uname -m)" = "x86_64" ]; then ./crun --version; fi

RUN cp crun/crun*.tar.gz .
