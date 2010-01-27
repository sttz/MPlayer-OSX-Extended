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
#import "TimestampTextField.h"

#if __MAC_OS_X_VERSION_MIN_REQUIRED <= __MAC_OS_X_VERSION_10_5
// used for preventing screensaver on leopard
#import <CoreServices/CoreServices.h>
// not very nice hack to get to the header on 64bit builds
#ifdef __LP64__
#import <CoreServices/../Frameworks/OSServices.framework/Headers/Power.h>
#endif
#endif

#import <Carbon/Carbon.h>

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
	subtitleVobStreamId = -1;
	
	// load images
	playImageOn = [[NSImage imageNamed:@"play_button_on"] retain];
	playImageOff = [[NSImage imageNamed:@"play_button_off"] retain];
	pauseImageOn = [[NSImage imageNamed:@"pause_button_on"] retain];
	pauseImageOff = [[NSImage imageNamed:@"pause_button_off"] retain];
	
	// create menus
	videoStreamsMenu     = [NSMenu new];
	audioStreamsMenu     = [NSMenu new];
	subtitleStreamsMenu  = [NSMenu new];
	chaptersMenu         = [NSMenu new];
	fullscreenDeviceMenu = [NSMenu new];
	
	// Save reference to menu controller
	menuController = [[AppController sharedController] menuController];
	
	// Load MPlayer interface
	myPlayer = [MPlayerInterface new];
	
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
	
	// register for fullscreen device changes
	[PREFS addObserver:self
			forKeyPath:MPEGoToFullscreenOn
			   options:0
			   context:nil];
	
	[PREFS addObserver:self
			forKeyPath:MPEFullscreenDisplayNumber
			   options:0
			   context:nil];
	
	return self;
}

-(void)awakeFromNib
{	
    // Make sure we don't initialize twice
	if (playListController)
		return;
	
	NSUInteger playerNum = [[AppController sharedController] registerPlayer:self];
	
	// Load playlist controller for first player window
	if (playerNum == 0)
		[NSBundle loadNibNamed:@"Playlist" owner:self];
	[self updatePlaylistButton:nil];
	
	// resize window
	[playerWindow setContentSize:[playerWindow contentMinSize]];
	
	int offset = (playerNum == 0 ? 0 : 50);
	[playerWindow setFrameOrigin:NSMakePoint([playerWindow frame].origin.x + offset,
											 [playerWindow frame].origin.y - offset)];
	
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
	
	// Pass buffer name to interface
	[myPlayer setBufferName:[videoOpenGLView bufferName]];
	
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
	
	[videoStreamsMenu release];
	[audioStreamsMenu release];
	[subtitleStreamsMenu release];
	[chaptersMenu release];
	[fullscreenDeviceMenu release];
	
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
					
					if ([[AppController sharedController] isDVD:[propertyList objectAtIndex:i]])
						return NSDragOperationCopy; // video_ts folder
					
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
						[[AppController sharedController] isExtension:[filename pathExtension] ofType:MP_DIALOG_MEDIA] ||
						[[AppController sharedController] isDVD:filename]) {
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
	if (playListController)
		[playListButton setState:[[playListController window] isVisible]];
	else
		[playListButton setEnabled:NO];
}

