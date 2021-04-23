# syntax = docker/dockerfile:1.1-experimental
FROM ruby:3.0.1-alpine
MAINTAINER Ryan Lue <hello@ryanlue.com>

WORKDIR /app
COPY archivist-0.0.1.gem /app
COPY archivistd /app

RUN apk add --no-cache --update \
    build-base \
    exiftool \
    imagemagick \
    ffmpeg \
    optipng

RUN gem install \
    archivist-0.0.1.gem \
    debouncer \
    rb-inotify

CMD ["./archivistd"]
