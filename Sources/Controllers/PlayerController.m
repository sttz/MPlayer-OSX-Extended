/*
 *  PlayerCtrllr.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "PlayerController.h"

// other controllers
#import "MenuController.h"
#import "AppController.h"
#import "PlayListController.h"
#import "PreferencesController2.h"

#import "Preferences.h"
#import "CocoaAdditions.h"

// custom classes
#import "VideoOpenGLView.h"
#import "VolumeSlider.h"
#import "ScrubbingBar.h"

#if __MAC_OS_X_VERSION_MIN_REQUIRED <= __MAC_OS_X_VERSION_10_5
// used for preventing screensaver on leopard
#import <CoreServices/CoreServices.h>
// not very nice hack to get to the header on 64bit builds
#ifdef __LP64__
#import <CoreServices/../Frameworks/OSServices.framework/Headers/Power.h>
#endif
#endif

#include <sys/types.h>
#include <sys/sysctl.h>

#include "AppleRemote.h"

#define		MP_CHAPTER_CHECK_INTERVAL	0.5f
#define		MP_SEEK_UPDATE_BLOCK		0.5f

NSString* const MPEPlaybackStoppedNotification = @"MPEPlaybackStoppedNotification";

@implementation PlayerController
@synthesize myPlayer, playListController, videoOpenGLView, movieInfo;

/************************************************************************************/
-(id)init
{
	if (!(self = [super init]))
		return nil;
	
	// Initialize some variables
	saveTime = YES;
	lastChapterCheck = -MP_CHAPTER_CHECK_INTERVAL;
	
	// fullscreen device defaults to automatic
	fullscreenDeviceId = -2;
	
	// streams default to unselected
	videoStreamId = -1;
	audioStreamId = -1;
	subtitleDemuxStreamId = -1;
	subtitleFileStreamId = -1;
	
	// load images
	playImageOn = [[NSImage imageNamed:@"play_button_on"] retain];
	playImageOff = [[NSImage imageNamed:@"play_button_off"] retain];
	pauseImageOn = [[NSImage imageNamed:@"pause_button_on"] retain];
	pauseImageOff = [[NSImage imageNamed:@"pause_button_off"] retain];
	
	// Save reference to menu controller
	menuController = [[AppController sharedController] menuController];
	
	// Load MPlayer interface
	myPlayer = [MplayerInterface new];
	
	[myPlayer addClient:self];
	
	// register for MPlayer crash
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(mplayerCrashed:)
			name: @"MIMplayerExitedAbnormally"
			object: myPlayer];
	
	// register for app pre termination notification
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appShouldTerminate)
			name: @"ApplicationShouldTerminateNotification"
			object:NSApp];
	
	// request notification for changes to monitor configuration
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(screensDidChange)
			name:NSApplicationDidChangeScreenParametersNotification
			object:NSApp];
	
	// register for ontop changes
	[PREFS addObserver:self
			forKeyPath:MPEWindowOnTopMode
			   options:NSKeyValueObservingOptionInitial
			   context:nil];
	
	return self;
}

-(void)awakeFromNib
{	
    // Make sure we don't initialize twice
	if (playListController)
		return;
	
	// resize window
	//[playerWindow setContentMinSize:NSMakeSize(450, 78)]; // Temp workaround for IB always forgetting the min-size
	[playerWindow setContentSize:[playerWindow contentMinSize]];
	[playerWindow makeFirstResponder:playerWindow];
	
	// register for notification on clicking progress bar
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(progresBarClicked:)
			name: @"SBBarClickedNotification"
			object:scrubbingBar];
	
	// set mute status and reload unmuted volume
	if ([PREFS objectForKey:MPEAudioVolume] && [PREFS boolForKey:MPEAudioMute]) {
		[self setVolume:0];
		muteLastVolume = [PREFS floatForKey:MPEAudioVolume];
	// set volume to the last used value
	} else if ([PREFS objectForKey:MPEAudioVolume])
		[self setVolume:[[PREFS objectForKey:MPEAudioVolume] floatValue]];
	else
		[self setVolume:25];
		
	//setup drag & drop
	[playerWindow registerForDraggedTypes:[NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
	
	// fill fullscreen device menu
	[self fillFullscreenMenu];
	[self selectFullscreenDevice];
	
	// Pass buffer name to interface
	[myPlayer setBufferName:[videoOpenGLView bufferName]];
	
	// Load playlist controller
	[NSBundle loadNibNamed:@"Playlist" owner:self];
	[self updatePlaylistButton:nil];
	
	// Keep track if playlist window is open
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updatePlaylistButton:)
												 name:NSWindowDidBecomeKeyNotification
											   object:[playListController window]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updatePlaylistButton:)
												 name:NSWindowWillCloseNotification
											   object:[playListController window]];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	NSSet *affectingKeys = nil;
	
	if ([key isEqualToString:@"currentMovieInfo"])
		affectingKeys = [NSSet setWithObjects:@"movieInfo",nil];
	
	if (affectingKeys)
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	
	return keyPaths;
}

- (void) dealloc
{
	[myPlayer release];
	
	[movieInfo release];
	
	[playImageOn release];
	[playImageOff release];
	[pauseImageOn release];
	[pauseImageOff release];
	
	[super dealloc];
}

/************************************************************************************
 DRAG & DROP
 ************************************************************************************/
 
 /*
	Validate Drop Opperation on player window
 */
- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	int i;
	NSPasteboard *pboard;
	NSArray *fileArray;
	NSArray *propertyList;
	NSString *availableType;

	pboard = [sender draggingPasteboard];	
	//paste board contain filename?
	if ( [[pboard types] containsObject:NSFilenamesPboardType] )
	{	
		//get dragged file array
		fileArray = [pboard propertyListForType:@"NSFilenamesPboardType"];
		if(fileArray)
		{
			//we are only dropping one item.
			if([fileArray count] == 1)
			{
				//look in property list for know file type
				availableType=[pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
				propertyList = [pboard propertyListForType:availableType];
				for (i=0;i<[propertyList count];i++)
				{
					if ([[AppController sharedController] 
							isExtension:[[propertyList objectAtIndex:i] pathExtension] 
								 ofType:MP_DIALOG_MEDIA])
						return NSDragOperationCopy; //its a movie file, good
					
					if ([self isRunning] && [[AppController sharedController] 
												isExtension:[[propertyList objectAtIndex:i] pathExtension] 
													 ofType:MP_DIALOG_SUBTITLES])
						return NSDragOperationCopy; // subtitles are good when playing
					
					// let the choice be overridden with the command key
					if ([sender draggingSourceOperationMask] == NSDragOperationGeneric)
						return NSDragOperationCopy;
				}
				return NSDragOperationNone; //no know object found, cancel drop.
			}
			else
			{
				return NSDragOperationNone; //more than one item selected for drop.
			}
		}
    }
		
    return NSDragOperationNone;
}

 /*
	Perform Drop Opperation on player window
 */
- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard;
	NSArray *fileArray;
	NSString *filename;

	pboard = [sender draggingPasteboard];

	//drop contain filename type
	if ( [[pboard types] containsObject:NSFilenamesPboardType] )
	{		
		//get file array, should contain 1 item since this is verified in (draggingEntered).
		fileArray = [pboard propertyListForType:@"NSFilenamesPboardType"];
		if(fileArray)
		{
			filename = [fileArray objectAtIndex:0];
			if (filename)
			{
				// Open if a media file or if forced with the command key
				if ([sender draggingSourceOperationMask] == NSDragOperationGeneric || 
						[[AppController sharedController] isExtension:[filename pathExtension] ofType:MP_DIALOG_MEDIA]) {
					// create an item from it and play it
					MovieInfo *item = [MovieInfo movieInfoWithPathToFile:filename];
					[self playItem:item];
				} else if (movieInfo) {
					// load subtitles file
					[movieInfo addExternalSubtitle:filename];
				}
			}
		}
    }
	
	return YES;
}

