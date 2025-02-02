FROM ubuntu:18.04 AS builder

LABEL maintainer="Robin Marx <rmarx@akamai.com>"
# inspired by https://github.com/yurymuski/curl-http3

WORKDIR /opt

RUN apt-get update && \
    apt-get install -y build-essential git autoconf libtool cmake golang-go curl;

# https://github.com/curl/curl/blob/master/docs/HTTP3.md#quiche-version

# install rust & cargo
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y -q;

RUN git clone --recursive https://github.com/cloudflare/quiche

# build quiche
RUN export PATH="$HOME/.cargo/bin:$PATH" && \
    cd quiche && \
    cargo build --package quiche --release --features ffi,pkg-config-meta,qlog && \
    mkdir quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target/release -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib/

# add curl
RUN git clone https://github.com/curl/curl
RUN cd curl && \
    autoreconf -fi && \
    ./configure LDFLAGS="-Wl,-rpath,/opt/quiche/target/release" --with-openssl=/opt/quiche/quiche/deps/boringssl/src --with-quiche=/opt/quiche/target/release && \
    make && \
    make DESTDIR="/ubuntu/" install

FROM ubuntu:bionic
RUN apt-get update && apt-get install -y curl tcpdump

COPY --from=builder /ubuntu/usr/local/ /usr/local/
COPY --from=builder /opt/quiche/target/release /opt/quiche/target/release

# Resolve any issues of C-level lib
# location caches ("shared library cache")
RUN ldconfig /usr/local/lib

WORKDIR /opt
CMD ["curl"]