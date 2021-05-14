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

* look for a timestamp in...
  * EXIF metadata
  * filename
  * file birthtime
* rename files by that timestamp (`YYYY-mm-dd_HHMMSS.jpg`)
* handle conflicts for identical timestamps (`YYYY-mm-dd_HHMMSSa.jpg`, `YYYY-mm-dd_HHMMSSb.jpg`...)
* sort files into subdirectories by year (`YYYY/YYYY-mm-dd_HHMMSS.jpg`)
* optionally, optimize media for reduced filesize

#### Supported media formats

* .jpg
* .dng
* .heic
* .png
* .mp4
* .mov

### So how do I use it?

#### 📷 Auto-import from a digital camera (Linux)

Customize the provided [sample systemd service][]
to mount, import from, and unmount your camera
whenever you plug it in via USB.

```sh
$ mkdir -p ~/.local/share/systemd/user
$ curl https://raw.githubusercontent.com/rlue/archivist/master/examples/share/systemd/user/archivist-dcim.service -o ~/.local/share/systemd/user/archivist-dcim.service
$ systemctl --user daemon-reload
$ systemctl --user enable archivist-dcim.service
```

> Note: The provided systemd service makes the following
> assumptions:
>
> * Your device’s label is `RICOH_GR`. 
>   (Use `systemctl --all --full -t device`
>   to determine the label of your USB device.)
> * You use [rbenv][] to manage your system’s Ruby environment.
>
> Adjust accordingly.

[sample systemd service]: blob/master/examples/share/systemd/user/archivist-dcim.service
[rbenv]: https://github.com/rbenv/rbenv

#### 📱 Auto-import from an Android phone

Use [Syncthing][] to sync photos from your phone to a staging directory on
your computer. Then, run archivist in a cron job to import those photos into
your library on a daily basis.

[Syncthing]: https://syncthing.net/

Installation
------------

```sh
$ git clone https://github.com/rlue/archivist
$ cd archivist
$ gem build archivist.gemspec
$ gem install archivist-0.0.1.gem
```

Usage
-----

```sh
$ archivist \
    --source=/media/ricoh_gr/DCIM \ # pull photos & videos from here
    --dest=/home/rlue/Pictures      # and deposit them here (in per-year subdirectories)
```

Use `archivist --help` for a summary of all options.

Dependencies
------------

* [ExifTool][]
* [MediaInfo][]
* ImageMagick (for `--optimize-for=web` option)
* OptiPNG (for `--optimize-for=web` option)
* ffmpeg (for `--optimize-for={web,desktop}` options)
* lsof (for `--safe` option)

[ExifTool]: https://exiftool.org/
[MediaInfo]: https://mediaarea.net/MediaInfo

License
-------

© 2021 Ryan Lue. This project is licensed under the terms of the MIT License.
