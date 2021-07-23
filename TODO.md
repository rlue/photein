* Video bitrate threshold and CRF are “magic numbers”;
  research & reconsider these values:

  * <https://support.google.com/youtube/answer/1722171>
  * <https://slhck.info/video/2017/02/24/crf-guide.html>

* CONSIDER: Is it a bad idea to clean up all the empty directories in the
  source dir at exit?

* `Photein::Video#corrupted?`:
  Is `video.bitrate.nil?` a sufficient/complete corruption check?
  (Do we need to add a corresponding check for image files?)
