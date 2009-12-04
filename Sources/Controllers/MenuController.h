//
//  MenuController.h
//  MPlayer OSX Extended
//
//  Created by Adrian on 04.12.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AppController, PlayerController, PlayListController, PreferencesController2,
SettingsController, EqualizerController;

@interface MenuController : NSObject {

@public
	// Playback Menu
	IBOutlet NSMenuItem* playMenuItem;
	IBOutlet NSMenuItem* loopMenuItem;
	
	IBOutlet NSMenuItem* chapterMenu;
	
	// Movie Menu
	IBOutlet NSMenuItem* fullscreenMenu;
	
	IBOutlet NSMenuItem* videoStreamMenu;
	IBOutlet NSMenuItem* audioStreamMenu;
	IBOutlet NSMenuItem* subtitleStreamMenu;
	
@private
	// Controller shorthands
	AppController *appController;
	PlayerController *playerController;
	PlayListController *playListController;
	PreferencesController2 *preferencesController;
	SettingsController *settingsController;
	EqualizerController *equalizerController;
}

// Application Menu
- (IBAction) openPreferences:(NSMenuItem *)sender;

// File Menu
- (IBAction) addToPlaylist:(NSMenuItem *)sender;

// Playback Menu
- (IBAction) playPause:(NSMenuItem *)sender;
- (IBAction) stop:(NSMenuItem *)sender;
- (IBAction) toggleLoop:(NSMenuItem *)sender;

- (IBAction) skipToNext:(NSMenuItem *)sender;
- (IBAction) skipToPrevious:(NSMenuItem *)sender;
- (IBAction) skipToChapterFromMenu:(NSMenuItem *)sender;
- (IBAction) seekByTag:(NSMenuItem *)sender;
- (IBAction) stepFrame:(NSMenuItem *)sender;

- (IBAction) playlistPrevious:(NSMenuItem *)sender;
- (IBAction) playlistNext:(NSMenuItem *)sender;

- (IBAction) increaseVolume:(NSMenuItem *)sender;
- (IBAction) decreaseVolume:(NSMenuItem *)sender;
- (IBAction) muteVolume:(NSMenuItem *)sender;

// Movie Menu
- (IBAction) halfSize:(NSMenuItem *)sender;
- (IBAction) normalSize:(NSMenuItem *)sender;
- (IBAction) doubleSize:(NSMenuItem *)sender;
- (IBAction) fullScreen:(NSMenuItem *)sender;

- (IBAction) toggleKeepAspect:(NSMenuItem *)sender;
- (IBAction) togglePanScan:(NSMenuItem *)sender;
- (IBAction) originalAspect:(NSMenuItem *)sender;
- (IBAction) setAspectFromMenu:(NSMenuItem *)sender;
- (IBAction) openCustomAspectChooser:(NSMenuItem *)sender;

- (IBAction) selectVideoStreamFromMenu:(NSMenuItem *)sender;
- (IBAction) selectAudioStreamFromMenu:(NSMenuItem *)sender;
- (IBAction) selectSubtitleStreamFromMenu:(NSMenuItem *)sender;

- (IBAction) takeScreenshot:(NSMenuItem *)sender;

// Window Menu
- (IBAction) openPlayerWindow:(NSMenuItem *)sender;
- (IBAction) togglePlaylistWindow:(NSMenuItem *)sender;

- (IBAction) openVideoEqualizer:(NSMenuItem *)sender;
- (IBAction) openAudioEqualizer:(NSMenuItem *)sender;

- (IBAction) openStatisticsWindow:(NSMenuItem *)sender;
- (IBAction) openInfoWindow:(NSMenuItem *)sender;
- (IBAction) openLog:(NSMenuItem *)sender;

@end