/************************************************************************************
 INTERFACE
 ************************************************************************************/
- (void) mplayerCrashed:(NSNotification *)notification
{
	NSAlert *alert = [NSAlert alertWithMessageText:@"Playback Error"
									 defaultButton:@"Abort"
								   alternateButton:@"Restart"
									   otherButton:@"Open Log" 
						 informativeTextWithFormat:@"Abnormal playback termination. Check log file for more information."];
	[alert setAccessoryView:[[[AppController sharedController] preferencesController] binarySelectionView]];
	
	NSInteger answer = [alert runModal];
	
	// Open Log file
	if (answer == NSAlertOtherReturn) {
		[[AppController sharedController] displayLogWindow:self];
	
	// Restart playback
	} else if (answer == NSAlertAlternateReturn) {
		
		NSString *binary = [[[AppController sharedController] preferencesController] identifierFromSelectionInView];
		if (binary)
			[[movieInfo prefs] setObject:binary forKey:MPESelectedBinary];
		// Restart playback
		[self playItem:movieInfo];
	}
}
/************************************************************************************/
- (IBAction)displayWindow:(id)sender;
{
		[playerWindow makeKeyAndOrderFront:nil];
}
/************************************************************************************/
- (void)playItem:(MovieInfo *)anItem
{
	[self playItem:anItem fromPlaylist:NO];
}

/************************************************************************************/
- (void)playItem:(MovieInfo *)anItem fromPlaylist:(BOOL)fromPlaylist
{
	playingFromPlaylist = fromPlaylist;
	
	// re-open player window for internal video
	if (![videoOpenGLView isFullscreen] && ![playerWindow isVisible])
		[self displayWindow:self];
	
	// prepare player
	// stops mplayer if it is running
	if (!([myPlayer stateMask] & MIStateStoppedMask)) {
		continuousPlayback = YES;	// don't close view
		saveTime = NO;		// don't save time
	}
	if ([myPlayer isRunning])
		[myPlayer stop];
		
	if (![anItem fileIsValid]) {
		NSRunAlertPanel(NSLocalizedString(@"Error",nil), [NSString stringWithFormat:
				NSLocalizedString(@"File or URL %@ could not be found.",nil), [anItem filename]],
				NSLocalizedString(@"OK",nil),nil,nil);
		return;
	}
	
	if (movieInfo || movieInfo != anItem) {
		// switch movie info (take care of unregistering and registering the player instance)
		[movieInfo setPlayer:nil];
		[self setMovieInfo:anItem];
		[anItem setPlayer:self];
		// set self as movie info provider if key window
		if ([playerWindow isKeyWindow] && [[AppController sharedController] movieInfoProvider] != self)
			[[AppController sharedController] setMovieInfoProvider:self];
	}
	
	// Apply local volume
	[[movieInfo prefs] setBool:([self volume] == 0) forKey:MPEAudioMute];
	[[movieInfo prefs] setFloat:[self volume] forKey:MPEAudioVolume];
	
	// set video size for case it is set to fit screen so we have to compare
	// screen size with movie size
	[self setMovieSize];
	
	// start playback
	[myPlayer playItem:movieInfo];
	
	[playListController updateView];
	
	// add item to recent menu
	NSURL *fileURL = [NSURL fileURLWithPath:[movieInfo filename]];
	if (fileURL)
		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:fileURL];
}

/************************************************************************************/
- (IBAction) togglePlaylist:(id)sender
{
	[playListController toggleWindow:self];
}

- (void) updatePlaylistButton:(NSNotification *)notification
{
	[playListButton setState:[[playListController window] isVisible]];
}

/************************************************************************************/
- (void) stopFromPlaylist
{
	[self stop:nil];
	playingFromPlaylist = NO;
	[self cleanUpAfterStop];
}

/************************************************************************************/
- (void) loadExternalSubtitleFile:(NSString *)path withEncoding:(NSString *)encoding
{
	if (movieInfo) {
		
		[movieInfo addExternalSubtitle:path];
		
		if (encoding)
			[[movieInfo prefs] setObject:encoding forKey:MPETextEncoding];
		
		if ([myPlayer localChangesNeedRestart])
			[self applyChangesWithRestart:YES];
	}
}

/************************************************************************************/
- (MplayerInterface *)playerInterface
{
	return myPlayer;
}
/************************************************************************************/
- (MovieInfo *) playingItem
{
	if ([myPlayer isRunning])
		return [[movieInfo retain] autorelease]; // get it's own retention
	else
		return nil;
}

- (MovieInfo *) currentMovieInfo
{
	return [[movieInfo retain] autorelease];
}

/************************************************************************************/
- (BOOL) isRunning
{	return [myPlayer isRunning];		}
/************************************************************************************/
- (BOOL) changesRequireRestart
{
	if ([myPlayer isRunning])
		return [myPlayer changesNeedRestart];
	return NO;
}
/************************************************************************************/
- (void) applyChangesWithRestart:(BOOL)restart
{
	continuousPlayback = YES;
	[myPlayer applySettingsWithRestart];
	
	// set streams
	if (videoStreamId >= 0)
		[myPlayer sendCommand:[NSString stringWithFormat:@"set_property switch_video %i",videoStreamId]];
	if (audioStreamId >= 0)
		[myPlayer sendCommand:[NSString stringWithFormat:@"set_property switch_audio %i",audioStreamId]];
	if (subtitleDemuxStreamId >= 0)
		[myPlayer sendCommand:[NSString stringWithFormat:@"set_property sub_demux %i",subtitleDemuxStreamId]];
	if (subtitleFileStreamId >= 0)
		[myPlayer sendCommand:[NSString stringWithFormat:@"set_property sub_file %i",subtitleFileStreamId]];
}

/************************************************************************************
 MISC
 ************************************************************************************/
- (void) setMovieSize
{
	if ([PREFS integerForKey:MPEDisplaySize] == MPEDisplaySizeHalf)
		[videoOpenGLView setWindowSizeMode:WSM_SCALE withValue:0.5];
	
	else if ([PREFS integerForKey:MPEDisplaySize] == MPEDisplaySizeOriginal)
		[videoOpenGLView setWindowSizeMode:WSM_SCALE withValue:1];
	
	else if ([PREFS integerForKey:MPEDisplaySize] == MPEDisplaySizeDouble)
		[videoOpenGLView setWindowSizeMode:WSM_SCALE withValue:2];
	
	else if ([PREFS integerForKey:MPEDisplaySize] == MPEDisplaySizeFitScreen)
		[videoOpenGLView setWindowSizeMode:WSM_FIT_SCREEN withValue:0];
	
	else if ([PREFS integerForKey:MPEDisplaySize] == MPEDisplaySizeCustom
			 && [PREFS integerForKey:MPECustomSizeInPx] > 0) {
		[videoOpenGLView setWindowSizeMode:WSM_FIT_WIDTH withValue:[PREFS floatForKey:MPECustomSizeInPx]];
	
	} else
		[videoOpenGLView setWindowSizeMode:WSM_SCALE withValue:1];
}
/************************************************************************************
 ACTIONS
 ************************************************************************************/
// Apply volume and send it to mplayer
- (void) setVolume:(double)volume
{
	
	volume = fmin(fmax(volume,0.0),100.0);
	
	[self applyVolume:volume];
	
	BOOL isMute = (volume == 0);
	
	[myPlayer setVolume:volume isMuted:isMute];
	
	if (volume > 0 && volume != [PREFS floatForKey:MPEAudioVolume])
		[PREFS setFloat:volume forKey:MPEAudioVolume];
	if (isMute != [PREFS boolForKey:MPEAudioMute])
		[PREFS setBool:isMute forKey:MPEAudioMute];
}

