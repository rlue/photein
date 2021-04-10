🗄️ archivist
===========

Import/rename photos & videos from one directory to another.

Why?
----

* The major cloud photo services (iCloud, Google Photos) are great but not FOSS. 

  (My digital photo/video library belongs to me,
  but if I don’t control the pipeline for viewing/managing it,
  then does it really?)

* Importing photos from many sources
  (📱 cell phone / 📷 digital camera / 💬 chat app)
  into one library with as few manual steps as possible
  is not simple, especially on Linux.

What does it do?
----------------

Suppose your digital camera creates files with names like `R0017839.JPG`.
Archivist will...

* rename files by timestamp (`YYYY-mm-dd HH.MM.SS.jpg`)
* handle conflicts for identical timestamps (`YYYY-mm-dd HH.MM.SSa.jpg`, `YYYY-mm-dd HH.MM.SSb.jpg`...)
* fall back to file creation time if no metadata is found
* sort files into subdirectories by year (`YYYY/YYYY-mm-dd HH.MM.SS.jpg`)
* optionally, transcode video (for reduced filesize)

(Currently only imports .jpg, .dng, .mp4, and .mov files.)

### So how do I use it?

Use this in combination with a [custom systemd service][] to mount, import from,
and unmount your camera’s SD card whenever you plug it in.

Or, use [Syncthing][] to sync photos from your phone to a staging directory on
your computer. Then, run archivist in a cron job to import those photos into
your library on a daily basis.

[custom systemd service]: blob/master/examples/share/systemd/user/archivist-dcim.service
[Syncthing]: https://syncthing.net/

Installation
------------

TBD.

(Why not publish as a gem?
The current project name conflicts with [an existing gem][] on rubygems.org.)

[an existing gem]: https://rubygems.org/gems/archivist

Usage
-----

```sh
$ archivist \
    --volume=/media/ricoh_gr \      # mount this device first / unmount after (requires fstab entry)
    --source=/media/ricoh_gr/DCIM \ # pull photos & videos from here
    --dest=/home/rlue/Pictures      # and deposit them here (in per-year subdirectories)
```

Use `archivist --help` for a summary of all options.

Dependencies
------------

* [MediaInfo][]
* libexif (required by the [exif][] gem)
* ffmpeg (for video transcoding/compression)

  ```sh
  $ brew install libexif           # macOS
  $ sudo apt install libexif-dev   # Debian / Ubuntu
  $ sudo yum install libexif-devel # RedHat / Fedora / CentOS
  ```

[MediaInfo]: https://mediaarea.net/MediaInfo
[exif]: https://github.com/tonytonyjan/exif

License
-------

© 2021 Ryan Lue. This project is licensed under the terms of the MIT License.
