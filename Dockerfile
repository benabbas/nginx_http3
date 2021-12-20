FROM nginx:1.21.1 AS build

WORKDIR .
RUN apt-get update && \
    apt-get install -y git gcc make g++ cmake perl libunwind-dev golang && \
    git clone https://boringssl.googlesource.com/boringssl && \
    mkdir boringssl/build && \
    cd boringssl/build && \
    cmake .. && \
    make

RUN apt-get install -y mercurial libperl-dev libpcre3-dev zlib1g-dev libxslt1-dev libgd-ocaml-dev libgeoip-dev && \
    hg clone https://hg.nginx.org/nginx-quic   && \
    hg clone http://hg.nginx.org/njs -r "0.6.2" && \
    cd nginx-quic && \
    hg update quic && \
    auto/configure `nginx -V 2>&1 | sed "s/ \-\-/ \\\ \n\t--/g" | grep "\-\-" | grep -ve opt= -e param= -e build=` \
                   --build=nginx-quic --with-debug  \
                   --with-http_v3_module --with-http_quic_module --with-stream_quic_module \
                   --with-cc-opt="-I/src/boringssl/include" --with-ld-opt="-L/src/boringssl/build/ssl -L/src/boringssl/build/crypto" && \
    make

FROM nginx:1.21.1
COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /etc/nginx/conf.d
RUN mkdir -p /etc/ssl/
RUN mkdir -p /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf
COPY test.bentech.site.cert /etc/ssl/test.bentech.site.crt
COPY test.bentech.site.key /etc/ssl/test.bentech.site.key
COPY index.html /usr/share/nginx/html/index.html
COPY --from=build /src/nginx-quic/objs/nginx /usr/sbin
RUN /usr/sbin/nginx -V > /dev/stderr
EXPOSE 8443
