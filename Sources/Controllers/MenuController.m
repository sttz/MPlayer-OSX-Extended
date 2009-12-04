//
//  MenuController.m
//  MPlayer OSX Extended
//
//  Created by Adrian on 04.12.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MenuController.h"

#import "AppController.h"
#import "PlayerController.h"
#import "PlayListController.h"
#import "PreferencesController2.h"
#import "SettingsController.h"
#import "EqualizerController.h"

#import "VideoOpenGLView.h"

@interface MenuController (Private)
- (void) referenceControllers;
@end


@implementation MenuController (Private)

- (void) referenceControllers
{
	appController = [AppController sharedController];
	playerController = [appController playerController];
	playListController = [appController playListController];
	preferencesController = [appController preferencesController];
	settingsController = [appController settingsController];
	equalizerController = [appController equalizerController];
}

@end


@implementation MenuController

- (void) awakeFromNib
{
	// register for app launch finish
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(referenceControllers)
												 name: NSApplicationDidFinishLaunchingNotification
											   object:NSApp];
}

// -- Application Menu --------------------------------

- (IBAction) openPreferences:(NSMenuItem *)sender
{
	
}


// -- File Menu --------------------------------

- (IBAction) addToPlaylist:(NSMenuItem *)sender
{
	
}


// -- Playback Menu --------------------------------

- (IBAction) playPause:(NSMenuItem *)sender
{
	[playerController playPause:sender];
}

- (IBAction) stop:(NSMenuItem *)sender
{
	[playerController stop:self];
}

- (IBAction) toggleLoop:(NSMenuItem *)sender
{
	[playerController toggleLoop:sender];
}


- (IBAction) skipToNext:(NSMenuItem *)sender
{
	[playerController seekNext:sender];
}

- (IBAction) skipToPrevious:(NSMenuItem *)sender
{
	[playerController seekPrevious:sender];
}

- (IBAction) skipToChapterFromMenu:(NSMenuItem *)sender
{
	
}

- (IBAction) seekByTag:(NSMenuItem *)sender
{
	[playerController seekFromMenu:sender];
}

- (IBAction) stepFrame:(NSMenuItem *)sender
{
	[playerController stepFrame:sender];
}


- (IBAction) playlistPrevious:(NSMenuItem *)sender
{
	
}

- (IBAction) playlistNext:(NSMenuItem *)sender
{
	
}


- (IBAction) increaseVolume:(NSMenuItem *)sender
{
	[playerController increaseVolume:sender];
}

- (IBAction) decreaseVolume:(NSMenuItem *)sender
{
	[playerController decreaseVolume:sender];
}

- (IBAction) muteVolume:(NSMenuItem *)sender
{
	[playerController toggleMute:sender];
}


// -- Movie Menu --------------------------------

- (IBAction) halfSize:(NSMenuItem *)sender
{
	[[playerController videoOpenGLView] MovieMenuAction:sender];
}

- (IBAction) normalSize:(NSMenuItem *)sender
{
	[[playerController videoOpenGLView] MovieMenuAction:sender];
}

- (IBAction) doubleSize:(NSMenuItem *)sender
{
	[[playerController videoOpenGLView] MovieMenuAction:sender];
}

- (IBAction) fullScreen:(NSMenuItem *)sender
{
	[[playerController videoOpenGLView] MovieMenuAction:sender];
}


- (IBAction) toggleKeepAspect:(NSMenuItem *)sender
{
	[[playerController videoOpenGLView] MovieMenuAction:sender];
}

- (IBAction) togglePanScan:(NSMenuItem *)sender
{
	[[playerController videoOpenGLView] MovieMenuAction:sender];
}

- (IBAction) originalAspect:(NSMenuItem *)sender
{
	[[playerController videoOpenGLView] MovieMenuAction:sender];
}

- (IBAction) setAspectFromMenu:(NSMenuItem *)sender
{
	[[playerController videoOpenGLView] setAspectRatioFromMenu:sender];
}

- (IBAction) openCustomAspectChooser:(NSMenuItem *)sender
{
	
}


- (IBAction) selectVideoStreamFromMenu:(NSMenuItem *)sender
{
	
}

- (IBAction) selectAudioStreamFromMenu:(NSMenuItem *)sender
{
	
}

- (IBAction) selectSubtitleStreamFromMenu:(NSMenuItem *)sender
{
	
}


- (IBAction) takeScreenshot:(NSMenuItem *)sender
{
	[playerController takeScreenshot:sender];
}


// -- Window Menu --------------------------------

- (IBAction) openPlayerWindow:(NSMenuItem *)sender
{
	
}

- (IBAction) togglePlaylistWindow:(NSMenuItem *)sender
{
	
}


- (IBAction) openVideoEqualizer:(NSMenuItem *)sender
{
	
}

- (IBAction) openAudioEqualizer:(NSMenuItem *)sender
{
	
}


- (IBAction) openStatisticsWindow:(NSMenuItem *)sender
{
	
}

- (IBAction) openInfoWindow:(NSMenuItem *)sender
{
	
}

- (IBAction) openLog:(NSMenuItem *)sender
{
	
}


@end
