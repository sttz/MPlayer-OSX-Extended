//
//  MenuController.h
//  MPlayer OSX Extended
//
//  Created by Adrian on 04.12.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AppController, PlayerController, PlayListController, PreferencesController2,
EqualizerController;

@interface MenuController : NSObject {

@public
	// Playback Menu
	IBOutlet NSMenuItem* playMenuItem;
	IBOutlet NSMenuItem* loopMenuItem;
	
	IBOutlet NSMenuItem* chapterMenu;
	
	IBOutlet NSMenuItem* toggleMuteMenuItem;
	
	// Movie Menu
	IBOutlet NSMenuItem* fullscreenMenu;
	
	IBOutlet NSMenuItem* zoomToFitMenuItem;
	IBOutlet NSMenuItem* zoomToFillMenuItem;
	IBOutlet NSMenuItem* stretchToFillMenuItem;
	
	IBOutlet NSMenuItem* videoStreamMenu;
	IBOutlet NSMenuItem* audioStreamMenu;
	IBOutlet NSMenuItem* subtitleStreamMenu;
	
@private
	IBOutlet AppController *appController;
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
- (IBAction) setSizeFromMenu:(NSMenuItem *)sender;
- (IBAction) fullScreen:(NSMenuItem *)sender;

- (IBAction) setVideoScaleMode:(NSMenuItem *)sender;
- (IBAction) originalAspect:(NSMenuItem *)sender;
- (IBAction) setAspectFromMenu:(NSMenuItem *)sender;
- (IBAction) openCustomAspectChooser:(NSMenuItem *)sender;

- (IBAction) takeScreenshot:(NSMenuItem *)sender;

// Window Menu
- (IBAction) openPlayerWindow:(NSMenuItem *)sender;
- (IBAction) togglePlaylistWindow:(NSMenuItem *)sender;

- (IBAction) openVideoEqualizer:(NSMenuItem *)sender;
- (IBAction) openAudioEqualizer:(NSMenuItem *)sender;

- (IBAction) openInspector:(NSMenuItem *)sender;
- (IBAction) openLog:(NSMenuItem *)sender;

@end
