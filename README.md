PhπΈtein
========

A no-nonsense way to organize your personal photo library.

What does it do?
----------------

Photein manages your photos **at the filesystem level**.
It wonβt let you browse or edit your photos,
but it will give them a uniform folder structure and filenames,
no matter where they come from:

```sh
# Before                                # After

~                                       ~
βββ Downloads                           βββ Downloads
β   βββ 1619593208911.jpeg              βββ Pictures
β   βββ DCIM                                βββ 2020
β   β   βββ 2021_03_26                      β   βββ 2020-08-01_113129.heic
β   β       βββ R0014285.MOV                β   βββ 2020-05-20_160209.png
β   β       βββ R0014286.DNG                βββ 2021
β   β       βββ R0014286.JPG                    βββ 2021-02-12_081933a.jpg
β   β       βββ R0014287.DNG                    βββ 2021-02-12_081933b.jpg
β   β       βββ R0014287.JPG                    βββ 2021-02-12_081939.mp4
β   βββ IMG_20210212_081933_001.jpg             βββ 2021-03-26_161245.mp4
β   βββ IMG_20210212_081933_002.jpg             βββ 2021-03-26_161518.dng
β   βββ IMG_8953.HEIC                           βββ 2021-03-26_161518.jpg
β   βββ Screenshot_20200520_160209.png          βββ 2021-03-26_170304.dng
β   βββ VID_20210212_081939.mp4                 βββ 2021-03-26_170304.jpg
βββ Pictures                                    βββ 2021-04-28_000008.jpg
```

Photein generates these folders & filenames
based on metadata timestamps, filename timestamps, or file creation times.

> β οΈ **Note**
>
> If you use a photo management app that decides
> where and how your photos should be stored on disk
> (looking at you, Apple Photos π), Photein is not for you.

It can also optimize photos and videos for reduced file size.

What _doesnβt_ it do?
---------------------

On its own, Photein is **not** an alternative
to cloud photo services like Google Photos or iCloudβbut
in combination with other software, it can be.

If you want to:

* import photos from your phone as soon as you take them
* import photos from a digital camera / SD card as soon as you plug it in
* mirror a low-res copy of your entire photo library to your Android phone

check out Photeinβs sister utility [Xferase][],
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

* [π·β‘οΈπ₯οΈ Set up auto-import from a digital camera](guides/auto-import-digital-camera.md)

But for more complex tasks, like:

* π±β‘οΈπ₯οΈ Setting up auto-import from an Android phone
* π±ππ₯οΈ Mirroring your library across multiple devices

check out the documentation for [Xferase][],
an always-on background service based on Photein.

Development
-----------

Contributions welcome.

> β οΈ **Warning**
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

Β© 2021 Ryan Lue. This project is licensed under the terms of the MIT License.