/************************************************************************************/
- (void) stopFromPlaylist
{
	[self stop:nil];
	playingFromPlaylist = NO;
	[videoOpenGLView close];
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
- (MPlayerInterface *)playerInterface
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
	if (subtitleVobStreamId >= 0)
		[myPlayer sendCommand:[NSString stringWithFormat:@"set_property sub_vob %i",subtitleVobStreamId]];
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
	
	if ([self isCurrentPlayer])
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
	if ([myPlayer state] > MIStateStopped)
		[myPlayer pause];
		
	else {
		// set the item to play
		if ([playListController indexOfSelectedItem] < 0)
			[playListController selectItemAtIndex:0];
		
		// play the items
		if ([playListController selectedItem])
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
	if (![self isCurrentPlayer]) return;
	
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
- (void) executeHoldActionForRemoteButton:(NSNumber*)buttonIdentifierNumber
{
    if(appleRemoteHolding)
    {
        switch([buttonIdentifierNumber intValue])
        {
			// Right: Seek forward
			case kRemoteButtonRight_Hold:
				[self seek:[PREFS floatForKey:MPERemoteSeekBase]*pow(2,remoteHoldIncrement) mode:MISeekingModeRelative];
				break;
			// Left: Seek back
            case kRemoteButtonLeft_Hold:
				[self seek:-[PREFS floatForKey:MPERemoteSeekBase]*pow(2,remoteHoldIncrement) mode:MISeekingModeRelative];
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
				[self seek:[PREFS floatForKey:MPERemoteSkipStep] mode:MISeekingModeRelative];
            break;
		// Left: Skip backward
        case kRemoteButtonLeft:
            if (movieInfo && [movieInfo chapterCount] > 0)
				[self seekPrevious:nil];
			else
				[self seek:-[PREFS floatForKey:MPERemoteSkipStep] mode:MISeekingModeRelative];
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
			remoteHoldIncrement = 0;
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
	
	if (![self isCurrentPlayer]) return;
	
	NSMenuItem *parentMenu;
	int j;
	
	for (j = 0; j < 6; j++) {
		
		switch (j) {
			case 0:
				parentMenu = menuController->videoStreamMenu;
				break;
			case 1:
				parentMenu = menuController->audioStreamMenu;
				break;
			case 2:
				parentMenu = menuController->subtitleStreamMenu;			
				break;
			case 3:
				parentMenu = videoWindowItem;
				break;
			case 4:
				parentMenu = audioWindowItem;
				break;
			case 5:
				parentMenu = subtitleWindowItem;
				break;
		}
		
		[parentMenu setEnabled:NO];
	}
	
}
/************************************************************************************/
- (void)fillStreamMenus {
	
	if (![self isCurrentPlayer]) return;
	
	// clear menus
	[self clearStreamMenus];
	
	if (!movieInfo)
		return;
	
	[videoStreamsMenu removeAllItems];
	[audioStreamsMenu removeAllItems];
	[subtitleStreamsMenu removeAllItems];
	
	NSEnumerator *streams;
	NSMenu *menu;
	
	// video stream menu
	if ([movieInfo videoStreamCount] > 0) {
		
		streams = [movieInfo getVideoStreamsEnumerator];
		menu = videoStreamsMenu;
		
		for (NSNumber *streamId in streams) {
			NSMenuItem *item = [menu addItemWithTitle:[movieInfo descriptionForVideoStream:[streamId intValue]]
											   action:@selector(videoMenuAction:)
										keyEquivalent:@""];
			[item setRepresentedObject:streamId];
		}
		
		[menuController->videoStreamMenu setSubmenu:videoStreamsMenu];
		[videoWindowItem setSubmenu:[[menu copy] autorelease]];
		
		[menuController->videoStreamMenu setEnabled:YES];
		[videoWindowItem setEnabled:YES];
	}
	
	// audio stream menu
	if ([movieInfo audioStreamCount] > 0) {
		
		streams = [movieInfo getAudioStreamsEnumerator];
		menu = audioStreamsMenu;
		
		for (NSNumber *streamId in streams) {
			NSMenuItem *item = [menu addItemWithTitle:[movieInfo descriptionForAudioStream:[streamId intValue]]
											   action:@selector(audioMenuAction:)
										keyEquivalent:@""];
			[item setRepresentedObject:streamId];
		}
		
		[menuController->audioStreamMenu setSubmenu:audioStreamsMenu];
		[audioWindowItem setSubmenu:[[menu copy] autorelease]];
		
		[menuController->audioStreamMenu setEnabled:YES];
		[audioWindowItem setEnabled:YES];
	}
	
	// subtitle stream menu
	if ([movieInfo subtitleCountForType:SubtitleTypeAll]) {
		
		menu = subtitleStreamsMenu;
		
		// add "disabled" item
		NSMenuItem *item = [menu addItemWithTitle:@"Disabled"
							   action:@selector(subtitleMenuAction:)
						keyEquivalent:@""];
		[item setRepresentedObject:[NSArray arrayWithObjects:
									[NSNumber numberWithInt:SubtitleTypeDemux], 
									[NSNumber numberWithInt:-1],
									nil]];
		
		// subtitle stream types
		SubtitleType type;
		int i;
		for (i = 0; i < 3; i++) {
			
			switch (i) {
				case 0:
					type = SubtitleTypeDemux;
					break;
				case 1:
					type = SubtitleTypeVob;
					break;
				case 2:
					type = SubtitleTypeFile;
					break;
			}
			
			if ([movieInfo subtitleCountForType:type] == 0)
				continue;
			
			[menu addItem:[NSMenuItem separatorItem]];
			
			streams = [movieInfo getSubtitleStreamsEnumeratorForType:type];
			
			for (NSNumber *streamId in streams) {
				NSMenuItem *item = [menu addItemWithTitle:[movieInfo descriptionForSubtitleStream:[streamId intValue] andType:type]
												   action:@selector(subtitleMenuAction:)
											keyEquivalent:@""];
				[item setRepresentedObject:[NSArray arrayWithObjects:
											[NSNumber numberWithInt:type], 
											streamId,
											nil]];
			}
		}
		
		[menuController->subtitleStreamMenu setSubmenu:subtitleStreamsMenu];
		[subtitleWindowItem setSubmenu:[[menu copy] autorelease]];
		
		[menuController->subtitleStreamMenu setEnabled:YES];
		[subtitleWindowItem setEnabled:YES];
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
				@"get_property sub_demux",@"get_property sub_file",@"get_property sub_vob",
				nil]];
	else if ([[props objectAtIndex:0] intValue] == SubtitleTypeDemux)
		[myPlayer sendCommands:[NSArray arrayWithObjects:
				[NSString stringWithFormat:@"set_property sub_demux %d",[[props objectAtIndex:1] intValue]],
				@"get_property sub_demux",
				nil]];
	else if ([[props objectAtIndex:0] intValue] == SubtitleTypeFile)
		[myPlayer sendCommands:[NSArray arrayWithObjects:
				[NSString stringWithFormat:@"set_property sub_file %d",[[props objectAtIndex:1] intValue]],
				@"get_property sub_file",
				nil]];
	else
		[myPlayer sendCommands:[NSArray arrayWithObjects:
				[NSString stringWithFormat:@"set_property sub_vob %d",[[props objectAtIndex:1] intValue]],
				@"get_property sub_vob",
				nil]];
	
}
- (IBAction)cycleAudioStreams:(id)sender {
	
	[self cycleAudioStreamsWithOSD:YES];
}
- (void)cycleAudioStreamsWithOSD:(BOOL)showOSD {
	
	[myPlayer sendCommands:[NSArray arrayWithObjects:
							@"switch_audio -2",
							@"get_property switch_audio",
							nil]
				   withOSD:(showOSD ? MISurpressCommandOutputNever : MISurpressCommandOutputConditionally)
				andPausing:MICommandPausingKeep];
}
- (IBAction)cycleSubtitleStreams:(id)sender {
	
	[self cycleSubtitleStreamsWithOSD:YES];
}
- (void)cycleSubtitleStreamsWithOSD:(BOOL)showOSD {
	
	[myPlayer sendCommands:[NSArray arrayWithObjects:
							@"sub_select",
							@"get_property sub_demux",@"get_property sub_file",@"get_property sub_vob",
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
	
	[videoStreamsMenu setStateOfAllItemsTo:NSOffState];
	[[videoWindowItem submenu] setStateOfAllItemsTo:NSOffState];
	videoStreamId = streamId;
	
	if (streamId != -1) {
		
		NSMenuItem *item = [[videoWindowItem submenu] itemWithRepresentedIntegerValue:streamId];
		[item setState:NSOnState];
		
		item = [videoStreamsMenu itemWithRepresentedIntegerValue:streamId];
		[item setState:NSOnState];
	}
}

- (void)newAudioStreamId:(int)streamId {
	
	[audioStreamsMenu setStateOfAllItemsTo:NSOffState];
	[[audioWindowItem submenu] setStateOfAllItemsTo:NSOffState];
	audioStreamId = streamId;
	
	if (streamId != -1) {
		
		NSMenuItem *item = [[audioWindowItem submenu] itemWithRepresentedIntegerValue:streamId];
		[item setState:NSOnState];
		
		item = [audioStreamsMenu itemWithRepresentedIntegerValue:streamId];
		[item setState:NSOnState];
	}
}

- (void)newSubtitleStreamId:(int)streamId forType:(SubtitleType)type {
	
	[subtitleStreamsMenu setStateOfAllItemsTo:NSOffState];
	[[subtitleWindowItem submenu] setStateOfAllItemsTo:NSOffState];
	subtitleDemuxStreamId = -1; subtitleFileStreamId = -1; subtitleVobStreamId = -1;
	
	if (streamId != -1) {
		
		if (type == SubtitleTypeFile)
			subtitleFileStreamId = streamId;
		else if (type == SubtitleTypeDemux)
			subtitleDemuxStreamId = streamId;
		else
			subtitleVobStreamId = streamId;
		
		int index = -1;
		for (NSMenuItem *item in [subtitleStreamsMenu itemArray]) {
			NSArray *arr = [item representedObject];
			if (arr && [arr count] == 2 
				&& [[arr objectAtIndex:0] intValue] == type
				&& [[arr objectAtIndex:1] intValue] == streamId) {
				index = [subtitleStreamsMenu indexOfItem:item];
				break;
			}
		}
		
		if (index != -1) {
			[[subtitleStreamsMenu itemAtIndex:index] setState:NSOnState];
			[[[subtitleWindowItem submenu] itemAtIndex:index] setState:NSOnState];
		}
	
	} else {
		
		[[subtitleStreamsMenu itemAtIndex:0] setState:NSOnState];
		[[[subtitleWindowItem submenu] itemAtIndex:0] setState:NSOnState];
	}
}
/************************************************************************************/
- (void)clearChapterMenu {
	
	if (![self isCurrentPlayer]) return;
	
	[menuController->chapterMenu setEnabled:NO];
	[chapterWindowItem setEnabled:NO];
}
/************************************************************************************/
- (void)fillChapterMenu {
	
	if (![self isCurrentPlayer]) return;
	
	[self clearChapterMenu];
	[chaptersMenu removeAllItems];
	
	if (movieInfo && [movieInfo chapterCount] > 0) {
		
		NSEnumerator *chapters = [movieInfo getChaptersEnumerator];
		NSMenu *menu = chaptersMenu;
		
		for (NSNumber *chapterId in chapters) {
			int cid = [chapterId intValue];
			NSMenuItem *item = [menu addItemWithTitle:[NSString stringWithFormat:@"%d: %@", cid+1, [movieInfo nameForChapter:cid]]
											   action:@selector(chapterMenuAction:)
										keyEquivalent:@""];
			[item setRepresentedObject:chapterId];
		}
		
		[menuController->chapterMenu setSubmenu:chaptersMenu];
		[chapterWindowItem setSubmenu:[[menu copy] autorelease]];
		
		[chapterWindowItem setEnabled:YES];
		[menuController->chapterMenu setEnabled:YES];
	}
}
/************************************************************************************/
- (void)chapterMenuAction:(id)sender {
	
	[self goToChapter:[[sender representedObject] intValue]];
}
/************************************************************************************/
- (void)selectChapterForTime:(float)seconds {
	
	if (movieInfo && [movieInfo chapterCount] > 0) {
		
		[chaptersMenu setStateOfAllItemsTo:NSOffState];
		[[chapterWindowItem submenu] setStateOfAllItemsTo:NSOffState];
		
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
			
			int index = [chaptersMenu indexOfItemWithRepresentedObject:bestKey];
			
			if (index != -1) {
				[[chaptersMenu itemAtIndex:index] setState:NSOnState];
				[[[chapterWindowItem submenu] itemAtIndex:index] setState:NSOnState];
				currentChapter = [bestKey intValue];
			}
			return;
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
	
	if (![self isCurrentPlayer]) return;
	
	[menuController->fullscreenMenu setEnabled:NO];
	[fullscreenWindowItem setEnabled:NO];
}
/************************************************************************************/
- (void)fillFullscreenMenu {
	
	if (![self isCurrentPlayer]) return;
	
	[self clearFullscreenMenu];
	[fullscreenDeviceMenu removeAllItems];
	
	NSMenu *menu = fullscreenDeviceMenu;
	NSArray *screens = [NSScreen screens];
	NSMenuItem *item;
	
	// Add entry for auto option (-2)
	item = [menu addItemWithTitle:@"Selected from preferences"
						   action:@selector(fullscreenMenuAction:)
					keyEquivalent:@""];
	[item setRepresentedObject:[NSNumber numberWithInt:-2]];
	
	// Add entry for same screen option (-1)
	item = [menu addItemWithTitle:@"Same screen as player window"
						   action:@selector(fullscreenMenuAction:)
					keyEquivalent:@""];
	[item setRepresentedObject:[NSNumber numberWithInt:-1]];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	// Add screens
	int i;
	for (i=0; i < [screens count]; i++) {
		item = [menu addItemWithTitle:[NSString stringWithFormat:@"Screen %d: %.0fx%.0f", 
									   (i+1), 
									   [[screens objectAtIndex:i] frame].size.width, 
									   [[screens objectAtIndex:i] frame].size.height]
							   action:@selector(fullscreenMenuAction:)
						keyEquivalent:@""];
		[item setRepresentedObject:[NSNumber numberWithInt:i]];
	}
	
	[menuController->fullscreenMenu setSubmenu:fullscreenDeviceMenu];
	[fullscreenWindowItem setSubmenu:[[menu copy] autorelease]];
	
	[menuController->fullscreenMenu setEnabled:YES];
	[fullscreenWindowItem setEnabled:YES];
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
	
	[fullscreenDeviceMenu setStateOfAllItemsTo:NSOffState];
	[[fullscreenWindowItem submenu] setStateOfAllItemsTo:NSOffState];
	
	// index of currently selected device
	int index = [fullscreenDeviceMenu indexOfItemWithRepresentedObject:[NSNumber numberWithInt:[self fullscreenDeviceId]]];
	int state = (fullscreenDeviceId < 0) ? NSMixedState : NSOnState;
	
	if (index != -1) {
		[[fullscreenDeviceMenu itemAtIndex:index] setState:state];
		[[[fullscreenWindowItem submenu] itemAtIndex:index] setState:state];
	}
	
	// select auto entry
	if (fullscreenDeviceId == -2) {
		
		int index = [fullscreenDeviceMenu indexOfItemWithRepresentedObject:[NSNumber numberWithInt:-2]];
		
		[[fullscreenDeviceMenu itemAtIndex:index] setState:NSOnState];
		[[[fullscreenWindowItem submenu] itemAtIndex:index] setState:NSOnState];
	
		// same entry implicit selection
		if ([PREFS integerForKey:MPEGoToFullscreenOn] == MPEGoToFullscreenOnSameScreen) {
			
			int index = [fullscreenDeviceMenu indexOfItemWithRepresentedObject:[NSNumber numberWithInt:-1]];
			
			[[fullscreenDeviceMenu itemAtIndex:index] setState:NSMixedState];
			[[[fullscreenWindowItem submenu] itemAtIndex:index] setState:NSMixedState];
		}
	}
	
	// select same entry
	if (fullscreenDeviceId == -1) {
		
		int index = [fullscreenDeviceMenu indexOfItemWithRepresentedObject:[NSNumber numberWithInt:-1]];
		
		[[fullscreenDeviceMenu itemAtIndex:index] setState:NSOnState];
		[[[fullscreenWindowItem submenu] itemAtIndex:index] setState:NSOnState];
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
- (NSMenu *)contextMenu
{
	NSMenu *context = [[[fullscreenWindowItem menu] copy] autorelease];
	[context removeItemAtIndex:0];
	return context;
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
	
	else if ([keyPath isEqualToString:MPEGoToFullscreenOn] || [keyPath isEqualToString:MPEFullscreenDisplayNumber])
		[self selectFullscreenDevice];
}
/************************************************************************************/
- (void) interface:(MPlayerInterface *)mi hasChangedStateTo:(NSNumber *)statenumber fromState:(NSNumber *)oldstatenumber
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
								@"get_property sub_demux",@"get_property sub_file",
								@"get_property sub_vob",nil]];
	}
	
	// Change of Play/Pause state
	if (!!(stateMask & MIStatePPPlayingMask) != !!(oldStateMask & MIStatePPPlayingMask)) {
		// Playing
		if (stateMask & MIStatePPPlayingMask) {
			// Update interface
			[playButton setImage:pauseImageOff];
			[playButton setAlternateImage:pauseImageOn];
			if ([self isCurrentPlayer])
				[menuController->playMenuItem setTitle:@"Pause"];
		// Pausing
		} else if (stateMask & MIStatePPPausedMask) {
			// Update interface
			[playButton setImage:playImageOff];
			[playButton setAlternateImage:playImageOn];
			if ([self isCurrentPlayer])
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
			[timeTextField setTimestamptWithCurrentTime:0 andTotalTime:0];
			[fullscreenButton setEnabled:NO];
			// Disable stream menus
			[self clearStreamMenus];
			[self clearChapterMenu];
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
				[videoOpenGLView close];
		// Next item already waiting, don't clean up
		} else
			continuousPlayback = NO;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MPEPlaybackStoppedNotification
															object:self];
	}
}
/************************************************************************************/
- (void) interface:(MPlayerInterface *)mi streamUpate:(MovieInfo *)item
{
	[self fillStreamMenus];
}

/************************************************************************************/
- (void) interface:(MPlayerInterface *)mi hasSelectedStream:(NSNumber *)streamId ofType:(NSNumber *)type
{
	// Streams
	if ([type intValue] == MPEStreamTypeVideo)
		[self newVideoStreamId:[streamId intValue]];
	
	else if ([type intValue] == MPEStreamTypeAudio)
		[self newAudioStreamId:[streamId intValue]];
	
	else if ([type intValue] == MPEStreamTypeSubtitleDemux)
		[self newSubtitleStreamId:[streamId intValue] forType:SubtitleTypeDemux];
	
	else if ([type intValue] == MPEStreamTypeSubtitleFile)
		[self newSubtitleStreamId:[streamId intValue] forType:SubtitleTypeFile];
	
	else if ([type intValue] == MPEStreamTypeSubtitleVob)
		[self newSubtitleStreamId:[streamId intValue] forType:SubtitleTypeVob];
}

/************************************************************************************/
- (void) interface:(MPlayerInterface *)mi timeUpdate:(NSNumber *)newTime
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
	
	[timeTextField setTimestamptWithCurrentTime:seconds andTotalTime:[movieInfo length]];
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

// Handle additional keys not set as key equivalent
- (BOOL)handleKeyEvent:(NSEvent *)theEvent
{
	BOOL keyHandled = NO;
	
	NSString *characters = [theEvent characters];
	NSString *uCharacters = [theEvent charactersIgnoringModifiers];
	
	// Volume
	if (keyHandled = [characters isEqualToString:@"m"])
		[self toggleMute:self];
	else if (keyHandled = ([characters isEqualToString:@"9"]
						   || [uCharacters isEqualToString:@"/"]))
		[self decreaseVolume:self];
	else if (keyHandled = ([characters isEqualToString:@"0"]
						   || [uCharacters isEqualToString:@"*"]))
		[self increaseVolume:self];
	
	// All actions below need a playing item
	if (keyHandled || ![myPlayer isMovieOpen])
		return keyHandled;
	
	// Fullscreen
	if (keyHandled = [characters isEqualToString:@"f"])
		[self switchFullscreen:self];
	
	// Playback
	else if (keyHandled = [characters isEqualToString:@"q"])
		[self stop:self];
	else if (keyHandled = [characters isEqualToString:@"p"])
		[self playPause:self];
	else if (keyHandled = ([theEvent keyCode] == kVK_Return))
		[self seekNext:self];
	
	// Cycle Streams
	else if (keyHandled = [characters isEqualToString:@"j"])
		[self cycleSubtitleStreamsWithOSD:YES];
	else if (keyHandled = [characters isEqualToString:@"#"])
		[self cycleAudioStreamsWithOSD:YES];
	
	// Cycle OSD
	else if (keyHandled = [characters isEqualToString:@"o"])
		[self cycleOSD:self];
	
	// Audio Delay
	else if (keyHandled = ([characters isEqualToString:@"+"]
						   || [characters isEqualToString:@"="]))
		[self setAudioDelay:0.1 relative:YES];
	else if (keyHandled = [characters isEqualToString:@"-"])
		[self setAudioDelay:-0.1 relative:YES];
	
	// Subtitle Delay
	else if (keyHandled = [characters isEqualToString:@"x"])
		[self setSubtitleDelay:0.1 relative:YES];
	else if (keyHandled = [characters isEqualToString:@"z"])
		[self setSubtitleDelay:-0.1 relative:YES];
	
	// Playback Speed
	else if (keyHandled = [characters isEqualToString:@"["])
		[self setPlaybackSpeed:0.9091 multiply:YES];
	else if (keyHandled = [characters isEqualToString:@"]"])
		[self setPlaybackSpeed:1.1 multiply:YES];
	else if (keyHandled = [characters isEqualToString:@"{"])
		[self setPlaybackSpeed:0.5 multiply:YES];
	else if (keyHandled = [characters isEqualToString:@"}"])
		[self setPlaybackSpeed:2.0 multiply:YES];
	else if (keyHandled = ([theEvent keyCode] == kVK_Delete))
		[self setPlaybackSpeed:1.0 multiply:NO];
	
	return keyHandled;
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
- (void) playerDidBecomeCurrentPlayer
{
	[self fillStreamMenus];
	[self fillChapterMenu];
	[self fillFullscreenMenu];
	
	[self selectFullscreenDevice];
	[self updateLoopStatus];
	[menuController->toggleMuteMenuItem setState:(self.volume == 0)];
	
	[menuController->playMenuItem setTitle:([myPlayer isPlaying] ? @"Pause" : @"Play")];
}

- (void) playerWillResignCurrentPlayer
{
	[self clearStreamMenus];
	[self clearChapterMenu];
	[self clearFullscreenMenu];
	
	[menuController->loopMenuItem setState:NSOffState];
	[menuController->toggleMuteMenuItem setState:NSOffState];
	
	[menuController->playMenuItem setTitle:@"Play"];
	
	appleRemoteHolding = NO;
}

- (BOOL) isCurrentPlayer
{
	return ([[AppController sharedController] playerController] == self);
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
	
	if ([self isCurrentPlayer])
		[[AppController sharedController] setPlayerController:nil];
	
	[self stop:nil];
	return closeNow;
}

- (void)closeWindowNow:(id)sender {
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
		name: @"MIVideoViewClosed"
		object: videoOpenGLView];
	
	[playerWindow performClose:self];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	if (movieInfo && [[AppController sharedController] movieInfoProvider] != self)
		[[AppController sharedController] setMovieInfoProvider:self];
	
	if (![self isCurrentPlayer])
		[[AppController sharedController] setPlayerController:self];
}


@end
