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
> where and how your photos should be stored on disk
> (👀 looking at you, Apple Photos), Photein is not for you.

It can also optimize photos and videos for reduced file size.

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
* ImageMagick (for `--optimize-for=web` option)
* OptiPNG (for `--optimize-for=web` option)
* ffmpeg (for `--optimize-for={web,desktop}` options)

[ExifTool]: https://exiftool.org/
[MediaInfo]: https://mediaarea.net/MediaInfo

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
