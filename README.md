Ph📸tein / 🔀ferase
===================

All your photos under one roof.

What do they do?
----------------

`photein` is a CLI utility for batch-importing
your personal photos & videos into a central library.

`xferase` is an always-on background service that uses `photein`
to continuously import new photos & videos as they come in.

When combined with other software,
they can be used as a kind of self-hosted / DIY alternative
to cloud photo services like Google Photos or iCloud.

> ⚠️ **Note**
>
> Unlike true cloud photo services,
> this approach works by keeping a full copy of your photo library
> in local storage on each device you sync to.

### Photein

Photein manages your photos **at the filesystem level**.
It won’t let you browse or edit your photos,
but it will give them a uniform folder structure and filenames,
no matter where they come from:

```sh
# Before                                # After

~/Pictures                              ~/Pictures
└── _inbox                              ├── _inbox
    ├── 1619593208911.jpeg              ├── 2020
    ├── DCIM                            │   ├── 2020-08-01_113129.heic
    │   └── 2021_03_26                  │   └── 2020-05-20_160209.png
    │       ├── R0014285.MOV            └── 2021
    │       ├── R0014286.DNG                ├── 2021-02-12_081933a.jpg
    │       ├── R0014286.JPG                ├── 2021-02-12_081933b.jpg
    │       ├── R0014287.DNG                ├── 2021-02-12_081939.mp4
    │       └── R0014287.JPG                ├── 2021-03-26_161245.mp4
    ├── IMG_20210212_081933_001.jpg         ├── 2021-03-26_161518.dng
    ├── IMG_20210212_081933_002.jpg         ├── 2021-03-26_161518.jpg
    ├── IMG_8953.HEIC                       ├── 2021-03-26_170304.dng
    ├── Screenshot_20200520_160209.png      ├── 2021-03-26_170304.jpg
    └── VID_20210212_081939.mp4             └── 2021-04-28_000008.jpg
```

Photein generates these folders & filenames
based on metadata timestamps, filename timestamps, or file creation times.

> ⚠️ **Note**
>
> If you use a photo management app that decides
> where and how your photos should be stored on your system (like Apple Photos), 
> Photein is not for you.

### Xferase

Xferase watches a directory of your choosing (its “inbox”),
and whenever any files are placed there,
it automatically imports them into your photo library.

It creates and manages two parallel copies of your library
(one original/hi-res, one optimized for web)
and ensures that when you delete a photo from one,
it is automatically removed from the other.

With the help of [Syncthing][] and systemd,
you can automatically pull new photos from your camera or Android phone
into Xferase’s inbox.
Syncthing can also push your complete, web-optimized photo library
back to your phone (or, say, push your hi-res library out to another machine).

[Syncthing]: https://syncthing.net/

Why?
----

I could not find any existing software product that:

1. imports photos from many sources\* with **no mouse or keyboard interaction**

   \*_e.g.,_ 📱 cell phone / 📷 digital camera / 💬 chat app download

2. enforces a clean, consistent, **user-visible directory & filename scheme**

   (I want to be able to access my photos from the file manager,
   find them in an “Open...” dialog,
   or sync them to other devices with generic tools
   like rsync, Dropbox, or Syncthing.)

3. comes with **no recurring subscription fee**—or better yet, is FOSS

   (My digital photo/video library belongs to me,
   but if I don’t control the pipeline for viewing/managing it,
   then does it really?)

4. works with Linux

Installation
------------

```sh
$ gem install photein
```

### Dependencies

* Ruby 2.7+
* [ExifTool][]
* [MediaInfo][]
* ImageMagick (for `--optimize-for=web` option)
* OptiPNG (for `--optimize-for=web` option)
* ffmpeg (for `--optimize-for={web,desktop}` options)

[ExifTool]: https://exiftool.org/
[MediaInfo]: https://mediaarea.net/MediaInfo

Usage
-----

### Simple import

```sh
$ photein \
    --source /media/ricoh_gr/DCIM \ # batch-import photos from here
    --recursive \                   # including subdirectories
    --dest /home/rlue/Pictures      # into here
```

Use `photein --help` for a summary of all options.

#### Supported media formats

* .jpg
* .dng
* .heic
* .png
* .mp4
* .mov

### Automation guides

* [📷➡️🖥️ Set up auto-import from a digital camera](doc/auto-import-digital-camera.md)
* [📱➡️🖥️ Set up auto-import from an Android phone](doc/auto-import-android-phone.md)
* [📱🔄🖥️ Mirror your library across multiple devices](doc/mirroring-a-library-on-multiple-devices.md)

Development
-----------

Contributions welcome.

> ⚠️ **Warning**
>
> The RSpec test suite contains no unit tests.
> It solely tests `photein` as a CLI utility, or in other words,
> it defines expectations against the effects of `system('photein <args>')`.
>
> Because `Kernel#system` runs the given command in a subprocess, 
> it prints to a different stdout than `rspec` itself.
> This makes test failures cumbersome to debug,
> because `puts` statements never appear in the test output,
> and `binding.pry` will cause the test to appear to hang
> as it waits for user input on an invisible stdin.

License
-------

© 2021 Ryan Lue. This project is licensed under the terms of the MIT License.
