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
#import "EqualizerController.h"

#import "VideoOpenGLView.h"

#import "Preferences.h"
#import "CocoaAdditions.h"


@implementation MenuController

// -- Application Menu --------------------------------

- (IBAction) openPreferences:(NSMenuItem *)sender
{
	[[[appController preferencesController] window] makeKeyAndOrderFront:self];
}


// -- File Menu --------------------------------

- (IBAction) addToPlaylist:(NSMenuItem *)sender
{
	
}


// -- Playback Menu --------------------------------

- (IBAction) playPause:(NSMenuItem *)sender
{
	[[appController playerController] playPause:sender];
}

- (IBAction) stop:(NSMenuItem *)sender
{
	[[appController playerController] stop:self];
}

- (IBAction) toggleLoop:(NSMenuItem *)sender
{
	[[appController playerController] toggleLoop:sender];
}


- (IBAction) skipToNext:(NSMenuItem *)sender
{
	[[appController playerController] seekNext:sender];
}

- (IBAction) skipToPrevious:(NSMenuItem *)sender
{
	[[appController playerController] seekPrevious:sender];
}

- (IBAction) skipToChapterFromMenu:(NSMenuItem *)sender
{
	
}

- (IBAction) seekByTag:(NSMenuItem *)sender
{
	[[appController playerController] seekFromMenu:sender];
}

- (IBAction) stepFrame:(NSMenuItem *)sender
{
	[[appController playerController] stepFrame:sender];
}


- (IBAction) playlistPrevious:(NSMenuItem *)sender
{
	
}

- (IBAction) playlistNext:(NSMenuItem *)sender
{
	
}


- (IBAction) increaseVolume:(NSMenuItem *)sender
{
	[[appController playerController] increaseVolume:sender];
}

- (IBAction) decreaseVolume:(NSMenuItem *)sender
{
	[[appController playerController] decreaseVolume:sender];
}

- (IBAction) muteVolume:(NSMenuItem *)sender
{
	[[appController playerController] toggleMute:sender];
}


// -- Movie Menu --------------------------------

- (IBAction) setSizeFromMenu:(NSMenuItem *)sender
{
	[[[appController playerController] videoOpenGLView] setWindowSizeMode:WSM_SCALE 
																withValue:([sender tag]/100.0f)];
}

- (IBAction) fullScreen:(NSMenuItem *)sender
{
	[[appController playerController] switchFullscreen:sender];
}


- (IBAction) setVideoScaleMode:(NSMenuItem *)sender
{
	[[[appController playerController] videoOpenGLView] setVideoScaleMode:[sender tag]];
}

- (IBAction) originalAspect:(NSMenuItem *)sender
{
	[[[appController playerController] videoOpenGLView] setAspectRatio:0];
}

- (IBAction) setAspectFromMenu:(NSMenuItem *)sender
{
	float aspectValue;
	
	if (sender)
		aspectValue = [PreferencesController2 parseAspectRatio:[sender title]];
	else
		aspectValue = [[PREFS objectForKey:MPECustomAspectRatio] floatForKey:MPECustomAspectRatioValueKey];
	
	if (aspectValue <= 0) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Couldn't parse aspect menu item with title '%@'",[sender title]];
		return;
	}
	
	[[[appController playerController] videoOpenGLView] setAspectRatio:aspectValue];
}

- (IBAction) openCustomAspectChooser:(NSMenuItem *)sender
{
	[[[appController preferencesController] customAspectRatioChooser] makeKeyAndOrderFront:sender];
}


- (IBAction) takeScreenshot:(NSMenuItem *)sender
{
	[[appController playerController] takeScreenshot:sender];
}


// -- Window Menu --------------------------------

- (IBAction) openPlayerWindow:(NSMenuItem *)sender
{
	[[appController firstPlayerController] displayWindow:sender];
}

- (IBAction) togglePlaylistWindow:(NSMenuItem *)sender
{
	[[[appController firstPlayerController] playListController] displayWindow:sender];
}


- (IBAction) openVideoEqualizer:(NSMenuItem *)sender
{
	[[appController equalizerController] openVideoEqualizer];
}

- (IBAction) openAudioEqualizer:(NSMenuItem *)sender
{
	[[appController equalizerController] openAudioEqualizer];
}


- (IBAction) openInspector:(NSMenuItem *)sender
{
	[[[appController inspectorController] window] makeKeyAndOrderFront:self];
}

- (IBAction) openLog:(NSMenuItem *)sender
{
	[appController displayLogWindow:sender];
}


@end
