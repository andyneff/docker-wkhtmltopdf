FROM ubuntu:16.04 as prep
LABEL maintainer="Andrew Neff <andrew.neff@visionsystemsinc.com>"

SHELL ["bash", "-o", "pipefail", "-euc"]
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update; \
    apt-get install -y wget xz-utils

ENV WKHTMLTOPDF_VERSION=0.12.4
RUN wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox-${WKHTMLTOPDF_VERSION}_linux-generic-amd64.tar.xz; \
    tar Jxf wkhtmltox-${WKHTMLTOPDF_VERSION}_linux-generic-amd64.tar.xz; \
    cp -r wkhtmltox/* /usr/local

RUN wget http://ftp.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.6_all.deb

ENV GOSU_VERSION 1.10
RUN apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates wget; \

    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \

    # verify the signature
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc; \

    chmod +x /usr/local/bin/gosu; \
    # verify that the binary works
    gosu nobody true

ADD entrypoint.bsh /
RUN chmod 755 /entrypoint.bsh

#------------------------------------------------------------------------------

FROM ubuntu:16.04
LABEL maintainer="Andrew Neff <andrew.neff@visionsystemsinc.com>"

SHELL ["bash", "-o", "pipefail", "-euc"]
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=prep /ttf-mscorefonts-installer_3.6_all.deb /

RUN install_deps="wget cabextract"; \
    apt-get update; \
    apt-get install -y --no-install-recommends ${install_deps} xfonts-utils; \
    dpkg -i ttf-mscorefonts-installer_3.6_all.deb;\
    apt-get install -f; \
    #This would be VERY bad, you can't remove ttf-mscorefonts-installer
    #apt-get purge -y --auto-remove ${install_deps}; \
    rm -rf /var/apt/lists/*

COPY --from=prep /usr/local /usr/local

RUN apt-get update; \
    apt-get install -y --no-install-recommends \
                    xorg libssl1.0.0 libxrender1 xfonts-scalable; \
    rm -rf /var/apt/lists/*

COPY --from=prep /entrypoint.bsh /
ENTRYPOINT ["/entrypoint.bsh"]

CMD ["wkhtmltopdf", "--help"]