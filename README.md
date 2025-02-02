# curl-http3
[![](https://img.shields.io/docker/pulls/rmarx/curl-http3?style=flat-square)](https://hub.docker.com/r/rmarx/curl-http3)

Docker image of `curl` compiled with  `BoringSSL` and `quiche` for **HTTP3 support**.

Inspired by [yurymuski/curl-http3](https://github.com/yurymuski/curl-http3), mainly updates to latest curl and quiche versions to add support for the `h3` alpn. Removes httpstat support. 

Original documentation at [curl + http3 manual](https://github.com/curl/curl/blob/master/docs/HTTP3.md#quiche-version)

## Usage

Building it yourself locally from this repository:

`docker build -t rmarx/curl-http3 .`

Running it directly from DockerHub:

`docker run -it --rm rmarx/curl-http3 curl -V`
```
curl 7.87.0-DEV (aarch64-unknown-linux-gnu) libcurl/7.87.0-DEV BoringSSL quiche/0.16.0
Release-Date: [unreleased]
Protocols: dict file ftp ftps gopher gophers http https imap imaps mqtt pop3 pop3s rtsp smb smbs smtp smtps telnet tftp
Features: alt-svc AsynchDNS HSTS HTTP3 HTTPS-proxy IPv6 Largefile NTLM NTLM_WB SSL threadsafe UnixSockets
```


`docker run -it --rm rmarx/curl-http3 curl -IL https://daniel.haxx.se --http3`

`docker run -it --rm rmarx/curl-http3 curl -IL https://www.youtube.com --http3`

Add `--verbose` for additional protocol level details.

```

HTTP/3 200
content-length: 5802
server: nginx/1.21.1
content-type: text/html
last-modified: Thu, 17 Nov 2022 14:10:32 GMT
etag: "16aa-5edab26f0c089"
cache-control: max-age=60
expires: Tue, 29 Nov 2022 07:28:36 GMT
strict-transport-security: max-age=31536000
via: 1.1 varnish, 1.1 varnish
accept-ranges: bytes
date: Wed, 30 Nov 2022 13:54:37 GMT
age: 33
x-served-by: cache-bma1640-BMA, cache-bru1480057-BRU
x-cache: HIT, HIT
x-cache-hits: 3, 1
x-timer: S1669816477.087234,VS0,VE24
vary: Accept-Encoding
alt-svc: h3=":443";ma=86400,h3-29=":443";ma=86400,h3-27=":443";ma=86400

```

## Enabling qlog

qlog is a verbose JSON-based logging format specifically for QUIC and HTTP/3.
qlog output can be used together with tools like [qvis.quictools.info](https://qvis.quictools.info) to analyze QUIC and HTTP/3 behaviour. 

This build of curl supports qlog output, which can be enabled by setting the `QLOGDIR=/your/dir/here` environment variable.
For example:

```
# opens a shell inside the container
docker run -it --rm rmarx/curl-http3 bash
# will put a .qlog output file in /srv (you can't choose the filename, only the directory)
QLOGDIR=/srv curl -IL https://daniel.haxx.se --http3
```

You can also get the qlog output to the host system directly by mounting a folder as such:

`docker run --volume $(pwd)/qlogs_on_host:/srv -it --rm --env QLOGDIR=/srv rmarx/curl-http3 curl -IL https://daniel.haxx.se --http3`

## Testing alt-svc

In the above examples, we force the use of HTTP/3 through the `--http3` parameter. Normally however, HTTP/3 support needs to be discovered first. This is done by loading the URL over HTTP/1.1 or HTTP/2 first and receiving an [`alt-svc` HTTP response header](https://www.smashingmagazine.com/2021/09/http3-practical-deployment-options-part3/#alt-svc). 

`curl` allows you to store the alt-svc information from the first request in a "cache file", that can then be used in a subsequent request to load over HTTP/3 without explicitly setting the `--http3` flag (better emulating the normal browser/client flow).

An example:

`docker run -it --rm rmarx/curl-http3 bash -c "curl -IL https://daniel.haxx.se --alt-svc as.store; curl -IL https://daniel.haxx.se --alt-svc as.store; cat as.store"`

This should show you a first request over HTTP/2 (or HTTP/1.1), then a request over HTTP/3, and then the contents of the `as.store` alt-svc cache file. 

## Exporting packet captures

Besides using qlog, it can be interesting to use packet capture files (.pcaps) with a tool like Wireshark to examine what's being sent over the wire.

This docker container has support for tcpdump, but you need to manually start and stop it before and after running curl. Additionally, to be able to decrypt the QUIC and HTTP/3 traffic, you need to set the `SSLKEYLOGFILE` variable, which will be used to log the TLS keys. 

An example:

`docker run -it --rm --volume $(pwd)/pcaps_on_host:/srv --env SSLKEYLOGFILE=/srv/tls_keys.txt rmarx/curl-http3 bash -c "tcpdump -w /srv/packets.pcap -i eth0 & sleep 1; curl -IL https://daniel.haxx.se --http3; sleep 2; pkill tcpdump; sleep 2"`

(note: the `sleep` calls are to give tcpdump to properly start and finish. Otherwise, some packets might be missed)

You can then open the `packets.pcap` file in wireshark. To decrypt the traffic, you need to set the "(Pre)-Master-Secret log filename" in Preferences > Protocols > TLS to the exported `tls_keys.txt` file. More details on this on the [Wireshark website](https://wiki.wireshark.org/TLS) or [this blogpost](https://resources.infosecinstitute.com/topic/decrypting-ssl-tls-traffic-with-wireshark/).

Note: Wireshark currently (December 2022) cannot 100% interpret the HTTP/3 part of the traffic, due to incomplete QPACK header compression support. It should still give you enough to be a very useful tool though!
