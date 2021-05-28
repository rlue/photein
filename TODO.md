* Video bitrate threshold is a “magic number”;
  research & reconsider this value.

  https://support.google.com/youtube/answer/1722171

* CONSIDER: Is it a bad idea to clean up all the empty directories in the
  source dir at exit?

* Dependency checks: Wrap calls to ffmpeg / imagemagick / optipng
  (and exiftool / mediainfo?) in begin/rescue/end statements
