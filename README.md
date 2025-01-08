Ph📸tein
========

A no-nonsense way to organize your personal photo library.

What does it do?
----------------

Photein manages your photos **at the filesystem level**.
It won’t let you browse or edit your photos,
but it will give them a uniform folder structure and filenames,
no matter where they come from:

```sh
# Before                                # After

~                                       ~
├── Downloads                           ├── Downloads
│   ├── 1619593208911.jpeg              └── Pictures
│   ├── DCIM                                ├── 2020
│   │   └── 2021_03_26                      │   ├── 2020-08-01_113129.heic
│   │       ├── R0014285.MOV                │   └── 2020-05-20_160209.png
│   │       ├── R0014286.DNG                └── 2021
│   │       ├── R0014286.JPG                    ├── 2021-02-12_081933a.jpg
│   │       ├── R0014287.DNG                    ├── 2021-02-12_081933b.jpg
│   │       └── R0014287.JPG                    ├── 2021-02-12_081939.mp4
│   ├── IMG_20210212_081933_001.jpg             ├── 2021-03-26_161245.mp4
│   ├── IMG_20210212_081933_002.jpg             ├── 2021-03-26_161518.dng
│   ├── IMG_8953.HEIC                           ├── 2021-03-26_161518.jpg
│   ├── Screenshot_20200520_160209.png          ├── 2021-03-26_170304.dng
│   └── VID_20210212_081939.mp4                 ├── 2021-03-26_170304.jpg
└── Pictures                                    └── 2021-04-28_000008.jpg
```

Photein generates these folders & filenames
based on metadata timestamps, filename timestamps, or file creation times.

> ⚠️ **Note**
>
> If you use a photo management app that decides
> where and how your photos should be stored on disk
> (looking at you, Apple Photos 👀), Photein is not for you.

It can also:

* optimize photos and videos for reduced file size
* shift all timestamps by a given interval
  (for when you forget to update the clock on your camera
  for, _e.g.,_ daylight savings or traveling across time zones)
* backfill GPS metadata / `OffsetTime*` tags based on a given IANA time zone

  > 🤔 **Why would you want that?**
  >
  > One unfortunate quirk of this problem space is that
  > the EXIF standard does not cover video file formats,
  > meaning photos and videos do not have the same set of metadata fields.
  > Worse yet, the field we care about most (timestamps) is inconsistently defined,
  > with **photo timestamps recorded in local time and video timestamps in UTC**.
  >
  > (I haven’t been able to find the text of these specs—supposedly,
  > they are expensive—but it’s been [stated on a few occasions
  > by a pretty authoritative member of the Exiftool forum](https://exiftool.org/forum/index.php?msg=51915).
  > [That same user has noted that](https://exiftool.org/forum/index.php?msg=59329)
  > “there is no standard for embedding EXIF data in a video file.
  > Not that that has stopped a lot of camera makers from forcing it into the file.”)
  >
  > Photein attempts to set _all_ filenames in local time,
  > applying an offset to videos based on the time zone inferred
  > from their GPS location tags—which is only possible if they are present.
  > Other photo utilities (like [immich](https://immich.app)) follow the same strategy,
  > meaning that setting GPS tags can improve filename consistency elsewhere, too.
  >
  > (What about `OffsetTime*`, then? Those tags are superfluous for our needs
  > since they can only be set on photos, which are already in local time—but
  > implementation was straightforward, and they serve the parallel purpose
  > of backfilling missing time zone info, so I figured what the heck. ¯\\\_(ツ)\_/¯)

What _doesn’t_ it do?
---------------------

On its own, Photein is **not** an alternative
to cloud photo services like Google Photos or iCloud—but
in combination with other software, it can be.

If you want to:

* import photos from your phone as soon as you take them
* import photos from a digital camera / SD card as soon as you plug it in
* mirror a low-res copy of your entire photo library to your Android phone

check out Photein’s sister utility [Xferase][],
or try the [automation guides][] below.

[Xferase]: https://github.com/rlue/xferase
[automation guides]: #automation-guides

Installation
------------

```sh
$ gem install photein
```

### Dependencies

* Ruby 2.6+
* [ExifTool][]
* [MediaInfo][]
files)
* ImageMagick (for `--optimize-for=web` option)
* OptiPNG (for `--optimize-for=web` option)
* ffmpeg (for `--optimize-for={web,desktop}` options)
* [mkvtoolnix][] (for `--shift-timestamp` / `--local-tz` options on .webm

[ExifTool]: https://exiftool.org/
[MediaInfo]: https://mediaarea.net/MediaInfo
[mkvtoolnix]: https://mkvtoolnix.download/

Usage
-----

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

Using Photein + systemd, you can:

* [📷➡️🖥️ Set up auto-import from a digital camera](guides/auto-import-digital-camera.md)

But for more complex tasks, like:

* 📱➡️🖥️ Setting up auto-import from an Android phone
* 📱🔄🖥️ Mirroring your library across multiple devices

check out the documentation for [Xferase][],
an always-on background service based on Photein.

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
