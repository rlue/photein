📷➡️🖥️ Auto-Import: Digital Camera
=================================

Linux users can set up a systemd service to import photos automatically
any time they insert their camera’s SD card or plug it in via USB—but
to make it work, you’ll need to set it up so that
your device can be mounted without `sudo` first.

Why? Our custom systemd service must be run as a regular user;
otherwise, your imported photos will be owned by `root`.

> ⚠️ **Note**
>
> The examples below are taken from the author’s own system and camera;
> modify as appropriate.

Step 1: Mounting without `sudo`
-------------------------------

_fstab_ (short for “filesystem table”) is a system configuration file
detailing rules for how to mount individual storage devices.
Here, we will hardcode a rule
allowing regular users to mount your camera’s SD card,
along with specifying what directory it should be mounted to.

```sh
# Create a permanent mount point
$ sudo mkdir /media/ricoh_gr

# Use blkid to find your device’s LABEL or UUID
$ sudo blkid
/dev/sda1: UUID="9d5c5dfb-87d9-0dc7-ab96-658bf52e93bf" TYPE="ext4" PARTUUID="7bcbc41d-cfff-874c-a825-e9041357d15e"
/dev/sdb1: UUID="6364-D4D0" TYPE="vfat" PARTUUID="7568cf1f-66b6-4875-9f0e-31be907c3bda"
/dev/sdb2: UUID="dec5c1ad-b8cb-4c2f-c798-e169d11fc29e" TYPE="ext4" PARTUUID="e3f86e17-96a7-4eec-ba49-83a7a0cd1a2e"
/dev/sdb3: UUID="b82f560b-db77-424c-8aa3-9ee5bc78ccd4" TYPE="swap" PARTUUID="8d4cf864-4350-4b26-8af6-70786ae3e729"
/dev/sdc1: LABEL_FATBOOT="RICOH_GR" LABEL="RICOH_GR" TYPE="vfat"
                                         # ⮴ There it is!

# Add an entry for it to your /etc/fstab
# (see `man fstab` to learn more)
$ sudo -e /etc/fstab

    # <file system>		<mount point>	<type>	<options>		<dump>	<pass>
    LABEL=RICOH_GR		/media/ricoh_gr	vfat	defaults,noauto,user	0	2

# Verify that it works 🎉🎉🎉
$ mount /media/ricoh_gr
```

Step 2: Auto-running Photein when connecting to USB
---------------------------------------------------

_systemd_ is a Linux background service manager (among other things)
that coordinates when processes should be stopped, started, or restarted.
Here, we will register a new service
that mounts the camera, imports with photein, and unmounts
whenever it is attached.

> ⚠️ **Note**
>
> If you use a Ruby environment manager like rbenv or rvm,
> use `rbenv exec photein` / `rvm-exec photein`
> in your systemd service’s `ExecStart` line.

```sh
# Find the name for your camera’s systemd device unit
$ systemctl --all --full --type=device | grep label | cut -d' ' -f1
...                                         # ⮴ or 'uuid', if that’s what you’re using
dev-disk-by\x2dlabel-RICOH_GR.device

# Create the service file
$ mkdir -p ~/.local/share/systemd/user
$ vim ~/.local/share/systemd/user/dcim-import.service

    [Unit]
    Description=Digital Photo Importer for Ricoh GR
    BindsTo=dev-disk-by\x2dlabel-RICOH_GR.device
    After=dev-disk-by\x2dlabel-RICOH_GR.device

    [Service]
    ExecStart=/bin/sh -c 'mount /media/ricoh_gr; photein --source /media/ricoh_gr/DCIM --recursive --dest /home/rlue/Pictures; umount /media/ricoh_gr'
    Restart=no

    [Install]
    WantedBy=dev-disk-by\x2dlabel-RICOH_GR.device

# Reload to pick up your changes
$ systemctl --user daemon-reload

# Take a photo, plug in your camera, and run manually verify that it works
$ systemctl --user start dcim-import

# “Install” it to run automatically each time your camera is plugged in 🎉🎉🎉
$ systemctl --user enable dcim-import
```

Now, you should be able to
take some photos, plug in your camera, walk away,
and let Photein take care of the rest. 🥂
