/*
 *  PlayerCtrllr.h
 *  MPlayer OS X
 *
 *	Description:
 *		Controller for player controls, status box and statistics panel on side of UI
 *	and for MplayerInterface on side of data
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import <Cocoa/Cocoa.h>
#include <IOKit/pwr_mgt/IOPMLib.h>

#import "MplayerInterface.h"
#import "VideoOpenGLView.h"

#define		volumeStep				10.0

@interface PlayerController : NSObject
{
	// other controllers outlets
    IBOutlet PlayListController	*playListController;
	IBOutlet id settingsController;
	
	//Player Window
	IBOutlet NSWindow *playerWindow;
	IBOutlet NSButton *playButton;
	IBOutlet NSButton *playButtonToolbar;
    IBOutlet id volumeSlider;
	IBOutlet id volumeSliderToolbar;
	IBOutlet id volumeButton;
	IBOutlet id volumeButtonToolbar;
	IBOutlet id scrubbingBar;
	IBOutlet id scrubbingBarToolbar;
	IBOutlet id timeTextField;
	IBOutlet id timeTextFieldToolbar;
	IBOutlet id playListButton;
	IBOutlet VideoOpenGLView *videoOpenGLView;
	IBOutlet id audioWindowMenu;
	IBOutlet id subtitleWindowMenu;
	IBOutlet id toggleMuteMenu;
	IBOutlet id audioCycleButton;
	IBOutlet id subtitleCycleButton;
	IBOutlet id fullscreenButton;
	
	// Fullscreen controls
	IBOutlet id fcWindow;
	IBOutlet NSButton *fcPlayButton;
    IBOutlet id fcVolumeSlider;
	IBOutlet id fcScrubbingBar;
	IBOutlet id fcTimeTextField;
	IBOutlet id fcAudioCycleButton;
	IBOutlet id fcSubtitleCycleButton;
	IBOutlet id fcFullscreenButton;
	
	// statistics panel outlets
	IBOutlet id statsPanel;
    IBOutlet id statsAVsyncBox;
    IBOutlet id statsCacheUsageBox;
    IBOutlet id statsCPUUsageBox;
    IBOutlet id statsPostProcBox;
    IBOutlet id statsDroppedBox;
    IBOutlet id statsStatusBox;
	
	// stream menus
	IBOutlet id videoStreamMenu;
	IBOutlet id audioStreamMenu;
	IBOutlet id subtitleStreamMenu;
	
	// chapter menu
	IBOutlet id chapterMenu;
	IBOutlet id chapterWindowMenu;
	
	IBOutlet id fullscreenMenu;
	IBOutlet id fullscreenWindowMenu;
	
	// playback menu
	IBOutlet id playMenuItem;
	IBOutlet id stopMenuItem;
	IBOutlet id skipEndMenuItem;
	IBOutlet id skipBeginningMenuItem;
	
	// properties
	MplayerInterface *myPlayer;
	MplayerInterface *myPreflightPlayer;
	
	// paths to mplayer binaries
	NSString *mplayerPath;
	NSString *mplayerMTPath;
	
	// actual movie parametters
	NSMutableDictionary *myPlayingItem;
	MovieInfo *movieInfo;
	BOOL saveTime;
	int playerStatus;
	unsigned movieSeconds;		// stores actual movie seconds for further use
	BOOL  fullscreenStatus;
	BOOL isOntop;
	BOOL continuousPlayback;
	BOOL playingFromPlaylist;
	int currentChapter;
	int videoStreamId;
	int audioStreamId;
	int subtitleDemuxStreamId;
	int subtitleFileStreamId;
	BOOL isSeeking;
	
	// preferences
	int fullscreenDeviceId;
	BOOL fullscreenDeviceLocked;
	
	// volume
	float muteLastVolume;
	double lastVolumePoll;
	
	double lastChapterCheck;
	
	// images
	NSImage *playImageOff;
	NSImage *playImageOn;
	NSImage *pauseImageOff;
	NSImage *pauseImageOn;
	NSImage *fcPlayImageOff;
	NSImage *fcPlayImageOn;
	NSImage *fcPauseImageOff;
	NSImage *fcPauseImageOn;
	
	NSRect org_frame;
	
	BOOL appleRemoteHolding;
	uint remoteHoldIncrement;
	
	IOPMAssertionID sleepAssertionId;
}

// interface
- (IBAction)displayWindow:(id)sender;
- (void) preflightItem:(NSMutableDictionary *)anItem;
- (void) playItem:(NSMutableDictionary *)anItem;
- (NSMutableDictionary *) playingItem;
- (BOOL) isRunning;
- (BOOL) isPlaying;
- (BOOL) isInternalVideoOutput;
- (void) setOntop:(BOOL)aBool;
- (BOOL) isOntop;
- (void) applyPrefs;
- (void) applySettings;
- (BOOL) changesRequireRestart;
- (BOOL) movieIsSeekable;
- (void) applyChangesWithRestart:(BOOL)restart;
- (BOOL) startInFullscreen;
- (int) fullscreenDeviceId;
- (NSWindow *) playerWindow;

- (void) playFromPlaylist:(NSMutableDictionary *)anItem;
- (void) stopFromPlaylist;

// misc
- (void) setMovieSize;
- (void) setSubtitlesEncoding;
- (void) setVideoEqualizer;
- (NSNumber *) gammaValue:(NSNumber *)input;
- (MplayerInterface *)playerInterface;
- (MplayerInterface *)preflightInterface;
- (void) chooseMPlayerBinary;

// player control actions
- (IBAction)playPause:(id)sender;
- (void) seek:(float)seconds mode:(int)aMode;
- (BOOL) isSeeking;
- (float)getSeekSeconds;
- (IBAction)seekBack:(id)sender;
- (IBAction)seekFwd:(id)sender;
- (IBAction)seekPrevious:(id)sender;
- (IBAction)seekNext:(id)sender;
- (IBAction)stop:(id)sender;
- (void)cleanUpAfterStop;
- (IBAction)switchFullscreen:(id)sender;
- (IBAction)displayStats:(id)sender;
- (IBAction)takeScreenshot:(id)sender;
- (void) setVolume:(double)volume;
- (double)volume;
- (void) applyVolume:(double)volume;
- (IBAction)toggleMute:(id)sender;
- (IBAction)changeVolume:(id)sender;
- (IBAction)increaseVolume:(id)sender;
- (IBAction)decreaseVolume:(id)sender;
- (void)sendKeyEvent:(int)event;

- (void)goToChapter:(unsigned int)chapter;
- (void)skipToNextChapter;
- (void)skipToPreviousChapter;

- (void)clearStreamMenus;
- (void)fillStreamMenus;
- (void)videoMenuAction:(id)sender;
- (void)audioMenuAction:(id)sender;
- (void)subtitleMenuAction:(id)sender;
- (IBAction)cycleAudioStreams:(id)sender;
- (IBAction)cycleSubtitleStreams:(id)sender;
- (void)newVideoStreamId:(int)streamId;
- (void)newAudioStreamId:(int)streamId;
- (void)newSubtitleStreamId:(int)streamId forType:(SubtitleType)type;
- (void)disableMenuItemsInMenu:(NSMenu *)menu;

- (void)clearChapterMenu;
- (void)fillChapterMenu;
- (void)chapterMenuAction:(id)sender;
- (void)selectChapterForTime:(float)seconds;

- (void)clearFullscreenMenu;
- (void)fillFullscreenMenu;
- (void)fullscreenMenuAction:(id)sender;
- (void)selectFullscreenDevice;
- (void)menuWillOpen:(NSMenu *)menu;

// notification observers
- (void) appWillFinishLaunching;
- (void) appFinishedLaunching;
- (void) appShouldTerminate;
- (void) appTerminating;
- (void) playbackStarted;
- (void) statsClosed;
- (void) statusUpdate:(NSNotification *)notification;
- (void) statsUpdate:(NSNotification *)notification;
- (void) progresBarClicked:(NSNotification *)notification;
- (void) updatePlayerWindow;
- (void) updatePlaylistWindow;
- (void) updateFullscreenControls;
- (void) disableFFmpegMTForCurrentFile;

// window delegate methods
- (BOOL)windowShouldZoom:(NSWindow *)sender toFrame:(NSRect)newFrame;
- (BOOL)windowShouldClose:(id)sender;
- (void)closeWindowNow:(id)sender;

@end