- (double)volume
{
	return [volumeSlider doubleValue];
}

// Apply volume to images and sliders (don't send it to mplayer)
- (void) applyVolume:(double)volume
{
	NSImage *volumeImage;
		
	//set volume icon
	if (volume == 0)
		volumeImage = [NSImage imageNamed:@"volume0"];
	
	 else if (volume > 66)
		volumeImage = [NSImage imageNamed:@"volume3"];
	
	else if (volume > 33 && volume < 67)
		volumeImage = [NSImage imageNamed:@"volume2"];
	
	else
		volumeImage = [NSImage imageNamed:@"volume1"];
	
	
	[volumeSlider setDoubleValue:volume];
	[volumeButton setImage:volumeImage];
	[volumeButton setNeedsDisplay:YES];
	
	[menuController->toggleMuteMenuItem setState:(volume == 0)];
}

// Volume change action from sliders
- (IBAction)changeVolume:(id)sender
{
	[self setVolume:[sender doubleValue]];
}

// Volume change from menus
- (IBAction)increaseVolume:(id)sender
{
	
	double newVolume = [PREFS floatForKey:MPEAudioVolume] + [PREFS floatForKey:MPEVolumeStepSize];
	if (newVolume > 100)
		newVolume = 100;
		
	[self setVolume:newVolume];
}

- (IBAction)decreaseVolume:(id)sender
{
	
	double newVolume = [PREFS floatForKey:MPEAudioVolume] - [PREFS floatForKey:MPEVolumeStepSize];
	if (newVolume < 0)
		newVolume = 0;
	
	[self setVolume:newVolume];
}

// Toggle mute action from buttons
- (IBAction)toggleMute:(id)sender
{
	
	if ([volumeSlider doubleValue] == 0) {
		
		[self setVolume:muteLastVolume];
		
	} else {
		
		muteLastVolume = [volumeSlider doubleValue];
		[self setVolume:0];
	}
}

/************************************************************************************/
- (IBAction)playPause:(id)sender
{
	if ([myPlayer state] > MIStateStopped) {
		[myPlayer pause];				// if playing pause/unpause
		
	}
	else 
	{
		// set the item to play
		if ([playListController indexOfSelectedItem] < 0)
			[playListController selectItemAtIndex:0];
		
		// play the items
		[self playItem:(MovieInfo *)[playListController selectedItem]];
	}
	[playListController updateView];
}

/************************************************************************************/
- (IBAction)stepFrame:(id)sender
{
	[myPlayer sendCommand:@"frame_step"];
}

/************************************************************************************/
- (void) setLoopMovie:(BOOL)loop
{
	if (loop != [[movieInfo prefs] boolForKey:MPELoopMovie])
		[[movieInfo prefs] setBool:loop forKey:MPELoopMovie];
}

- (IBAction)toggleLoop:(id)sender
{
	if (movieInfo)
		[self setLoopMovie:(![[movieInfo prefs] boolForKey:MPELoopMovie])];
	[self updateLoopStatus];
}

- (void) updateLoopStatus
{
	if (movieInfo && [[movieInfo prefs] boolForKey:MPELoopMovie])
		[menuController->loopMenuItem setState:NSOnState];
	else
		[menuController->loopMenuItem setState:NSOffState];
}

/************************************************************************************/
- (void) seek:(float)seconds mode:(int)aMode
{
	// Tell MPlayer to seek
	[myPlayer seek:seconds mode:aMode];
	// Force recheck of chapters
	lastChapterCheck = -MP_CHAPTER_CHECK_INTERVAL;
	// Unblock for the next update
	seekUpdateBlockUntil = 0;
	// Optimist time update
	[self interface:nil timeUpdate:nil];
	// Block time updates to not update with values before the seek
	seekUpdateBlockUntil = [NSDate timeIntervalSinceReferenceDate] + MP_SEEK_UPDATE_BLOCK;
}

- (float)getSeekSeconds
{
	float seconds = [PREFS floatForKey:MPESeekStepMedium];
	if ([NSApp currentEvent]) {
		if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) {
			seconds = [PREFS floatForKey:MPESeekStepLarge];
		} else if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) {
			seconds = [PREFS floatForKey:MPESeekStepSmall];
		}
	}
	return seconds;
}

- (IBAction)seekBack:(id)sender
{
	
	if ([myPlayer isRunning])
		[self seek:-[self getSeekSeconds] mode:MISeekingModeRelative];
	else {
		if ([playListController indexOfSelectedItem] < 1)
			[playListController selectItemAtIndex:0];
		else
			[playListController selectItemAtIndex:
					([playListController indexOfSelectedItem]-1)];
	}
	
	[playListController updateView];
}

- (IBAction)seekFwd:(id)sender
{
	if ([myPlayer isRunning])
		[self seek:[self getSeekSeconds] mode:MISeekingModeRelative];
	else {
		if ([playListController indexOfSelectedItem] < ([playListController itemCount]-1))
			[playListController selectItemAtIndex:
					([playListController indexOfSelectedItem]+1)];
		else
			[playListController selectItemAtIndex:([playListController itemCount]-1)];
	}
	[playListController updateView];
}

- (IBAction)seekFromMenu:(NSMenuItem *)item
{
	float seconds;
	int sign = ([item tag] >= 0) ? 1 : -1;
	if (abs([item tag]) == 1)
		seconds = [PREFS floatForKey:MPESeekStepSmall] * sign;
	else if (abs([item tag]) == 2)
		seconds = [PREFS floatForKey:MPESeekStepMedium] * sign;
	else
		seconds = [PREFS floatForKey:MPESeekStepLarge] * sign;
		
	[self seek:seconds mode:MISeekingModeRelative];
}

/************************************************************************************/
- (IBAction)seekNext:(id)sender
{
	if ([myPlayer isRunning])
	{
		if (movieInfo && [movieInfo chapterCount] > 0)
			[self skipToNextChapter];
		else {
			if (playingFromPlaylist)
				[playListController finishedPlayingItem:movieInfo];
			else
				[self stop:nil];
			//[self seek:100 mode:MISeekingModePercent];
		}
	}
}

- (IBAction)seekPrevious:(id)sender
{
	if ([myPlayer isRunning])
	{
		if (movieInfo && [movieInfo chapterCount] > 0)
			[self skipToPreviousChapter];
		else
			[self seek:0 mode:MISeekingModePercent];
	}
}

/************************************************************************************/
- (void)skipToNextChapter {
	
	if ([myPlayer isRunning] && movieInfo && [movieInfo chapterCount] >= (currentChapter+1))
		[self goToChapter:(currentChapter+1)];
	else {
		if (playingFromPlaylist)
			[playListController finishedPlayingItem:movieInfo];
		else
			[self stop:nil];
		//[self seek:100 mode:MISeekingModePercent];
	}
}

- (void)skipToPreviousChapter {
	
	if ([myPlayer isRunning] && movieInfo && [movieInfo chapterCount] > 0 && currentChapter > 1)
		[self goToChapter:(currentChapter-1)];
	else
		[self seek:0 mode:MISeekingModePercent];
}

- (void)goToChapter:(unsigned int)chapter {
	
	// only if playing
	if ([myPlayer isRunning]) {
		
		currentChapter = chapter;
		[myPlayer sendCommand:[NSString stringWithFormat:@"set_property chapter %d 1", currentChapter] 
					  withOSD:MISurpressCommandOutputConditionally andPausing:MICommandPausingKeep];
		lastChapterCheck = -MP_CHAPTER_CHECK_INTERVAL; // force update of chapter menu
	}
}

