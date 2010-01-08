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

@class PlayListController, MenuController;
@protocol MovieInfoProvider;

extern NSString* const MPEPlaybackStoppedNotification;

@interface PlayerController : NSObject <MplayerInterfaceClientProtocol, MovieInfoProvider>
{
	// Shorthand to menu controller
	MenuController *menuController;
	
	// other controllers outlets
    IBOutlet PlayListController	*playListController;
	
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
	IBOutlet FullscreenControls *fullScreenControls;
	
	// properties
	MplayerInterface *myPlayer;
	
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
		
	BOOL appleRemoteHolding;
	uint remoteHoldIncrement;
	
	IOPMAssertionID sleepAssertionId;
}

@property (nonatomic,readonly) PlayListController *playListController;

@property (nonatomic,readonly) BOOL isFullscreen;
@property (nonatomic,readonly,getter=player) MplayerInterface* myPlayer;
@property (nonatomic,readonly) VideoOpenGLView* videoOpenGLView;

@property (nonatomic,retain) MovieInfo *movieInfo;
@property (nonatomic,readonly) MovieInfo *currentMovieInfo;

// interface
- (IBAction)displayWindow:(id)sender;
- (void) playItem:(MovieInfo *)anItem;
- (void) playItem:(MovieInfo *)anItem fromPlaylist:(BOOL)fromPlaylist;
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
- (void) stopFromPlaylist;

// misc
- (void) setMovieSize;
- (MplayerInterface *)playerInterface;

// player control actions
- (IBAction)playPause:(id)sender;
- (IBAction)stepFrame:(id)sender;
- (void) seek:(float)seconds mode:(int)aMode;
- (float)getSeekSeconds;
- (IBAction)seekBack:(id)sender;
- (IBAction)seekFwd:(id)sender;
- (IBAction)seekPrevious:(id)sender;
- (IBAction)seekNext:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)seekFromMenu:(NSMenuItem *)item;
- (void)cleanUpAfterStop;
- (IBAction)switchFullscreen:(id)sender;
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
- (void)cycleAudioStreamsWithOSD:(BOOL)showOSD;
- (IBAction)cycleSubtitleStreams:(id)sender;
- (void)cycleSubtitleStreamsWithOSD:(BOOL)showOSD;
- (void)newVideoStreamId:(int)streamId;
- (void)newAudioStreamId:(int)streamId;
- (void)newSubtitleStreamId:(int)streamId forType:(SubtitleType)type;
- (void)disableMenuItemsInMenu:(NSMenu *)menu;

- (IBAction)cycleOSD:(id)sender;

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
- (void) progresBarClicked:(NSNotification *)notification;
- (void) updatePlayerWindow;
- (void) mplayerCrashed:(NSNotification *)notification;

// window delegate methods
- (BOOL)windowShouldZoom:(NSWindow *)sender toFrame:(NSRect)newFrame;
- (BOOL)windowShouldClose:(id)sender;
- (void)closeWindowNow:(id)sender;

@end
