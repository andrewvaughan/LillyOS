# LillyOS

LillyOS is an extremely small operating system intended for discrete use.  LillyOS is built upon the belief that any
time a team grows, so does a chance for failure.  As such, everything from the bootloader to applications are built
into this tiny package to provide extreme security when using the platform.

## Dependencies

To cross-compile LillyOS, a number of dependencies are required.  These dependencies vary depending on your platform.

### Linux

To cross-compile using Linux, a number of packages are necessary.  The packages used are the same for `yum` if that is
the package manager being used:

```bash
sudo apt-get install build-essential nasm
```

If you intend to create an ISO file, the following must be installed as well:

```bash
sudo apt-get install genisoimage
```

### MacOS

Installation is similar to Linux, but uses [Homebrew](https://brew.sh/) to install necessary packages.  The provided
`Makefiles` are used the same way as described above, but the following must be installed with Homebrew first:

```bash
brew install nasm cdrtools
```

### Windows

Coming soon.


## Installation

LillyOS can be cross-compiled into an IMG file, and then optionally converted into an ISO for use.  The IMG option is
intended for direct use, either by being copied to media (e.g., a floppy disk) or used as a virtual floppy disk.  The
ISO option is available for users who wish to run their system directly from LillyOS or burn it to more advanced
bootable media (e.g., a CD-ROM or USB key).

After dependencies are installed (see below), one of he following can be run to build an image for your system:

1. `make image`
2. `make iso` (default)

By choosing `make image`, an `.iso` file will not be created.  Instead, a raw `.img` file will be created which can be
copied to a floppy disk using dd:

`dd if=lillyos-VERSION.img of=/mnt/yourfloppy-drive`

This file can also be used on a virtual operating system, if loaded into a virtual floppy drive.

Alternatively, the `iso` option will create both the `.img` and `.iso` files, the latter of which can be run virtually
or copied to a bootable CD or USB key.


## Emulation

Emulation is best done with QEMU.  This can be installed with Linux or Homebrew for MacOS by installing the `qemu`
package.  *Note* - if using MacOS, you will want to use the `qemu-system-i386` executable in place of `qemu` below.

To run a created image, simply load the created image in QEMU, loading LillyOS into the virtual hard drive:

`qemu -hda lillyos-VERSION.img`

If you prefer to emulate a floppy disk in QEMU, the command can be changed to reflect this:

`qemu -fda lillyos-VERSION.img`

Both of these should work without issue, due to the small size of LillyOS.
