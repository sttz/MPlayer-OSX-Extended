Changelog
=========

## Revision 14 (9. January 2011): ##

-   Major Changes:
    -   Redesigned fullscreen controls by Steven La. Thanks!
    -   Add audio output device selection to preferences.
    -   New no-distraction fullscreen option (blocks menu, dock, task
        switcher, growl, etc).

-   Improvements:
    -   Improve visibility of scrub bar badge.
    -   Add option to enable equalizers by default and save defaults for
        the video equalizer.
    -   Add tab-key to cycle timestamp display modes (shows controls
        first in fullscreen).
    -   Remember timestamp display mode (separately for
        player/playlist).
    -   Improved Spaces compatibility.

-   Fixes:
    -   Fix MPE not opening any new files if all player windows have
        been closed.
    -   Fix Fontconfig having to always rebuild its caches when using
        32bit and 64bit clients.
    -   Fix loosing audio when plugging/unplugging headphones.
    -   Fix on top while playing when a movie is starting.
    -   Fix MPE not launching when the screenshot save location doesn't
        exist.
    -   Fix a bug that would toggle out of fullscreen when playing from
        the playlist.
    -   Fix issues with files that contain problematic metadata.
    -   Fix menu key binding interfering with text input.

-   New MPlayer and MPlayer-MT build from 7. January 2011 (r32769).

## Revision 13 (1. February 2010) ##

-   Major changes:
    -   Redesigned preferences window
    -   MPlayer binary bundles
    -   Interactive audio and video equalizers
    -   New inspector window
    -   Redesigned player window (by Nick Saia)
    -   Support for multiple player instances

-   Smaller changes:
    -   Custom screenshot save location
    -   OSD level and subtitle scale now apply immediately
    -   Better custom aspect ratio support
    -   Audio equalizer presets
    -   Per-file settings in the inspector including audio and subtitle
        delay
    -   Added and fixed framestep function
    -   Added loop option
    -   Faster adding of files to the playlist
    -   Added recent files menu
    -   Fix old Apple Remote on Snow Leopard and add support for new one
    -   Added support for selecting vob subtitles
    -   Clicking on timestamps will cycle the displayed time mode
    -   Improved support for VIDEO\_TS folders
    -   Improved detection of initial streams

-   Fixes:
    -   Many playlist fixes
    -   Fix garbled MPEG1/2 playback
    -   Fix video view related crashed
    -   The player window is hidden if it's on the same screen that is
        used for fullscreen
    -   Removed in this release:
    -   Video output selection (internal is the only option now)
    -   ASS subtitles are always enabled
    -   Skip loopfilter and fast options have been merged
    -   The MPlayer config file in \~/.mplayer will now longer be loaded

## Revision 12 (18. October 2009) ##

-   This update requires at least OSX 10.5 (Leopard)!
-   Highlights
    -   Compatible with OSX 10.6 (Snow Leopard)
    -   GUI and MPlayer are now 64bit compatible (\~20-50% faster)

-   Changes
    -   Chapter support no longer limited to MKV
    -   Refine the behavior of the Apple Remote's combined skip/seek
        buttons

-   Bugfixes
-   Fix two Snow Leopard issues
-   Fix additional parameters being ignored in some cases
    (especially -vf-add/-af-add)
-   Fix loading of subtitles with an apostrophe in their path
-   Fix player window from appearing in fullscreen when using on top
    while playing
-   Don't set the -monitoraspect MPlayer option (use Additional
    Parameters if needed)
-   Fix fullscreen controls disappearing when being dragged
-   New MPlayer and MPlayer-MT build from 18. October 2009 (r29777)

## Revision 11 (27. June 2009) ##

-   New icon by mar2o
-   Fullscreen improvements:
    -   Option to black out other screens while in fullscreen
    -   Don't hide player window to allow using it on a second
        screen
    -   Check that fullscreen controls are never placed off-screen
    -   Don't hide menu bar except when going fullscreen on main
        screen

-   Interface improvements:
    -   Enable volume changing and seeking with the scroll wheel
    -   Allow player window to be dragged by clicking on the video
    -   Additional option for on-top while playing only
    -   Allow overriding pre-defined file types (drop-down in open
        dialog, hold command while dragging file on window)
    -   Add encoding selection to open subtitle dialog
    -   Update cache slider range to 256MB and allow higher values
        to be entered in the text box

