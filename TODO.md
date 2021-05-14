* Video bitrate threshold is a “magic number”;
  research & reconsider this value.

  https://support.google.com/youtube/answer/1722171

* Add HEALTHCHECK to archivistd Dockerfile

* Resolve docker build requirement `COPY ./archivist-0.0.1.gem app/`

* Rename `/app` directory in Dockerfile

* ```ruby
  Signal.trap('INT') do
    Archivist::Logger.debug("unmounting #{PARAMS[:volume]}") if PARAMS.key?(:volume)
    system("umount #{PARAMS[:volume]}") if PARAMS.key?(:volume)

    exit 130
  end
  ```

* Also delete all tempfiles upon cleanup
