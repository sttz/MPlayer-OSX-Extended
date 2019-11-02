Retirement Notice
-----------------

**MPlayer OSX Extended has been retired and won't receive any future updates.**

After development of MPlayer OSX Extended has been slow for many years and development of the underlying MPlayer project has moved on to mpv, I have decided that it doesn't make sense to invest more time into this project.

Consider using one of the following alternatives for video playback on macOS:
* [IINA](https://iina.io/): Great UI for mpv
* [mpv](https://mpv.io/): Has its own UI but is a bit cryptic
* [VLC](http://www.videolan.org/): Feature-packed but clunky interface

MPlayer OSX Extended
====================

Homepage:
http://www.mplayerosx.ch/

Issue tracker:
https://github.com/sttz/MPlayer-OSX-Extended/issues

Downloads:
http://code.google.com/p/mplayerosxext/downloads/list

Build Instructions
------------------

The project can be built using either XCode 3 or 4.
Make sure you've got the dependencies below and then you should be able to compile MPE directly with XCode.

### Dependencies

#### Sparkle

MPE requires my [Sparkle Fork](https://github.com/sttz/Sparkle).
It adds updating separate bundles without a restart, used in MPE for updating its binary bundles with Sparkle.

#### Fontconfig & Freetype

It's best to use the same Fontconfig and Freetype versions as used in the binary bundle. The default setup links to the libraries inside the `mpextended.mpBinaries` bundle in the binaries folder. The easiest way to get that is download the latest (test) version of MPE and extracting the binary bundle form "`MPlayer OSX Extened.app/Contents/Resources/Binaries`".

**Note**: I've reorganized the bundle after the FFMpeg-MT merge and haven't released a test version with it yet. For now it's probably best to link to the system Fontconfig and Freetype libraries.

#### libiconv.2 ####

On Lion use the system's `libiconv.2`. On Snow Leopard the system's `libiconv.2` is not new enough (Version 8 is required)  so install libiconv using for example homebrew or macports, then link to it.
