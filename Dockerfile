FROM dprus/python-alpine-openssl-rsync-jre
LABEL maintainer="richard@powell.dev"

RUN apk update && \
  apk add --no-cache msmtp && \
  rm -rf /var/cache/apk/*

RUN ln -sf /usr/bin/msmtp /usr/sbin/sendmail