/************************************************************************************/
- (IBAction)stop:(id)sender
{
	
	saveTime = NO;		// if user stops player, don't save time
	
	[myPlayer stop];
		
	[playListController updateView];
}

/************************************************************************************/
- (void)cleanUpAfterStop {
	
	[videoOpenGLView close];
	[self clearStreamMenus];
	[self clearChapterMenu];
}
/************************************************************************************/
- (void) executeHoldActionForRemoteButton:(NSNumber*)buttonIdentifierNumber
{
    if(appleRemoteHolding)
    {
        switch([buttonIdentifierNumber intValue])
        {
			// Right: Seek forward
			case kRemoteButtonRight_Hold:
				[self seek:10*pow(2,remoteHoldIncrement) mode:MISeekingModeRelative];
				break;
			// Left: Seek back
            case kRemoteButtonLeft_Hold:
				[self seek:-10*pow(2,remoteHoldIncrement) mode:MISeekingModeRelative];
				break;
			// Volume+: Increase volume
            case kRemoteButtonVolume_Plus_Hold:
                [self increaseVolume:nil];
				break;
			// Volume-: Decrease volume
            case kRemoteButtonVolume_Minus_Hold:
                [self decreaseVolume:nil];
				break;
			// Menu: Mute
            case kRemoteButtonMenu_Hold:
                [self toggleMute:nil];
				break;
			// Play: Stop
            case kRemoteButtonPlay_Sleep:
                [self stop:nil];
				break;
        }
        // re-schedule event
		if (remoteHoldIncrement < 6)
			remoteHoldIncrement++;
        [self performSelector:@selector(executeHoldActionForRemoteButton:)
				   withObject:buttonIdentifierNumber
				   afterDelay:1.];
    }
}
/************************************************************************************/
- (void) appleRemoteButton:(AppleRemoteEventIdentifier)buttonIdentifier 
			   pressedDown:(BOOL)pressedDown 
				clickCount:(unsigned int)count
{
	switch(buttonIdentifier)
    {
        // Play: Play/Pause
		case kRemoteButtonPlay:
            [self playPause:nil];
            break;
        // Volume+: Increase volume
		case kRemoteButtonVolume_Plus:
            [self increaseVolume:nil];
            break;
        // Volume-: Decrease volume
		case kRemoteButtonVolume_Minus:
            [self decreaseVolume:nil];
            break;
		// Right: Skip forward (skip to next chapter if available, skip 10m else)
        case kRemoteButtonRight:
			if (movieInfo && [movieInfo chapterCount] > 0)
				[self seekNext:nil];
			else
				[self seek:[PREFS floatForKey:MPESeekStepLarge] mode:MISeekingModeRelative];
            break;
		// Left: Skip backward
        case kRemoteButtonLeft:
            if (movieInfo && [movieInfo chapterCount] > 0)
				[self seekPrevious:nil];
			else
				[self seek:-[PREFS floatForKey:MPESeekStepLarge] mode:MISeekingModeRelative];
            break;
		// Menu: Switch fullscreen
        case kRemoteButtonMenu:
            [self switchFullscreen:nil];
            break;
		// Redirect hold events
        case kRemoteButtonRight_Hold:
        case kRemoteButtonLeft_Hold:
        case kRemoteButtonVolume_Plus_Hold:
        case kRemoteButtonVolume_Minus_Hold:
            // Trigger periodic method for hold duration
            appleRemoteHolding = pressedDown;
			remoteHoldIncrement = 1;
            if (pressedDown) {
                NSNumber* buttonIdentifierNumber = [NSNumber numberWithInt:buttonIdentifier];
                [self performSelector:@selector(executeHoldActionForRemoteButton:)
                           withObject:buttonIdentifierNumber];
            }
            break;
    }
}
/************************************************************************************/
- (NSWindow *) playerWindow
{
	return [[playerWindow retain] autorelease];
}
/************************************************************************************/
- (void)setOntop:(BOOL)aBool
{
    if(aBool)
	{
		[playerWindow setLevel:NSModalPanelWindowLevel];
		[videoOpenGLView setOntop:YES];
	}
	else
	{
		[playerWindow setLevel:NSNormalWindowLevel];
		[videoOpenGLView setOntop:NO];
	}
}
- (void)updateWindowOnTop
{
	if ([PREFS integerForKey:MPEWindowOnTopMode] == MPEWindowOnTopModeNever)
		[self setOntop:NO];
	else if ([PREFS integerForKey:MPEWindowOnTopMode] == MPEWindowOnTopModeAlways)
		[self setOntop:YES];
	else // [PREFS integerForKey:MPEWindowOnTopMode] == MPEWindowOnTopModeWhilePlaying
		[self setOntop:[myPlayer isPlaying]];
}
/************************************************************************************/
- (IBAction)switchFullscreen:(id)sender
{
	[videoOpenGLView toggleFullscreen];
}
/************************************************************************************/
- (int) fullscreenDeviceId {
	
	// Default value from preferences
	if (fullscreenDeviceId == -2) {
		
		if ([PREFS integerForKey:MPEGoToFullscreenOn] == MPEGoToFullscreenOnSameScreen)
			return [[NSScreen screens] indexOfObject:[playerWindow screen]];
		else if ([PREFS integerForKey:MPEFullscreenDisplayNumber] < [[NSScreen screens] count])
			return [PREFS integerForKey:MPEFullscreenDisplayNumber];
		else
			return [[NSScreen screens] count] - 1;
	
	// Same screen as player window
	} else if (fullscreenDeviceId == -1) {
		
		NSUInteger screenId = [[NSScreen screens] indexOfObject:[playerWindow screen]];
		if (screenId != NSNotFound)
			return screenId;
		else
			return 0;
	// custom screen id
	} else
		return fullscreenDeviceId;
}
/************************************************************************************/
- (IBAction)takeScreenshot:(id)sender {
	if ([myPlayer state] > MIStateStopped) {
		[myPlayer takeScreenshot];
	}
}
/************************************************************************************/
- (void)clearStreamMenus {
	
	NSMenuItem *parentMenu;
	NSMenu *menu;
	int j;
	
	for (j = 0; j < 3; j++) {
		
		switch (j) {
			case 0:
				parentMenu = menuController->videoStreamMenu;
				menu = [parentMenu submenu];
				break;
			case 1:
				parentMenu = menuController->audioStreamMenu;
				menu = [parentMenu submenu];
				[audioCycleButton setEnabled:NO];
				
				break;
			case 2:
				parentMenu = menuController->subtitleStreamMenu;
				menu = [parentMenu submenu];
				[subtitleCycleButton setEnabled:NO];
				
				break;
		}
		
		[parentMenu setEnabled:NO];
		
		while ([menu numberOfItems] > 0) {
			[menu removeItemAtIndex:0];
		}
		
	}
	
}
/************************************************************************************/
- (void)fillStreamMenus {
	
	if (movieInfo != nil) {
		
		// clear menus
		[self clearStreamMenus];
		
		// video stream menu
		NSEnumerator *en = [movieInfo getVideoStreamsEnumerator];
		NSNumber *key;
		NSMenu *menu = [menuController->videoStreamMenu submenu];
		NSMenuItem* newItem;
		BOOL hasItems = NO;
		
		while ((key = [en nextObject])) {
			newItem = [[NSMenuItem alloc]
					   initWithTitle:[movieInfo descriptionForVideoStream:[key intValue]]
					   action:@selector(videoMenuAction:)
					   keyEquivalent:@""];
			[newItem setRepresentedObject:key];
			if ([movieInfo videoStreamCount] == 1)
				[newItem setState:NSOnState];
			[menu addItem:newItem];
			[newItem release];
		}
		
		hasItems = ([menu numberOfItems] > 0);
		[menuController->videoStreamMenu setEnabled:hasItems];
		
		// audio stream menu
		en = [movieInfo getAudioStreamsEnumerator];
		menu = [menuController->audioStreamMenu submenu];
		
		while ((key = [en nextObject])) {
			newItem = [[NSMenuItem alloc]
					   initWithTitle:[movieInfo descriptionForAudioStream:[key intValue]]
					   action:@selector(audioMenuAction:)
					   keyEquivalent:@""];
			[newItem setRepresentedObject:key];
			if ([movieInfo audioStreamCount] == 1)
				[newItem setState:NSOnState];
			[menu addItem:newItem];
			[newItem release];
		}
		
		if ([menu numberOfItems] > 0) {
			
			// Copy menu for window popup
			NSMenu *other = [menu copy];
			newItem = [[NSMenuItem alloc]
					   initWithTitle:@""
					   action:NULL
					   keyEquivalent:@""];
			[other insertItem:newItem atIndex:0];
			[newItem release];
			
			[audioWindowMenu setMenu:other];
			[other release];

		}
		
		hasItems = ([menu numberOfItems] > 0);
		[menuController->audioStreamMenu setEnabled:hasItems];
		[audioWindowMenu setEnabled:hasItems];
		[audioCycleButton setEnabled:([menu numberOfItems] > 1)];
		
		// subtitle stream menu
		menu = [menuController->subtitleStreamMenu submenu];
		
		// Add "disabled" item
		newItem = [[NSMenuItem alloc]
				   initWithTitle:@"Disabled"
				   action:NULL
				   keyEquivalent:@""];
		[newItem setRepresentedObject:[NSArray arrayWithObjects: [NSNumber numberWithInt:SubtitleTypeDemux], 
									   [NSNumber numberWithInt:-1], nil]];
		[newItem setAction:@selector(subtitleMenuAction:)];
		if ([movieInfo subtitleCountForType:SubtitleTypeAll] == 0)
			[newItem setState:NSOnState];
		[menu addItem:newItem];
		[newItem release];
		
		if ([movieInfo subtitleCountForType:SubtitleTypeDemux] > 0 || [movieInfo subtitleCountForType:SubtitleTypeFile] > 0)
			[menu addItem:[NSMenuItem separatorItem]];
		
		// demux subtitles
		en = [movieInfo getSubtitleStreamsEnumeratorForType:SubtitleTypeDemux];
		
		while ((key = [en nextObject])) {
			newItem = [[NSMenuItem alloc]
					   initWithTitle:[movieInfo descriptionForSubtitleStream:[key intValue] andType:SubtitleTypeDemux]
					   action:@selector(subtitleMenuAction:)
					   keyEquivalent:@""];
			[newItem setRepresentedObject:[NSArray arrayWithObjects: [NSNumber numberWithInt:SubtitleTypeDemux], key, nil]];
			[menu addItem:newItem];
			[newItem release];
		}
		
		if ([movieInfo subtitleCountForType:SubtitleTypeDemux] > 0 && [movieInfo subtitleCountForType:SubtitleTypeFile] > 0)
			[menu addItem:[NSMenuItem separatorItem]];
		
		// file subtitles
		en = [movieInfo getSubtitleStreamsEnumeratorForType:SubtitleTypeFile];
		
		while ((key = [en nextObject])) {
			newItem = [[NSMenuItem alloc]
					   initWithTitle:[movieInfo descriptionForSubtitleStream:[key intValue] andType:SubtitleTypeFile]
					   action:@selector(subtitleMenuAction:)
					   keyEquivalent:@""];
			[newItem setRepresentedObject:[NSArray arrayWithObjects: [NSNumber numberWithInt:SubtitleTypeFile], key, nil]];
			[menu addItem:newItem];
			[newItem release];
		}
		
		if ([menu numberOfItems] > 0) {
			
			// Copy menu for window popup
			NSMenu *other = [menu copy];
			newItem = [[NSMenuItem alloc]
					   initWithTitle:@""
					   action:NULL
					   keyEquivalent:@""];
			[other insertItem:newItem atIndex:0];
			[newItem release];
			
			[subtitleWindowMenu setMenu:other];
			[other release];
		}
		
		hasItems = ([menu numberOfItems] > 0);
		[menuController->subtitleStreamMenu setEnabled:hasItems];
		[subtitleWindowMenu setEnabled:hasItems];
		[subtitleCycleButton setEnabled:([menu numberOfItems] > 1)];
	}
}
/************************************************************************************/
- (void)videoMenuAction:(id)sender {
	
	[myPlayer sendCommands:[NSArray arrayWithObjects:
		[NSString stringWithFormat:@"set_property switch_video %d",[[sender representedObject] intValue]],
		@"get_property switch_video",
		nil]];
}
- (void)audioMenuAction:(id)sender {
	
	[myPlayer sendCommands:[NSArray arrayWithObjects:
			[NSString stringWithFormat:@"set_property switch_audio %d",[[sender representedObject] intValue]],
			@"get_property switch_audio",
			nil]];
}
- (void)subtitleMenuAction:(id)sender {
	
	NSArray *props = [sender representedObject];
	
	if ([[props objectAtIndex:1] intValue] == -1)
		[myPlayer sendCommands:[NSArray arrayWithObjects:@"set_property sub_source -1",
				@"get_property sub_demux",@"get_property sub_file",
				nil]];
	else if ([[props objectAtIndex:0] intValue] == SubtitleTypeDemux)
		[myPlayer sendCommands:[NSArray arrayWithObjects:
				[NSString stringWithFormat:@"set_property sub_demux %d",[[props objectAtIndex:1] intValue]],
				@"get_property sub_demux",
				nil]];
	else
		[myPlayer sendCommands:[NSArray arrayWithObjects:
				[NSString stringWithFormat:@"set_property sub_file %d",[[props objectAtIndex:1] intValue]],
				@"get_property sub_file",
				nil]];
	
}
- (IBAction)cycleAudioStreams:(id)sender {
	
	[self cycleAudioStreamsWithOSD:NO];
}
- (void)cycleAudioStreamsWithOSD:(BOOL)showOSD {
	
	[myPlayer sendCommands:[NSArray arrayWithObjects:
							@"set_property switch_audio -2",
							@"get_property switch_audio",
							nil]
				   withOSD:(showOSD ? MISurpressCommandOutputNever : MISurpressCommandOutputConditionally)
				andPausing:MICommandPausingKeep];
}
- (IBAction)cycleSubtitleStreams:(id)sender {
	
	[self cycleSubtitleStreamsWithOSD:NO];
}
- (void)cycleSubtitleStreamsWithOSD:(BOOL)showOSD {
	
	[myPlayer sendCommands:[NSArray arrayWithObjects:
							@"sub_select",
							@"get_property sub_demux",@"get_property sub_file",
							nil]
				   withOSD:(showOSD ? MISurpressCommandOutputNever : MISurpressCommandOutputConditionally)
				andPausing:MICommandPausingKeep];
}
/************************************************************************************/
- (IBAction)cycleOSD:(id)sender {
	
	if (!movieInfo)
		return;
	
	int osdLevel;
	
	if ([[movieInfo prefs] objectForKey:MPEOSDLevel])
		osdLevel = [[movieInfo prefs] integerForKey:MPEOSDLevel];
	else
		osdLevel = [PREFS integerForKey:MPEOSDLevel];
	
	osdLevel++;
	
	if (osdLevel > 4)
		osdLevel = 0;
	
	[[movieInfo prefs] setInteger:osdLevel forKey:MPEOSDLevel];
}
/************************************************************************************/
- (void)setAudioDelay:(float)delay relative:(BOOL)setRelative {
	
	if (!movieInfo) return;
	
	if (setRelative)
		delay = [[movieInfo prefs] floatForKey:MPEAudioDelay] + delay;
	
	[[movieInfo prefs] setFloat:delay forKey:MPEAudioDelay];
}

