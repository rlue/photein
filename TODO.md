* Make sure all metadata is always preserved across downscaling / re-encoding

* Support `--shift-timestamp` option
  (accept integer number of hours to shift timestamp by)

* Support `--geotag` option
  (accept GPS lat/lon OR IANA TZ identifier)

* Support custom filename templates

* Address crash from panoramas

  ```
  I, [2021-08-27T12:57:58.753721 #6539]  INFO -- : optimizing /media/data/rlue/memories/_staging/web/IMG_20210827_
  /home/rlue/.rbenv/versions/3.0.0/lib/ruby/gems/3.0.0/gems/mini_magick-4.11.0/lib/mini_magick/shell.rb:17:in `run
  convert-im6.q16: width or height exceeds limit `/media/data/rlue/memories/_staging/web/IMG_20210827_071808.jpg'
  convert-im6.q16: no images defined `/tmp/photein/2021-08-27_071808.jpg' @ error/convert.c/ConvertImageCommand/32
          from /home/rlue/.rbenv/versions/3.0.0/lib/ruby/gems/3.0.0/gems/mini_magick-4.11.0/lib/mini_magick/tool.r
          from /home/rlue/.rbenv/versions/3.0.0/lib/ruby/gems/3.0.0/gems/mini_magick-4.11.0/lib/mini_magick/tool.r
          from /home/rlue/.rbenv/versions/3.0.0/lib/ruby/gems/3.0.0/gems/photein-0.0.4/lib/photein/image.rb:33:in
          from /home/rlue/.rbenv/versions/3.0.0/lib/ruby/gems/3.0.0/gems/photein-0.0.4/lib/photein/media_file.rb:2
          from /home/rlue/.rbenv/versions/3.0.0/lib/ruby/gems/3.0.0/gems/photein-0.0.4/bin/photein:45:in `each'
          from /home/rlue/.rbenv/versions/3.0.0/lib/ruby/gems/3.0.0/gems/photein-0.0.4/bin/photein:45:in `<top (re
          from /home/rlue/.rbenv/versions/3.0.0/bin/photein:23:in `load'
          from /home/rlue/.rbenv/versions/3.0.0/bin/photein:23:in `<main>'
  ```

* Video bitrate threshold and CRF are “magic numbers”;
  research & reconsider these values:

  * <https://support.google.com/youtube/answer/1722171>
  * <https://slhck.info/video/2017/02/24/crf-guide.html>

* CONSIDER: Is it a bad idea to clean up all the empty directories in the
  source dir at exit?

* `Photein::Video#corrupted?`:
  Is `video.bitrate.nil?` a sufficient/complete corruption check?
  (Do we need to add a corresponding check for image files?)
