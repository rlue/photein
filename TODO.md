* Video bitrate threshold is a “magic number”;
  research & reconsider this value.

  https://support.google.com/youtube/answer/1722171

* Add HEALTHCHECK to archivistd Dockerfile

* Resolve docker build requirement `COPY ./photein-0.0.1.gem app/`

* Rename `/app` directory in Dockerfile

* CONSIDER: Is it a bad idea to clean up all the empty directories in the
  source dir at exit?
