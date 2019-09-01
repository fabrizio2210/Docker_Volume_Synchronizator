FROM debian
MAINTAINER fabrizio2210
ENV DOCKERVERSION=18.03.1-ce
ENV DOCKERARCH=x86_64

RUN apt-get update && apt-get install -y csync2 lsyncd sed curl procps iputils-ping && apt-get clean

RUN curl -fsSLO https://download.docker.com/linux/static/stable/${DOCKERARCH}/docker-${DOCKERVERSION}.tgz \
    && tar xzvf docker-${DOCKERVERSION}.tgz --strip 1 -C /usr/local/bin docker/docker \
    && rm docker-${DOCKERVERSION}.tgz

COPY src/* /usr/local/bin/

VOLUME ["/etc", "/var/lib/csync2"]

CMD /usr/local/bin/wrapper.sh
