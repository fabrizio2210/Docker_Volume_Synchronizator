FROM balenalib/armv7hf-debian
MAINTAINER fabrizio2210

RUN [ "cross-build-start" ]

RUN apt-get update && apt-get install -y csync2 lsyncd sed wget && apt-get clean

RUN wget https://github.com/jpillora/chisel/releases/download/1.2.4/chisel_linux_arm.gz && \
    gunzip chisel_linux_arm.gz && \
    mv chisel_linux_arm /usr/local/bin/chisel && \
    chmod +x /usr/local/bin/chisel


COPY src/* /usr/local/bin/

VOLUME ["/etc", "/var/lib/csync2"]
EXPOSE 80/tcp

RUN [ "cross-build-end" ]

CMD /usr/local/bin/wrapper.sh