- (void)setSubtitleDelay:(float)delay relative:(BOOL)setRelative {
	
	if (!movieInfo) return;
	
	if (setRelative)
		delay = [[movieInfo prefs] floatForKey:MPESubtitleDelay] + delay;
	
	[[movieInfo prefs] setFloat:delay forKey:MPESubtitleDelay];
}

- (void)setPlaybackSpeed:(float)speed multiply:(BOOL)multiply {
	
	if (!movieInfo) return;
	
	if (multiply) {
		float oldSpeed = 1;
		if ([[movieInfo prefs] objectForKey:MPEPlaybackSpeed])
			oldSpeed = [[movieInfo prefs] floatForKey:MPEPlaybackSpeed];
		speed = oldSpeed * speed;
	}
	
	[[movieInfo prefs] setFloat:speed forKey:MPEPlaybackSpeed];
}
/************************************************************************************/
- (void)newVideoStreamId:(int)streamId {
	
	[[menuController->videoStreamMenu submenu] setStateOfAllItemsTo:NSOffState];
	videoStreamId = -1;
	
	if (streamId != -1) {
		
		videoStreamId = streamId;
		
		int index = -1;
		for (NSMenuItem *item in [[menuController->videoStreamMenu submenu] itemArray]) {
			NSNumber *itemId = [item representedObject];
			if (itemId && [itemId intValue] == streamId) {
				index = [[menuController->videoStreamMenu submenu] indexOfItem:item];
				break;
			}
		}
		
		if (index != -1)
			[[[menuController->videoStreamMenu submenu] itemAtIndex:index] setState:NSOnState];
	}
}

