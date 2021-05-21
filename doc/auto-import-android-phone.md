📱➡️🖥️ Auto-Import: Android Phone
================================

> ⚠️ **Caveat**
>
> This document details how to configure automated transfer
> from a phone to a computer.
> In this setup, photos are **removed from the phone** after import.
> If this workflow is acceptable to you, read on.
>
> Maintaining a local copy of your photo library on your phone after import
> is a little more complicated;
> for that, see [Mirroring a Library][] instead.
>
> [Mirroring a Library]: mirroring-a-library-on-multiple-devices.md

Step 1: Sync your Android photo gallery to your computer
--------------------------------------------------------

Use a cloud file sync utility to sync your phone’s DCIM directory
to an “inbox” directory on your computer.
(I use [Syncthing][], but I imagine that Dropbox works just as well.)

[Syncthing]: https://syncthing.net/

Step 2: Import photos from your “inbox” to your library
-------------------------------------------------------

The easiest way to process the photos that arrive in your “inbox”
is to run photein in a cron job.

```sh
$ crontab -e

    # Run photein once an hour, on the hour
    0 * * * * photein --source ~/Pictures/_inbox --recursive --dest ~/Pictures
```

If polling is not your style, you can build your own script to monitor the
“inbox” for changes using inotify. This approach is left as an exercise for
the reader. 😂
