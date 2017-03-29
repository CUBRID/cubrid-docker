FROM centos

RUN groupadd -r cubrid && useradd -r -g cubrid -d /home/cubrid -m cubrid

ENV GOSU_VERSION 1.10
RUN set -x \
	&& yum -y install epel-release \
	&& yum -y install wget dpkg \
	&& dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
	&& wget -O /usr/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
	&& wget -O /tmp/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /tmp/gosu.asc /usr/bin/gosu \
	&& rm -r "$GNUPGHOME" /tmp/gosu.asc \
	&& chmod +x /usr/bin/gosu \
	&& gosu nobody true \
	&& yum -y remove dpkg 

ENV CUBRID_VERSION latest
ENV CUBRID /home/cubrid/CUBRID
ENV CUBRID_DATABASES /var/lib/cubrid
ENV CUBRID_DB cubdb
ENV CUBRID_VOLUME_SIZE 100M
ENV CUBRID_LOCALE en_US
ENV CUBRID_COMPONENTS ALL
ENV PATH $CUBRID/bin:$PATH
ENV LD_LIBRARY_PATH=$CUBRID/lib

RUN set -x \
	&& wget -O cubrid.tar.gz ftp://ftp.cubrid.org/CUBRID_Engine/nightly/develop/CUBRID-$CUBRID_VERSION-Linux.x86_64.tar.gz \
	&& tar -xzf cubrid.tar.gz -C /home/cubrid && rm cubrid.tar.gz \
	&& mkdir -p $CUBRID_DATABASES \
	&& chown -R cubrid:cubrid $CUBRID $CUBRID_DATABASES \
	&& yum -y remove wget \
	&& yum clean all

VOLUME $CUBRID_DATABASES

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 33000
