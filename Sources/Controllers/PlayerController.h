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

@class PlayListController, SettingsController, MenuController;

@interface PlayerController : NSObject
{
	// Shorthand to menu controller
	MenuController *menuController;
	
	// other controllers outlets
    IBOutlet PlayListController	*playListController;
	IBOutlet SettingsController *settingsController;
	
	//Player Window
	IBOutlet NSWindow *playerWindow;
	IBOutlet NSButton *playButton;
    IBOutlet id volumeSlider;
	IBOutlet id volumeButton;
	IBOutlet id scrubbingBar;
	IBOutlet id timeTextField;
	IBOutlet NSButton *playListButton;
	IBOutlet VideoOpenGLView *videoOpenGLView;
	IBOutlet id audioWindowMenu;
	IBOutlet id subtitleWindowMenu;
	IBOutlet id audioCycleButton;
	IBOutlet id subtitleCycleButton;
	IBOutlet id fullscreenButton;
	IBOutlet id chapterWindowMenu;
	IBOutlet id fullscreenWindowMenu;
	
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
	
	// properties
	MplayerInterface *myPlayer;
	MplayerInterface *myPreflightPlayer;
	
	// actual movie parametters
	MovieInfo *movieInfo;
	BOOL saveTime;
	BOOL continuousPlayback;
	BOOL playingFromPlaylist;
	int currentChapter;
	int videoStreamId;
	int audioStreamId;
	int subtitleDemuxStreamId;
	int subtitleFileStreamId;
	BOOL isSeeking;
	int lastPlayerStatus;
	
	// preferences
	int fullscreenDeviceId;
	BOOL fullscreenDeviceLocked;
	
	// volume
	float muteLastVolume;
	double lastVolumePoll;
	
	double lastChapterCheck;
	double seekUpdateBlockUntil;
	
	// images
	NSImage *playImageOff;
	NSImage *playImageOn;
	NSImage *pauseImageOff;
	NSImage *pauseImageOn;
	NSImage *fcPlayImageOff;
	NSImage *fcPlayImageOn;
	NSImage *fcPauseImageOff;
	NSImage *fcPauseImageOn;
		
	BOOL appleRemoteHolding;
	uint remoteHoldIncrement;
	
	IOPMAssertionID sleepAssertionId;
}

@property (nonatomic,readonly) PlayListController *playListController;
@property (nonatomic,readonly) SettingsController *settingsController;

@property (nonatomic,readonly) BOOL isFullscreen;
@property (nonatomic,readonly,getter=player) MplayerInterface* myPlayer;
@property (nonatomic,readonly) VideoOpenGLView* videoOpenGLView;

// interface
- (IBAction)displayWindow:(id)sender;
- (void) preflightItem:(MovieInfo *)anItem;
- (void) playItem:(MovieInfo *)anItem;
- (MovieInfo *) playingItem;
- (void) loadExternalSubtitleFile:(NSString *)path withEncoding:(NSString *)encoding;
- (BOOL) isRunning;
- (void) setOntop:(BOOL)aBool;
- (void) applySettings;
- (BOOL) changesRequireRestart;
- (void) applyChangesWithRestart:(BOOL)restart;
- (int) fullscreenDeviceId;
- (NSWindow *) playerWindow;

- (IBAction) togglePlaylist:(id)sender;
- (void) updatePlaylistButton:(NSNotification *)notification;
- (void) playFromPlaylist:(MovieInfo *)anItem;
- (void) stopFromPlaylist;

// misc
- (void) setMovieSize;
- (MplayerInterface *)playerInterface;
- (MplayerInterface *)preflightInterface;

// player control actions
- (IBAction)playPause:(id)sender;
- (IBAction)stepFrame:(id)sender;
- (void) seek:(float)seconds mode:(int)aMode;
- (BOOL) isSeeking;
- (float)getSeekSeconds;
- (IBAction)seekBack:(id)sender;
- (IBAction)seekFwd:(id)sender;
- (IBAction)seekPrevious:(id)sender;
- (IBAction)seekNext:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)seekFromMenu:(NSMenuItem *)item;
- (void)cleanUpAfterStop;
- (IBAction)switchFullscreen:(id)sender;
- (IBAction)displayStats:(id)sender;
- (IBAction)takeScreenshot:(id)sender;
- (void) setVolume:(double)volume;
- (double)volume;
- (void) applyVolume:(double)volume;
- (IBAction)toggleMute:(id)sender;
- (void) setLoopMovie:(BOOL)loop;
- (void) updateLoopStatus;
- (IBAction)changeVolume:(id)sender;
- (IBAction)increaseVolume:(id)sender;
- (IBAction)decreaseVolume:(id)sender;
- (IBAction)toggleLoop:(id)sender;
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
- (void) appShouldTerminate;
- (void) appTerminating;
- (void) statsClosed;
- (void) statusUpdate:(NSNotification *)notification;
- (void) statsUpdate:(NSNotification *)notification;
- (void) progresBarClicked:(NSNotification *)notification;
- (void) updatePlayerWindow;
- (void) updatePlaylistWindow;
- (void) updateFullscreenControls;
- (void) mplayerCrashed:(NSNotification *)notification;

// window delegate methods
- (BOOL)windowShouldZoom:(NSWindow *)sender toFrame:(NSRect)newFrame;
- (BOOL)windowShouldClose:(id)sender;
- (void)closeWindowNow:(id)sender;

@end
