FROM alpine:edge as build

ARG TOR_VERSION=0.3.4.8
ARG TOR_URL="https://dist.torproject.org/tor-${TOR_VERSION}.tar.gz"
ARG TOR_SIG_URL="https://dist.torproject.org/tor-${TOR_VERSION}.tar.gz.asc"
ARG TOR_KEY="0x6AFEE6D49E92B601"

ENV TOR_PREFIX /usr/local/tor
RUN mkdir -p "${TOR_PREFIX}"
WORKDIR ${TOR_PREFIX}

RUN apk --no-cache add \
        bash \
        build-base \
        ca-certificates \
        curl \
        gnupg \
        libevent-dev \
        libressl-dev \
        linux-headers \
        zlib-dev

RUN set -eux; \
    \
    curl -LO "${TOR_URL}"; \
    curl -LO "${TOR_SIG_URL}" ; \
    \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver pool.sks-keyservers.net --recv-keys "${TOR_KEY}"; \
    gpg --fingerprint "${TOR_KEY}"; \
    gpg --verify "tor-${TOR_VERSION}.tar.gz.asc"; \
    command -v gpgconf && gpgconf --kill all || :; \
    \
    mkdir -p src; \
    tar xzf tor-${TOR_VERSION}.tar.gz -C src --strip-components=1; \
    rm tor-${TOR_VERSION}.tar.gz tor-${TOR_VERSION}.tar.gz.asc

RUN set -eux; \
    \
    cd ${TOR_PREFIX}/src; \
    ./configure \
        --prefix=${TOR_PREFIX} \
        --sysconfdir=/etc \
        --disable-asciidoc \
        --mandir=${TOR_PREFIX}/man \
        --infodir=${TOR_PREFIX}/info \
        --localstatedir=/var \
        --enable-static-tor \
        --with-libevent-dir=/usr/lib \
        --with-openssl-dir=/usr/lib \
        --with-zlib-dir=/lib; \
    make && make install; \
    \
    scanelf -R --nobanner -F '%F' ${TOR_PREFIX}/bin/ | xargs strip

FROM scratch

LABEL maintainer="Alex Druzenko <alex@druzenko.com>" \
    org.label-schema.vcs-url="https://github.com/torosio/docker-tor.git"

COPY --from=build /usr/local/tor/bin/tor /usr/bin/tor

CMD ["tor"]