- (void)newAudioStreamId:(int)streamId {
	
	[[menuController->audioStreamMenu submenu] setStateOfAllItemsTo:NSOffState];
	[[audioWindowMenu menu] setStateOfAllItemsTo:NSOffState];
	audioStreamId = -1;
	
	if (streamId != -1) {
		
		audioStreamId = streamId;
		
		int index = -1;
		for (NSMenuItem *item in [[menuController->audioStreamMenu submenu] itemArray]) {
			NSNumber *itemId = [item representedObject];
			if (itemId && [itemId intValue] == streamId) {
				index = [[menuController->audioStreamMenu submenu] indexOfItem:item];
				break;
			}
		}
		
		if (index != -1) {
			[[[menuController->audioStreamMenu submenu] itemAtIndex:index] setState:NSOnState];
			[[[audioWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
		}
	}
}

- (void)newSubtitleStreamId:(int)streamId forType:(SubtitleType)type {
	
	[[menuController->subtitleStreamMenu submenu] setStateOfAllItemsTo:NSOffState];
	[[subtitleWindowMenu menu] setStateOfAllItemsTo:NSOffState];
	subtitleDemuxStreamId = -1; subtitleFileStreamId = -1;
	
	if (streamId != -1) {
		
		if (type == SubtitleTypeFile)
			subtitleFileStreamId = streamId;
		else
			subtitleDemuxStreamId = streamId;
		
		int index = -1;
		for (NSMenuItem *item in [[menuController->subtitleStreamMenu submenu] itemArray]) {
			NSArray *arr = [item representedObject];
			if (arr && [arr count] == 2 
				&& [[arr objectAtIndex:0] intValue] == type
				&& [[arr objectAtIndex:1] intValue] == streamId) {
				index = [[menuController->subtitleStreamMenu submenu] indexOfItem:item];
				break;
			}
		}
		
		if (index != -1) {
			[[[menuController->subtitleStreamMenu submenu] itemAtIndex:index] setState:NSOnState];
			[[[subtitleWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
		}
	
	} else {
		
		[[[menuController->subtitleStreamMenu submenu] itemAtIndex:0] setState:NSOnState];
		[[[subtitleWindowMenu menu] itemAtIndex:1] setState:NSOnState];
	}
}
/************************************************************************************/
- (void)clearChapterMenu {
	
	[menuController->chapterMenu setEnabled:NO];
	[chapterWindowMenu setEnabled:NO];
	
	while ([[menuController->chapterMenu submenu] numberOfItems] > 0) {
		[[menuController->chapterMenu submenu] removeItemAtIndex:0];
	}
	while ([[chapterWindowMenu menu] numberOfItems] > 1) {
		[[chapterWindowMenu menu] removeItemAtIndex:1];
	}
}
/************************************************************************************/
- (void)fillChapterMenu {
	
	if (movieInfo != nil) {
		
		[self clearChapterMenu];
		
		// video stream menu
		NSEnumerator *en = [movieInfo getChaptersEnumerator];
		NSNumber *key;
		NSMenu *menu = [menuController->chapterMenu submenu];
		NSMenuItem* newItem;
		
		while ((key = [en nextObject])) {
			newItem = [[NSMenuItem alloc]
					   initWithTitle:[NSString stringWithFormat:@"%d: %@", [key intValue]+1, [movieInfo nameForChapter:[key intValue]]]
					   action:@selector(chapterMenuAction:)
					   keyEquivalent:@""];
			[newItem setRepresentedObject:key];
			[menu addItem:newItem];
			[newItem release];
		}
		
		if ([menu numberOfItems] > 0) {
			
			// Copy menu for window popup
			NSMenu *other = [menu copy];
			newItem = [[NSMenuItem alloc]
					   initWithTitle:@"C"
					   action:NULL
					   keyEquivalent:@""];
			[other insertItem:newItem atIndex:0];
			[newItem release];
			
			[chapterWindowMenu setMenu:other];
			[other release];
		}
		
		[chapterWindowMenu setEnabled:([menu numberOfItems] > 1)];
		[menuController->chapterMenu setEnabled:([menu numberOfItems] > 0)];
	}
}
/************************************************************************************/
- (void)chapterMenuAction:(id)sender {
	
	[self goToChapter:[[sender representedObject] intValue]];
}
/************************************************************************************/
- (void)selectChapterForTime:(float)seconds {
	//[Debug log:ASL_LEVEL_ERR withMessage:@"selectChapterForTime"];
	if (movieInfo && [movieInfo chapterCount] > 0) {
		
		NSEnumerator *en = [movieInfo getChaptersEnumerator];
		NSNumber *key;
		NSNumber *bestKey = nil;
		
		while ((key = [en nextObject])) {
			
			if ([movieInfo startOfChapter:[key intValue]] <= seconds 
					&& (bestKey == nil || 
							[movieInfo startOfChapter:[bestKey intValue]] < [movieInfo startOfChapter:[key intValue]])) {
				
				bestKey = key;
			}
		}
		
		if (bestKey) {
			
			int index = [[menuController->chapterMenu submenu] indexOfItemWithRepresentedObject:bestKey];
			
			if (index != -1 && [[[menuController->chapterMenu submenu] itemAtIndex:index] state] != NSOnState) {
				
				[[menuController->chapterMenu submenu] setStateOfAllItemsTo:NSOffState];
				[[chapterWindowMenu menu] setStateOfAllItemsTo:NSOffState];
				
				[[[menuController->chapterMenu submenu] itemAtIndex:index] setState:NSOnState];
				[[[chapterWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
				currentChapter = [bestKey intValue];
			}
			return;
			
		} else {
			[[menuController->chapterMenu submenu] setStateOfAllItemsTo:NSOffState];
			[[chapterWindowMenu menu] setStateOfAllItemsTo:NSOffState];
		}
		
	}
	
	currentChapter = 0;
}
/************************************************************************************/
- (BOOL) isFullscreen {
	return [videoOpenGLView isFullscreen];
}
/************************************************************************************/
- (void)clearFullscreenMenu {
	
	[menuController->fullscreenMenu setEnabled:NO];
	[fullscreenWindowMenu setEnabled:NO];
	
	while ([[menuController->fullscreenMenu submenu] numberOfItems] > 0) {
		[[menuController->fullscreenMenu submenu] removeItemAtIndex:0];
	}
	while ([[fullscreenWindowMenu menu] numberOfItems] > 0) {
		[[fullscreenWindowMenu menu] removeItemAtIndex:0];
	}
}
/************************************************************************************/
- (void)fillFullscreenMenu {
	
	[self clearFullscreenMenu];
	
	NSMenu *menu = [menuController->fullscreenMenu submenu];
	[menu setDelegate:self];
	NSMenuItem *newItem;
	NSArray *screens = [NSScreen screens];
	
	// Add entry for auto option (-2)
	newItem = [[NSMenuItem alloc]
			   initWithTitle:@"Automatic"
			   action:@selector(fullscreenMenuAction:)
			   keyEquivalent:@""];
	[newItem setRepresentedObject:[NSNumber numberWithInt:-2]];
	[menu addItem:newItem];
	[newItem release];
	
	// Add entry for same screen option (-1)
	newItem = [[NSMenuItem alloc]
			   initWithTitle:@"Same screen as player window"
			   action:@selector(fullscreenMenuAction:)
			   keyEquivalent:@""];
	[newItem setRepresentedObject:[NSNumber numberWithInt:-1]];
	[menu addItem:newItem];
	[newItem release];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	// Add screens
	int i;
	for (i=0; i < [screens count]; i++) {
		
		newItem = [[NSMenuItem alloc]
				   initWithTitle:[NSString stringWithFormat:@"Screen %d: %.0fx%.0f", (i+1), [[screens objectAtIndex:i] frame].size.width, [[screens objectAtIndex:i] frame].size.height]
				   action:@selector(fullscreenMenuAction:)
				   keyEquivalent:@""];
		[newItem setRepresentedObject:[NSNumber numberWithInt:i]];
		
		if (fullscreenDeviceId < 0)
			[newItem setEnabled:NO];
		
		[menu addItem:newItem];
		[newItem release];
	}
	
	if ([menu numberOfItems] > 0) {
		
		// Copy menu for window popup
		NSMenu *other = [[menu copy] autorelease];
		[other setDelegate:self];
		newItem = [[NSMenuItem alloc]
				   initWithTitle:@""
				   action:NULL
				   keyEquivalent:@""];
		[other insertItem:newItem atIndex:0];
		[newItem release];
		
		[fullscreenWindowMenu setMenu:other];
	}
	
	[menuController->fullscreenMenu setEnabled:([menu numberOfItems] > 0)];
	[fullscreenWindowMenu setEnabled:([menu numberOfItems] > 0)];
}
/************************************************************************************/
- (void)fullscreenMenuAction:(id)sender {
	
	int devid = [[sender representedObject] intValue];
	
	if (devid >= -2 && devid < (int)[[NSScreen screens] count]) {
		
		fullscreenDeviceId = devid;
		[self selectFullscreenDevice];
	}
}
/************************************************************************************/
- (void)selectFullscreenDevice {
	
	[[menuController->fullscreenMenu submenu] setStateOfAllItemsTo:NSOffState];
	[[fullscreenWindowMenu menu] setStateOfAllItemsTo:NSOffState];
	
	// index of currently selected device
	int index = [[menuController->fullscreenMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:[self fullscreenDeviceId]]];
	int state = (fullscreenDeviceId < 0) ? NSMixedState : NSOnState;
	
	if (index != -1) {
		[[[menuController->fullscreenMenu submenu] itemAtIndex:index] setState:state];
		[[[fullscreenWindowMenu menu] itemAtIndex:(index+1)] setState:state];
	}
	
	// select auto entry
	if (fullscreenDeviceId == -2) {
		
		int index = [[menuController->fullscreenMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:-2]];
		
		[[[menuController->fullscreenMenu submenu] itemAtIndex:index] setState:NSOnState];
		[[[fullscreenWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
	
		// same entry implicit selection
		if ([PREFS integerForKey:MPEGoToFullscreenOn] == MPEGoToFullscreenOnSameScreen) {
			
			int index = [[menuController->fullscreenMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:-1]];
			
			[[[menuController->fullscreenMenu submenu] itemAtIndex:index] setState:NSMixedState];
			[[[fullscreenWindowMenu menu] itemAtIndex:(index+1)] setState:NSMixedState];
		}
	}
	
	// select same entry
	if (fullscreenDeviceId == -1) {
		
		int index = [[menuController->fullscreenMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:-1]];
		
		[[[menuController->fullscreenMenu submenu] itemAtIndex:index] setState:NSOnState];
		[[[fullscreenWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
	}
}
/************************************************************************************/
- (void)screensDidChange {
	
	// Reset devide id to preferences value if auto or unavailable
	if (fullscreenDeviceId == -2 || [self fullscreenDeviceId] >= [[NSScreen screens] count])
		fullscreenDeviceId = [PREFS integerForKey:MPEFullscreenDisplayNumber];
	// Rebuild menu and select current id
	[self fillFullscreenMenu];
	[self selectFullscreenDevice];
}
/************************************************************************************/
- (void)menuWillOpen:(NSMenu *)menu
{
	[self selectFullscreenDevice];
}
/************************************************************************************
 NOTIFICATION OBSERVERS
 ************************************************************************************/
- (void) appShouldTerminate
{
	// save values before all is saved to disk and released
	if ([myPlayer state] > MIStateStopped && [[[AppController sharedController] preferences] objectForKey:@"PlaylistRemember"])
	{
		/*if ([[[AppController sharedController] preferences] boolForKey:@"PlaylistRemember"])
		{
			//[[[AppController sharedController] preferences] setObject:[NSNumber numberWithInt:[playListController indexOfItem:myPlayingItem]] forKey:@"LastTrack"];
			
			if (myPlayingItem)
				[myPlayingItem setObject:[NSNumber numberWithFloat:[myPlayer seconds]] forKey:@"LastSeconds"];			
		}*/
	}
	
	// stop mplayer
	[myPlayer stop];	
}
/************************************************************************************/
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:MPEWindowOnTopMode])
		[self updateWindowOnTop];
}
/************************************************************************************/
- (void) interface:(MplayerInterface *)mi hasChangedStateTo:(NSNumber *)statenumber fromState:(NSNumber *)oldstatenumber
{	
	MIState state = [statenumber unsignedIntValue];
	unsigned int stateMask = (1<<state);
	MIState oldState = [oldstatenumber unsignedIntValue];
	unsigned int oldStateMask = (1<<oldState);
		
	// First play after startup
	if (state == MIStatePlaying && (oldStateMask & MIStateStartupMask)) {
		// Populate menus
		[self fillStreamMenus];
		[self fillChapterMenu];
		// Request the selected streams
		[myPlayer sendCommands:[NSArray arrayWithObjects:
								@"get_property switch_video",@"get_property switch_audio",
								@"get_property sub_demux",@"get_property sub_file",nil]];
	}
	
	// Change of Play/Pause state
	if (!!(stateMask & MIStatePPPlayingMask) != !!(oldStateMask & MIStatePPPlayingMask)) {
		// Playing
		if (stateMask & MIStatePPPlayingMask) {
			// Update interface
			[playButton setImage:pauseImageOff];
			[playButton setAlternateImage:pauseImageOn];
			[menuController->playMenuItem setTitle:@"Pause"];
		// Pausing
		} else if (stateMask & MIStatePPPausedMask) {
			// Update interface
			[playButton setImage:playImageOff];
			[playButton setAlternateImage:playImageOn];
			[menuController->playMenuItem setTitle:@"Play"];
			
		}
		
		// Update on-top
		[self updateWindowOnTop];
		
	}
	
	// Change of Running/Stopped state
	if (!!(stateMask & MIStateStoppedMask) != !!(oldStateMask & MIStateStoppedMask)) {
		// Stopped
		if (stateMask & MIStateStoppedMask) {
			// Update interface
			[playerWindow setTitle:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]];
			[timeTextField setStringValue:@"00:00:00"];
			[fullscreenButton setEnabled:NO];
			// Disable stream menus
			[menuController->videoStreamMenu setEnabled:NO];
			[menuController->audioStreamMenu setEnabled:NO];
			[menuController->subtitleStreamMenu setEnabled:NO];
			[audioWindowMenu setEnabled:NO];
			[subtitleWindowMenu setEnabled:NO];
			// Release Sleep assertion
			IOPMAssertionRelease(sleepAssertionId);	
		// Running
		} else {
			// Update interface
			[playerWindow setTitle:[NSString stringWithFormat:@"%@ - %@",
									[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
									[movieInfo title]]];
			[fullscreenButton setEnabled:YES];
			// Disable loop when movie finished
			[self setLoopMovie:NO];
			[self updateLoopStatus];
			// Create sleep assertion
			IOPMAssertionCreate(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, &sleepAssertionId);
		}
	}
	
	// Update progress bar
	if (stateMask & MIStateStoppedMask && !(oldStateMask & MIStateStoppedMask)) {
		// Reset progress bar
		[scrubbingBar setScrubStyle:MPEScrubbingBarEmptyStyle];
		[scrubbingBar setDoubleValue:0];
		[scrubbingBar setIndeterminate:NO];
	} else if (stateMask & MIStateIntermediateMask && !(oldStateMask & MIStateIntermediateMask)) {
		// Intermediate progress bar
		[scrubbingBar setScrubStyle:MPEScrubbingBarProgressStyle];
		[scrubbingBar setIndeterminate:YES];
	} else if (stateMask & MIStatePositionMask && !(oldStateMask & MIStatePositionMask)) {
		// Progress bar
		if ([movieInfo length] > 0) {
			[scrubbingBar setMaxValue: [movieInfo length]];
			[scrubbingBar setScrubStyle:MPEScrubbingBarPositionStyle];
		} else {
			[scrubbingBar setScrubStyle:MPEScrubbingBarProgressStyle];
			[scrubbingBar setMaxValue:100];
			[scrubbingBar setIndeterminate:NO];
		}
	}
	
	// Handle stop
	if (stateMask & MIStateStoppedMask) {
		// Nothing more to play, look for next or clean up
		if (!continuousPlayback) {
			// Playlist mode
			if (playingFromPlaylist) {
				// if playback finished itself (not by user) let playListController know
				if (state == MIStateFinished || state == MIStateError)
					[playListController finishedPlayingItem:movieInfo];
				// close view otherwise
				else
					[self stopFromPlaylist];
			// Regular play mode
			} else
				[self cleanUpAfterStop];
		// Next item already waiting, don't clean up
		} else
			continuousPlayback = NO;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MPEPlaybackStoppedNotification
															object:self];
	}
}
/************************************************************************************/
- (void) interface:(MplayerInterface *)mi streamUpate:(MovieInfo *)item
{
	[self fillStreamMenus];
}

/************************************************************************************/
- (void) interface:(MplayerInterface *)mi hasSelectedStream:(NSNumber *)streamId ofType:(NSNumber *)type
{
	// Streams
	if ([type intValue] == MPEStreamTypeVideo)
		[self newVideoStreamId:[streamId intValue]];
	
	if ([type intValue] == MPEStreamTypeAudio)
		[self newAudioStreamId:[streamId intValue]];
	
	if ([type intValue] == MPEStreamTypeSubtitleDemux)
		[self newSubtitleStreamId:[streamId intValue] forType:SubtitleTypeDemux];
	
	if ([type intValue] == MPEStreamTypeSubtitleFile)
		[self newSubtitleStreamId:[streamId intValue] forType:SubtitleTypeFile];
}

/************************************************************************************/
- (void) interface:(MplayerInterface *)mi timeUpdate:(NSNumber *)newTime
{
	
#if __MAC_OS_X_VERSION_MIN_REQUIRED <= __MAC_OS_X_VERSION_10_5
	// prevent screensaver on leopard
	if (NSAppKitVersionNumber < 1000 && [movieInfo isVideo])
		UpdateSystemActivity(UsrActivity);
#endif
	
	if ([myPlayer state] == MIStatePlaying || [myPlayer state] == MIStateSeeking) {
		if (movieInfo) {
			// update time
			if (seekUpdateBlockUntil < [NSDate timeIntervalSinceReferenceDate]) {
				if ([playerWindow isVisible])
					[self updatePlayerWindow];
			}
		}
		// check chapters
		double timeDifference = ([NSDate timeIntervalSinceReferenceDate] - lastChapterCheck);
		if (timeDifference >= MP_CHAPTER_CHECK_INTERVAL) {
			lastChapterCheck = [NSDate timeIntervalSinceReferenceDate];
			[self selectChapterForTime:[myPlayer seconds]];
		}
	}
}
/************************************************************************************/
- (void) updatePlayerWindow
{
	int seconds = (int)[myPlayer seconds];
	
	if ([movieInfo length] > 0)
		[scrubbingBar setDoubleValue:seconds];
	else
		[scrubbingBar setDoubleValue:0];
	
	[timeTextField setStringValue:[NSString stringWithFormat:@"%02d:%02d:%02d", seconds/3600,(seconds%3600)/60,seconds%60]];
}

/************************************************************************************/
- (void) progresBarClicked:(NSNotification *)notification
{
	if ([myPlayer state] == MIStatePlaying || [myPlayer state] == MIStatePaused || [myPlayer state] == MIStateSeeking) {
		int theMode = MISeekingModePercent;
		if ([movieInfo length] > 0)
			theMode = MISeekingModeAbsolute;

		[self seek:[[[notification userInfo] 
				objectForKey:@"SBClickedValue"] floatValue] mode:theMode];
	}
}

- (void)sendKeyEvent:(int)event
{
	[myPlayer sendCommand: [NSString stringWithFormat:@"key_down_event %d",event]];
}

/************************************************************************************
 DELEGATE METHODS
 ************************************************************************************/
// main window delegates
// exekutes when window zoom box is clicked
- (BOOL)windowShouldZoom:(NSWindow *)sender toFrame:(NSRect)newFrame
{
	return YES;
}
/************************************************************************************/
// executes when window is closed
- (BOOL)windowShouldClose:(id)sender
{
	BOOL closeNow;
	
	if ([videoOpenGLView isFullscreen]) {
		closeNow = NO;
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector: @selector(closeWindowNow:) 
			name: @"MIVideoViewClosed"
			object: videoOpenGLView];
	} else
		closeNow = YES;
	
	[self stop:nil];
	return closeNow;
}

- (void)closeWindowNow:(id)sender {
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
		name: @"MIVideoViewClosed"
		object: videoOpenGLView];
	
	[playerWindow close];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	if (movieInfo && [[AppController sharedController] movieInfoProvider] != self)
		[[AppController sharedController] setMovieInfoProvider:self];
}


@end