-   Switch to new MPlayer build style with shared libraries (saves
    17MB or 36%)
-   Add log rotation to avoid MPlayerOSX.log getting unreasonably
    huge
-   Add BS2B audio filter (to simulate speakers through headphones
    for a more natural listening experience)
-   Bugfixes:
    -   Fixed a crash when going to fullscreen
    -   Fix occasional volume "leak" at the start of a movie
    -   Fix a problem with preferences window not closing
    -   On-top now doesn't place the window above menus
    -   Fix a memory leak in the video output (patch by mpx-trax AT
        the-color-black.net)
    -   Fix MPlayer being marked as unresponsive and spindump on
        Leopard eating CPU time
    -   Video no longer stops when a menu is opened for a longer
        time

-   New MPlayer and MPlayer-MT build from 22. June 2009 (r29378)

## Revision 10 (18. April 2009) ##

-   Much improved scrubbing bar
-   Fix font selection
-   Fix video size options in preferences
-   Add NSV and FLV to file types
-   Fix skipping buttons on player window and on fullscreen controls
-   Fix crash when opening a file after another one was already
    opened
-   Fix a memory leak in MPlayer when used with the internal video
    output
-   Fix playback with more than 8 cores
-   Some performance and size optimiziations
-   New MPlayer and MPlayer-MT build from 18. April 2009 (r29185)

## Revision 9 (08. April 2009) ##

-   Support for multithreaded decoding (FFmpeg-MT - still
    experimental)
-   Custom aspect ratio from preferences selectable in aspect ratio
    menu
-   Option to disable animated transitions of the interface
-   Add missing file types (flac, m2ts)
-   Support opening URLs from other applications (like a Browser)
-   Subtitles can now be dragged onto the player or opened in the
    finder to load them while a movie is playing
-   Save fullscreen controls position relative to screen
-   Support opening multiple files at once in the Finder or by
    dragging onto the icon
-   Updated deinterlace options
-   Option to skip loop filters (H264)
-   Add option to update to prereleases through Sparkle
-   Various bug fixes
-   Dropped support for PPC without altivec
-   New MPlayer and MPlayer-MT build from 07. April 2009 (r29150)

## Revision 8 (09. January 2009) ##

-   Fullscreen controls
-   Automatic updates with Sparkle
-   Font and font style selection with Fontconfig
-   Automatic detection of subtitle encoding for supported languages
-   Improved and expanded font, subtitles and osd options
-   Options for AC3 and DTS pass-through
-   Internal video output support for multiple gui instances
-   Better Fontconfig cache warning
-   Fix going back to fullscreen on Tiger
-   Fix some memory related issues
-   Other small fixes
-   Includes MPlayer build r28284 from 9. January 2009

## Revision 7 (20. October 2008) ##

-   Fixed internal video output on Tiger
-   Fixed internal video output with too little shared memory
-   Fixed aspect ratio preferences
-   Improved fullscreen transition for internal video output
-   Support for the Apple Remote
-   Various other small bug fixes
-   Updated mplayer binary to r27807 from 20. Oct 2008

## Revision 6 (22. August 2008) ##

-   Threaded integrated video display
-   (gui no longer blocks video)
-   MKV chapter selection
-   Fullscreen device selection
-   Easier application of preferences changes
-   Size and color selection for subtitles
-   Subtitle encoding selection fixed
-   Various other small bug fixes

## Revision 5 (13. August 2008) ##

-   Stream selection
-   Don't minimize and reopen video when switching movies
-   Add items to playlist without stopping playback
-   Remember if playlist is opened
-   Don't spill all log messages to system.log
-   Improved volume control
-   Expose more actions in menus with keyboard
-   Fixed Taking Screenhots
-   Switched to MPlayer icon from tango project

## Revision 4 (1. August 2008) ##

-   Recent SVN mplayer build (PPC only with Altivec)
-   Fontconfig and OSX fix

## Revision 3 (28. July 2008) ##

-   Fontconfig and font encoding fix
-   Screenshot filter loading fix
-   Support for older mplayer binaries
-   Included RC2 mplayer binary

## Revision 2 (26. July 2008) ##

-   Redesigned preferences dialog
-   Additoinal options
-   Audio / Video equalizers
-   Take screenshots

## Revision 1 (6. July 2008) ##

-   ASS Option
-   Fast libavcodec option