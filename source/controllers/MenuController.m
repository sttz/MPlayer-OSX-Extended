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
	[[appController activePlayer] playPause:sender];
}

- (IBAction) stop:(NSMenuItem *)sender
{
	[[appController activePlayer] stop:self];
}

- (IBAction) toggleLoop:(NSMenuItem *)sender
{
	[[appController activePlayer] toggleLoop:sender];
}


- (IBAction) skipToNext:(NSMenuItem *)sender
{
	[[appController activePlayer] seekNext:sender];
}

- (IBAction) skipToPrevious:(NSMenuItem *)sender
{
	[[appController activePlayer] seekPrevious:sender];
}

- (IBAction) skipToChapterFromMenu:(NSMenuItem *)sender
{
	
}

- (IBAction) seekByTag:(NSMenuItem *)sender
{
	[[appController activePlayer] seekFromMenu:sender];
}

- (IBAction) stepFrame:(NSMenuItem *)sender
{
	[[appController activePlayer] stepFrame:sender];
}


- (IBAction) playlistPrevious:(NSMenuItem *)sender
{
	
}

- (IBAction) playlistNext:(NSMenuItem *)sender
{
	
}


- (IBAction) increaseVolume:(NSMenuItem *)sender
{
	[[appController activePlayer] increaseVolume:sender];
}

- (IBAction) decreaseVolume:(NSMenuItem *)sender
{
	[[appController activePlayer] decreaseVolume:sender];
}

- (IBAction) muteVolume:(NSMenuItem *)sender
{
	[[appController activePlayer] toggleMute:sender];
}


// -- Movie Menu --------------------------------

- (IBAction) setSizeFromMenu:(NSMenuItem *)sender
{
	[[[appController activePlayer] videoOpenGLView] setWindowSizeMode:WSM_SCALE 
																withValue:([sender tag]/100.0f)];
}

- (IBAction) fitScreen:(NSMenuItem *) sender
{
    [[[appController activePlayer] videoOpenGLView] setWindowSizeMode:WSM_FIT_SCREEN 
																withValue:1];
}

- (IBAction) fullScreen:(NSMenuItem *)sender
{
	[[appController activePlayer] switchFullscreen:sender];
}


- (IBAction) setVideoScaleMode:(NSMenuItem *)sender
{
	[[[appController activePlayer] videoOpenGLView] setVideoScaleMode:[sender tag]];
}

- (IBAction) originalAspect:(NSMenuItem *)sender
{
	[[[appController activePlayer] videoOpenGLView] setAspectRatio:0];
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
	
	[[[appController activePlayer] videoOpenGLView] setAspectRatio:aspectValue];
}

- (IBAction) openCustomAspectChooser:(NSMenuItem *)sender
{
	[[[appController preferencesController] customAspectRatioChooser] makeKeyAndOrderFront:sender];
}


- (IBAction) takeScreenshot:(NSMenuItem *)sender
{
	[[appController activePlayer] takeScreenshot:sender];
}


// -- Window Menu --------------------------------

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
