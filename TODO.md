* Video bitrate threshold is a “magic number”;
  research & reconsider this value.

  https://support.google.com/youtube/answer/1722171

* Refactor transcoding/optimization logic

* Refactor logic into separate classes

* Add HEALTHCHECK to archivistd Dockerfile

* Add timestamp/import strategies for chat app downloads

* Resolve docker build requirement `COPY ./archivist-0.0.1.gem app/`

* Rename `/app` directory in Dockerfile

* ```ruby
  Signal.trap('INT') do
    Archivist::Logger.debug("unmounting #{PARAMS[:volume]}") if PARAMS.key?(:volume)
    system("umount #{PARAMS[:volume]}") if PARAMS.key?(:volume)

    exit 130
  end
  ```
