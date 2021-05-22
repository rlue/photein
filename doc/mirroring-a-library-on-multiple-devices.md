📱🔄🖥️ Mirroring a Library on Multiple Devices
==============================================

TODO: Write me.

#### via CLI

```sh
$ docker run -d \
    --name xferase \
    --user $(id -u) \  # fixes file permission issues
    -e TZ=America/Los_Angeles \
    -v /media/data/rlue/memories:/data \
    -e WATCH_DIR=/data/_inbox \
    -e STAGING_DIR=/data/_staging \
    -e HI_RES_DIR=/data/originals \
    -e LO_RES_DIR=/data/web \
    rlue/xferase
```

#### via Docker Compose

```yaml
# docker-compose.yml

version: '3'

services:
  xferase:
    image: rlue/xferase:latest
    user: 1000
    volumes:
      /media/data/rlue/memories:/data
    environment:
      TZ: America/Los_Angeles
      INBOX: /data/_inbox
      STAGING: /data/_staging
      LIB_ORIG: /data/originals
      LIB_WEB: /data/web
```
