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
#import "AppController.h"
#import "PlayListController.h"

// custom classes
#import "VideoOpenGLView.h"
#import "VolumeSlider.h"
#import "ScrubbingBar.h"
#include <sys/types.h>
#include <sys/sysctl.h>

#include "AppleRemote.h"

#define		MP_VOLUME_POLL_INTERVAL		10.0f
#define		MP_CHAPTER_CHECK_INTERVAL	0.5f

@implementation PlayerController

/************************************************************************************/
-(void)awakeFromNib
{	
	
	NSUserDefaults *prefs = [appController preferences];
    NSString *playerPath;
	NSString *preflightPlayerPath;
	saveTime = YES;
	fullscreenStatus = NO;	// by default we play in window
	isOntop = NO;
	lastVolumePoll = -MP_VOLUME_POLL_INTERVAL;
	lastChapterCheck = -MP_CHAPTER_CHECK_INTERVAL;
	
	//resize window
	[playerWindow setContentMinSize:NSMakeSize(450, 78)]; // Temp workaround for IB always forgetting the min-size
	[playerWindow setContentSize:[playerWindow contentMinSize] ];
	
	// make window ontop
	if ([prefs integerForKey:@"DisplayType"] == 2)
		[self setOntop:YES];
	
	// set path to mplayer binary
	mplayerPath = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: 
						@"External_Binaries/mplayer.app/Contents/MacOS/mplayer"] retain];
	
	// Temporary: Separate binary for ffmpeg-mt
	mplayerMTPath = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: 
						@"External_Binaries/mplayer-mt.app/Contents/MacOS/mplayer"] retain];
	
	// init player
    playerPath = mplayerPath;
	preflightPlayerPath = mplayerPath;
	
	/* G3 support removed /
	NSString *player_noaltivec = @"External_Binaries/mplayer_noaltivec.app/Contents/MacOS/mplayer";
	
	//check if we have Altivec
    static int hasAltivec = 0;
	static int isIntel = 0;
	static char machine[255];
	
    int selectors[2] = { CTL_HW, HW_MACHINE };
    size_t length = sizeof(machine);
	sysctl(selectors, 2, &machine, &length, NULL, 0);

	if(strcmp(machine,"i386") != 0)
	{
		int selectors_altivec[2] = { CTL_HW, HW_VECTORUNIT };
		length = sizeof(hasAltivec);
		sysctl(selectors_altivec, 2, &hasAltivec, &length, NULL, 0);	
	}
	else
	{
		isIntel = 1;
	}
    
	// choose altivec or not	
    if(hasAltivec)
    {
		playerPath = player;
    }
    else
	{
    	if(isIntel)
        {
            playerPath = player;
        }
        else
        {
            playerPath = player_noaltivec;
        }
	}
	*/
	
    myPlayer = [[MplayerInterface alloc] initWithPathToPlayer: playerPath];
	myPreflightPlayer = [[MplayerInterface alloc] initWithPathToPlayer: preflightPlayerPath];
	
	// register for FFmpeg-MT fail
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(disableFFmpegMTForCurrentFile)
			name: @"MIRestartWithoutFFmpegMT"
			object: myPlayer];
	
	// register for mplayer playback start
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(playbackStarted)
			name: @"MIInfoReadyNotification"
			object:myPlayer];

	// register for mplayer status update
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(statusUpdate:)
			name: @"MIStateUpdatedNotification"
			object:myPlayer];
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(statsUpdate:)
			name: @"MIStatsUpdatedNotification"
			object:myPlayer];

	// register for notification on clicking progress bar
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(progresBarClicked:)
			name: @"SBBarClickedNotification"
			object:scrubbingBar];
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(progresBarClicked:)
			name: @"SBBarClickedNotification"
			object:scrubbingBarToolbar];
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(progresBarClicked:)
			name: @"SBBarClickedNotification"
			object:fcScrubbingBar];
			
    // register for app launch finish
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appFinishedLaunching)
			name: NSApplicationDidFinishLaunchingNotification
			object:NSApp];
	
	// register for pre-app launch finish
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appWillFinishLaunching)
			name: NSApplicationWillFinishLaunchingNotification
			object:NSApp];
	
	// register for app termination notification
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appTerminating)
			name: NSApplicationWillTerminateNotification
			object:NSApp];

	// register for app pre termination notification
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appShouldTerminate)
			name: @"ApplicationShouldTerminateNotification"
			object:NSApp];
	
	// load images
	playImageOn = [[NSImage imageNamed:@"play_button_on"] retain];
	playImageOff = [[NSImage imageNamed:@"play_button_off"] retain];
	pauseImageOn = [[NSImage imageNamed:@"pause_button_on"] retain];
	pauseImageOff = [[NSImage imageNamed:@"pause_button_off"] retain];
	
	fcPlayImageOn = [[NSImage imageNamed:@"fc_play_on"] retain];
	fcPlayImageOff = [[NSImage imageNamed:@"fc_play"] retain];
	fcPauseImageOn = [[NSImage imageNamed:@"fc_pause_on"] retain];
	fcPauseImageOff = [[NSImage imageNamed:@"fc_pause"] retain];
	
	// set up prograss bar
	[scrubbingBar setScrubStyle:NSScrubbingBarEmptyStyle];
	[scrubbingBar setIndeterminate:NO];
	[scrubbingBarToolbar setScrubStyle:NSScrubbingBarEmptyStyle];
	[scrubbingBarToolbar setIndeterminate:NO];
	[fcScrubbingBar setScrubStyle:NSScrubbingBarEmptyStyle];
	[fcScrubbingBar setIndeterminate:NO];
	
	// set mute status and reload unmuted volume
	if ([prefs objectForKey:@"LastAudioVolume"] && [prefs boolForKey:@"LastAudioMute"]) {
		[self setVolume:0];
		muteLastVolume = [prefs floatForKey:@"LastAudioVolume"];
	// set volume to the last used value
	} else if ([prefs objectForKey:@"LastAudioVolume"])
		[self setVolume:[[prefs objectForKey:@"LastAudioVolume"] doubleValue]];
	else
		[self setVolume:50];
	
	[self displayWindow:self];
		
	//setup drag & drop
	[playerWindow registerForDraggedTypes:[NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
	
	// fullscreen device defaults to automatic
	fullscreenDeviceId = -2;
	
	// streams default to unselected
	videoStreamId = -1;
	audioStreamId = -1;
	subtitleDemuxStreamId = -1;
	subtitleFileStreamId = -1;
	
	// fill fullscreen device menu
	[self fillFullscreenMenu];
	[self selectFullscreenDevice];
	
	// request notification for changes to monitor configuration
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(screensDidChange)
			name:NSApplicationDidChangeScreenParametersNotification
			object:NSApp];
	
	// apply prefs to player
	[self applyPrefs];
	
}

- (void) dealloc
{
	[myPlayer release];
	[myPreflightPlayer release];
	
	[mplayerPath release];
	[mplayerMTPath release];
	
	[myPlayingItem release];
	[movieInfo release];
	
	[playImageOn release];
	[playImageOff release];
	[pauseImageOn release];
	[pauseImageOff release];
	
	[fcPlayImageOn release];
	[fcPlayImageOff release];
	[fcPauseImageOn release];
	[fcPauseImageOff release];
	
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
					if ([appController isExtension:[[propertyList objectAtIndex:i] pathExtension] ofType:MP_DIALOG_MEDIA])
						return NSDragOperationCopy; //its a movie file, good
					
					if ([self isPlaying] && [appController isExtension:[[propertyList objectAtIndex:i] pathExtension] ofType:MP_DIALOG_SUBTITLES])
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
	NSMutableDictionary *myItem;

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
						[appController isExtension:[filename pathExtension] ofType:MP_DIALOG_MEDIA]) {
					// create an item from it and play it
					myItem = [NSMutableDictionary dictionaryWithObject:filename forKey:@"MovieFile"];
					[self playItem:myItem];
				} else {
					// load subtitles file
					[myPlayer setSubtitlesFile:filename];
				}
			}
		}
    }
	
	return YES;
}

/************************************************************************************
 INTERFACE
 ************************************************************************************/
- (void) chooseMPlayerBinary
{
	if ((![myPlayingItem objectForKey:@"UseFFmpegMT"]
		 && [[appController preferences] boolForKey:@"UseFFmpegMT"])
		||
		([myPlayingItem objectForKey:@"UseFFmpegMT"]
		 && [[myPlayingItem objectForKey:@"UseFFmpegMT"] boolValue]))
		[myPlayer setPlayerPath:mplayerMTPath];
	else
		[myPlayer setPlayerPath:mplayerPath];
}
/************************************************************************************/
- (void) disableFFmpegMTForCurrentFile
{
	if (myPlayingItem) {
		// Disable FFmpegt-MT
		[myPlayingItem setObject:[NSNumber numberWithBool:NO] forKey:@"UseFFmpegMT"];
		// Restart playback
		[self playItem:myPlayingItem];
	}
}
/************************************************************************************/
- (IBAction)displayWindow:(id)sender;
{
		[playerWindow makeKeyAndOrderFront:nil];
}
/************************************************************************************/
- (void)preflightItem:(NSMutableDictionary *)anItem
{
	// set movie
	[myPreflightPlayer setMovieFile:[anItem objectForKey:@"MovieFile"]];
	// perform preflight
	[myPreflightPlayer loadInfo];
}
/************************************************************************************/
- (void)playItem:(NSMutableDictionary *)anItem
{
	NSString *aPath;
	BOOL loadInfo;
	
	// re-open player window for internal video
	if ([self isInternalVideoOutput] && ![videoOpenGLView isFullscreen] && ![playerWindow isVisible])
		[self displayWindow:self];
	
	// prepare player
	// set movie file
	aPath = [anItem objectForKey:@"MovieFile"];
	if (aPath) {
		// stops mplayer if it is running
		if ([myPlayer isPlaying]) {
			continuousPlayback = YES;	// don't close view
			saveTime = NO;		// don't save time
			[myPlayer stop];
			[playListController updateView];
		}

		if ([[NSFileManager defaultManager] fileExistsAtPath:aPath] ||
				[NSURL URLWithString:aPath]) // if the file exist or it is an URL
			[myPlayer setMovieFile:aPath];
		else {
			NSRunAlertPanel(NSLocalizedString(@"Error",nil), [NSString stringWithFormat:
					NSLocalizedString(@"File %@ could not be found.",nil), aPath],
					NSLocalizedString(@"OK",nil),nil,nil);
			return;
		}
	}
	else {
		aPath = [anItem objectForKey:@"SubtitlesFile"];
		if (aPath)
			[myPlayer setSubtitlesFile:aPath];
		// set encoding from open dialog drop-down
		[myPlayingItem setObject:[anItem objectForKey:@"SubtitlesEncoding"] forKey:@"SubtitlesEncoding"];
		[self setSubtitlesEncoding];
		// restart playback if encoding has changed
		if ([myPlayer changesNeedsRestart])
			[self applyChangesWithRestart:YES];
   		return;
	}
	
	if (myPlayingItem) {
		[myPlayingItem autorelease];
		myPlayingItem = nil;
	}
	if (movieInfo) {
		[movieInfo autorelease];
		movieInfo = nil;
	}
	
	// backup item that is playing
	myPlayingItem = [anItem retain];
	
	// apply item settings
	[self applySettings];
	
	// chose binary to use
	[self chooseMPlayerBinary];
	
	// if monitors aspect ratio is not 4:3 set monitor aspect ratio to the real one
	if ([[NSScreen mainScreen] frame].size.width/4 != 
			[[NSScreen mainScreen] frame].size.height/3) {
		[myPlayer setMonitorAspectRatio:([[NSScreen mainScreen] frame].size.width /
				[[NSScreen mainScreen] frame].size.height)];
    }

	// set video size for case it is set to fit screen so we have to compare
	// screen size with movie size
	[self setMovieSize];

	// set the start of playback
	if ([myPlayingItem objectForKey:@"LastSeconds"])
		[myPlayer seek:[[myPlayingItem objectForKey:@"LastSeconds"] floatValue]
				mode:MIAbsoluteSeekingMode];
	else
		[myPlayer seek:0 mode:MIAbsoluteSeekingMode];
	if (myPlayingItem)
		[myPlayingItem removeObjectForKey:@"LastSeconds"];

	// load info before playback only if it was not previously loaded
	if ([myPlayingItem objectForKey:@"MovieInfo"])
		loadInfo = NO;
	else
		loadInfo = YES;
	[myPlayer loadInfoBeforePlayback:loadInfo];

	// start playback
	if (loadInfo)
		[myPlayer play];
	else
		[myPlayer playWithInfo:[myPlayingItem objectForKey:@"MovieInfo"]];
	
	// its enough to load info only once so disable it
	if (loadInfo)
		[myPlayer loadInfoBeforePlayback:NO];
	
	[playListController updateView];
	
	IOPMAssertionCreate(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, &sleepAssertionId);
}

/************************************************************************************/
- (void) playFromPlaylist:(NSMutableDictionary *)anItem
{
	playingFromPlaylist = YES;
	[self playItem:anItem];
}

/************************************************************************************/
- (void) stopFromPlaylist
{
	[self stop:nil];
	playingFromPlaylist = NO;
	[self cleanUpAfterStop];
}

/************************************************************************************/
- (MplayerInterface *)playerInterface
{
	return myPlayer;
}

- (MplayerInterface *)preflightInterface
{
	return myPreflightPlayer;
}
/************************************************************************************/
- (NSMutableDictionary *) playingItem
{
	if ([myPlayer isRunning])
		return [[myPlayingItem retain] autorelease]; // get it's own retention
	else
		return nil;
}

/************************************************************************************/
- (BOOL) isRunning
{	return [myPlayer isRunning];		}

/************************************************************************************/
- (BOOL) isPlaying
{	
	if ([myPlayer status] != kStopped && [myPlayer status] != kFinished)
		return YES;
	else
		return NO;
}
/************************************************************************************/
- (BOOL) isInternalVideoOutput
{
	NSUserDefaults *preferences = [appController preferences];
	if ([preferences integerForKey:@"VideoDriver"] == 0)
		return YES;
	else
		return NO;
}

/************************************************************************************/
// applay values from preferences to player controller
- (void) applyPrefs
{
	NSUserDefaults *preferences = [appController preferences];
	
	// *** Playback
	
	// audio languages
	if ([[preferences stringForKey:@"AudioLanguages"] length] > 0)
		[myPlayer setAudioLanguages: [preferences stringForKey:@"AudioLanguages"]];
	else
		[myPlayer setAudioLanguages:nil];
	
	// subtitle languages
	if ([[preferences stringForKey:@"SubtitleLanguages"] length] > 0)
		[myPlayer setSubtitleLanguages: [preferences stringForKey:@"SubtitleLanguages"]];
	else
		[myPlayer setSubtitleLanguages:nil];
	
	// cache size
	if ([preferences objectForKey:@"CacheSize"])
		[myPlayer setCacheSize: [[NSNumber numberWithFloat: ([preferences floatForKey:@"CacheSize"] * 1024)] unsignedIntValue]];
	
	
	
	// *** Display
	
	// display type (force to fullscreen if overridden)
	if ([preferences objectForKey:@"DisplayType"])
		[myPlayer setDisplayType: [preferences integerForKey:@"DisplayType"]];
	
	// ontop for internal video
	if ([self isInternalVideoOutput] && [preferences integerForKey:@"DisplayType"] == 2)
		[self setOntop:YES];
	else
		[self setOntop:NO];
	
	// ontop while playing
	if ([preferences objectForKey:@"DisplayType"])
		isOntopWhilePlaying = ([preferences integerForKey:@"DisplayType"] == 5);
	
	// flip vertical
	if ([preferences objectForKey:@"FlipVertical"])
		[myPlayer setFlipVertical: [preferences boolForKey:@"FlipVertical"]];
	
	// flip horizontal
	if ([preferences objectForKey:@"FlipHorizontal"])
		[myPlayer setFlipHorizontal: [preferences boolForKey:@"FlipHorizontal"]];
	
	// set video size
	[self setMovieSize];
	
	// set aspect ratio
	if ([preferences objectForKey:@"VideoAspect"]) {
		switch ([[preferences objectForKey:@"VideoAspect"] intValue]) {
		case 1 :
			[myPlayer setAspectRatio:4.0/3.0];		// 4:3
			break;
		case 2 :
			[myPlayer setAspectRatio:3.0/2.0];		// 3:2
			break;
		case 3 :
			[myPlayer setAspectRatio:5.0/3.0];		// 5:3
			break;
		case 4 :
			[myPlayer setAspectRatio:16.0/9.0];		// 16:9
			break;
		case 5 :
			[myPlayer setAspectRatio:1.85];		// 1.85:1
			break;
		case 6 :
			[myPlayer setAspectRatio:2.93];	// 2.39:1
			break;
		case 7 :
			[myPlayer setAspectRatio:[preferences floatForKey:@"CustomVideoAspectValue"]];
			break;
		default :
			[myPlayer setAspectRatio:0];
			break;
		}
	}
	else
		[myPlayer setAspectRatio:0];
	
	// fullscreen device id for not integrated video window
	if ([[preferences objectForKey:@"VideoDriver"] intValue] != 0) {
		[myPlayer setDeviceId: [self fullscreenDeviceId]];
	}
	
	//vo driver
	if ([preferences objectForKey:@"VideoDriver"])
	{
		switch ([[preferences objectForKey:@"VideoDriver"] intValue]) 
		{
		case 0 :
			[myPlayer setVideoOutModule:2]; // MPlayer OSX
			break;
		case 1 :
			[myPlayer setVideoOutModule:0]; // Quartz / Quicktime
			break;
		case 2 :
			[myPlayer setVideoOutModule:1]; // CoreVideo
			break;
		default :
			[myPlayer setVideoOutModule:2]; // MPlayer OSX
			break;
		}
	}
	else
		[myPlayer setVideoOutModule:2];	// MPlayer OSX
	
	// Screenshot path
	switch ([preferences integerForKey:@"Screenshots"]) {
		case 0: // disabled
			[myPlayer setScreenshotPath:nil];
			break;
		case 1: // desktop
			[myPlayer setScreenshotPath:
				[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
			break;
		case 2: // documents
			[myPlayer setScreenshotPath:
				[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
			break;
		case 3: // home
			[myPlayer setScreenshotPath:NSHomeDirectory()];
			break;
		case 4: // pictures
			[myPlayer setScreenshotPath:[NSHomeDirectory() stringByAppendingString:@"/Pictures"]];
			break;
	}
	
	
	
	// *** Text
	
	// subtitle font
	if ([preferences objectForKey:@"SubtitlesFontName"]) {
		NSString *fontname = [preferences stringForKey:@"SubtitlesFontName"];
		if ([preferences objectForKey:@"SubtitlesStyleName"])
			fontname = [NSString stringWithFormat:@"%@:style=%@", fontname, [preferences stringForKey:@"SubtitlesStyleName"]];
		[myPlayer setFont:fontname];
	} else
		[myPlayer setFont:nil];
	
	// subtitle encoding
	[self setSubtitlesEncoding];
	
	// guess encoding
	if (![preferences boolForKey:@"SubtitlesGuessEncoding"])
		[myPlayer setGuessEncodingLang:nil];
	else
		[myPlayer setGuessEncodingLang:[preferences stringForKey:@"SubtitlesGuessLanguage"]];
	
	// ass subtitles
	if ([preferences objectForKey:@"ASSSubtitles"])
		[myPlayer setAssSubtitles: [preferences boolForKey:@"ASSSubtitles"]];
	
	// subtitle scale
	if ([preferences objectForKey:@"SubtitlesScale"])
		[myPlayer setSubtitlesScale:[preferences integerForKey:@"SubtitlesScale"]];
	
	// embedded fonts
	if ([preferences objectForKey:@"EmbeddedFonts"])
		[myPlayer setEmbeddedFonts: [preferences boolForKey:@"EmbeddedFonts"]];
	
	// ass pre filter
	if ([preferences objectForKey:@"ASSPreFilter"])
		[myPlayer setAssPreFilter: [preferences boolForKey:@"ASSPreFilter"]];
	
	// subtitle color
	if ([preferences objectForKey:@"SubtitlesColor"])
		[myPlayer setSubtitlesColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[preferences objectForKey:@"SubtitlesColor"]]];
	
	// subtitle color
	if ([preferences objectForKey:@"SubtitlesBorderColor"])
		[myPlayer setSubtitlesBorderColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[preferences objectForKey:@"SubtitlesBorderColor"]]];
	
	// osd level
	if ([preferences objectForKey:@"OSDLevel"])
		[myPlayer setOsdLevel:[preferences integerForKey:@"OSDLevel"]];
	
	// osd scale
	if ([preferences objectForKey:@"OSDScale"])
		[myPlayer setOsdScale:[preferences integerForKey:@"OSDScale"]];
	
	
	
	// *** Video
	
	// enable video
	if ([preferences objectForKey:@"EnableVideo"])
		[myPlayer setVideoEnabled: [preferences boolForKey:@"EnableVideo"]];
	
	// video codecs
	if ([[preferences stringForKey:@"VideoCodecs"] length] > 0)
		[myPlayer setVideoCodecs: [preferences stringForKey:@"VideoCodecs"]];
	else
		[myPlayer setVideoCodecs:nil];
	
	// framedrop
	if ([preferences objectForKey:@"Framedrop"])
		[myPlayer setFramedrop: [preferences integerForKey:@"Framedrop"]];
	
	// fast libavcodec decoding
	if ([preferences objectForKey:@"FastLibavcodecDecoding"])
		[myPlayer setFastLibavcodec: [preferences boolForKey:@"FastLibavcodecDecoding"]];
	
	// deinterlace
	if ([preferences objectForKey:@"Deinterlace_r9"])
		[myPlayer setDeinterlace: [preferences integerForKey:@"Deinterlace_r9"]];
	
	// postprocessing
	if ([preferences objectForKey:@"Postprocessing"])
		[myPlayer setPostprocessing: [preferences integerForKey:@"Postprocessing"]];
	
	// skip loopfilter
	if ([preferences objectForKey:@"SkipLoopfilter"])
		[myPlayer setSkipLoopfilter: [preferences integerForKey:@"SkipLoopfilter"]];
	
	
	// *** Audio
	
	// enable audio
	if ([preferences objectForKey:@"EnableAudio"])
		[myPlayer setAudioEnabled: [preferences boolForKey:@"EnableAudio"]];
	
	// audio codecs
	if ([[preferences stringForKey:@"AudioCodecs"] length] > 0)
		[myPlayer setAudioCodecs: [preferences stringForKey:@"AudioCodecs"]];
	else
		[myPlayer setAudioCodecs:nil];
	
	// ac3 passthrough
	if ([preferences objectForKey:@"PassthroughAC3"])
		[myPlayer setAC3Passthrough:[preferences boolForKey:@"PassthroughAC3"]];
	
	// dts passthrough
	if ([preferences objectForKey:@"PassthroughDTS"])
		[myPlayer setDTSPassthrough:[preferences boolForKey:@"PassthroughDTS"]];
	
	// hrtf filter
	if ([preferences objectForKey:@"HRTFFilter"])
		[myPlayer setHRTFFilter: [preferences boolForKey:@"HRTFFilter"]];
	
	// b2bs filter
	if ([preferences objectForKey:@"BS2BFilter"])
		[myPlayer setBS2BFilter: [preferences boolForKey:@"BS2BFilter"]];
	
	// karaoke filter
	if ([preferences objectForKey:@"KaraokeFilter"])
		[myPlayer setKaraokeFilter: [preferences boolForKey:@"KaraokeFilter"]];
	
	
	
	// *** Advanced
	
	// equalizer
	if ([preferences objectForKey:@"AudioEqualizerEnabled"])
		[myPlayer setEqualizerEnabled: [preferences boolForKey:@"AudioEqualizerEnabled"]];
	if ([preferences objectForKey:@"AudioEqualizerValues"])
		[myPlayer setEqualizer: [preferences arrayForKey:@"AudioEqualizerValues"]];
	
	// video software equalizer
	if ([preferences objectForKey:@"VideoEqualizerEnabled"])
		[myPlayer setVideoEqualizerEnabled: [preferences boolForKey:@"VideoEqualizerEnabled"]];
	[self setVideoEqualizer];
	
	// additional params
	if ([preferences objectForKey:@"EnableAdditionalParams"])
		if ([preferences boolForKey:@"EnableAdditionalParams"]
				&& [preferences objectForKey:@"AdditionalParams"]) {
			[myPlayer setAdditionalParams:
					[[[preferences objectForKey:@"AdditionalParams"] objectAtIndex:0]
							componentsSeparatedByString:@" "]];
		}
		else
			[myPlayer setAdditionalParams:nil];
	else
		[myPlayer setAdditionalParams:nil];
	
	// update fullscreen device menu if set to auto
	if (fullscreenDeviceId == -2)
		[self selectFullscreenDevice];
	
}
/************************************************************************************/
- (void) applySettings
{
	NSString *aPath;
	
	// set audio file	
	aPath = [myPlayingItem objectForKey:@"AudioFile"];
	if (aPath) {
		if (![[NSFileManager defaultManager] fileExistsAtPath:aPath])
			NSRunAlertPanel(NSLocalizedString(@"Error",nil), [NSString stringWithFormat:
					NSLocalizedString(@"File %@ could not be found.",nil), aPath],
					NSLocalizedString(@"OK",nil),nil,nil);
		else
			[myPlayer setAudioFile:aPath];
	}
	else
		[myPlayer setAudioFile:nil];
	
	// set subtitles file
	aPath = [myPlayingItem objectForKey:@"SubtitlesFile"];
	if (aPath) {
		if (![[NSFileManager defaultManager] fileExistsAtPath:aPath])
			NSRunAlertPanel(NSLocalizedString(@"Error",nil), [NSString stringWithFormat:
					NSLocalizedString(@"File %@ could not be found.",nil), aPath],
					NSLocalizedString(@"OK",nil),nil,nil);
		else
			[myPlayer setSubtitlesFile:aPath];
	}
	else
		[myPlayer setSubtitlesFile:nil];
	
	// set to rebuild index
	if ([myPlayingItem objectForKey:@"RebuildIndex"]) {
		if ([[myPlayingItem objectForKey:@"RebuildIndex"] isEqualToString:@"YES"])
			[myPlayer setRebuildIndex:YES];
		else
			[myPlayer setRebuildIndex:NO];
	}
	else
		[myPlayer setRebuildIndex:NO];

	// set subtitles encoding only if not default
	[self setSubtitlesEncoding];
}
/************************************************************************************/
- (BOOL) changesRequireRestart
{
	if ([myPlayer isRunning])
		return [myPlayer changesNeedsRestart];
	return NO;
}
/************************************************************************************/
- (BOOL) movieIsSeekable
{
	if ([myPlayer isRunning] && movieInfo)
		return [movieInfo isSeekable];
	return NO;
}
/************************************************************************************/
- (void) applyChangesWithRestart:(BOOL)restart
{
	if ([myPlayer videoOutHasChanged])
		[videoOpenGLView close];
	
	[self chooseMPlayerBinary];
	
	[myPlayer applySettingsWithRestart:restart];
	
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
	NSUserDefaults *preferences = [appController preferences];

	if ([preferences objectForKey:@"VideoSize"]) {
		switch ([[preferences objectForKey:@"VideoSize"] intValue]) {
		case 0 :		// original
			[myPlayer setMovieSize:kDefaultMovieSize];
			[videoOpenGLView setWindowSizeMode:WSM_SCALE withValue:1];
			break;
		case 1 :		// half
			[myPlayer setMovieSize:NSMakeSize(0.5, 0)];
			[videoOpenGLView setWindowSizeMode:WSM_SCALE withValue:0.5];
			break;
		case 2 :		// double
			[myPlayer setMovieSize:NSMakeSize(2, 0)];
			[videoOpenGLView setWindowSizeMode:WSM_SCALE withValue:2];
			break;
		case 3 :		// fit screen it (it is set before actual playback)
			if ([movieInfo videoWidth] && [movieInfo videoHeight]) {
				NSSize screenSize = [[playerWindow screen] visibleFrame].size;
				double theWidth = ((screenSize.height - 28) /	// 28 pixels for window caption
						[movieInfo videoHeight] * [movieInfo videoWidth]);
				if (theWidth < screenSize.width)
					[myPlayer setMovieSize:NSMakeSize(theWidth, 0)];
				else
					[myPlayer setMovieSize:NSMakeSize(screenSize.width, 0)];
			}
			[videoOpenGLView setWindowSizeMode:WSM_FIT_SCREEN withValue:0];
			break;
		case 4 :		// fit width
			if ([preferences objectForKey:@"CustomVideoSize"]) {
				[myPlayer setMovieSize:NSMakeSize([[preferences
						objectForKey:@"CustomVideoSize"] unsignedIntValue], 0)];
				[videoOpenGLView setWindowSizeMode:WSM_FIT_WIDTH withValue:[[preferences objectForKey:@"CustomVideoSize"] floatValue]];
			} else {
				[myPlayer setMovieSize:kDefaultMovieSize];
				[videoOpenGLView setWindowSizeMode:WSM_SCALE withValue:1];
			}
			break;
		default :
			[myPlayer setMovieSize:kDefaultMovieSize];
			break;
		}
	}
	else
		[myPlayer setMovieSize:kDefaultMovieSize];
}
/************************************************************************************/
- (void) setSubtitlesEncoding
{
	NSUserDefaults *preferences = [appController preferences];
	
	if (myPlayingItem && [myPlayingItem objectForKey:@"SubtitlesEncoding"]
			&& ![[myPlayingItem objectForKey:@"SubtitlesEncoding"] isEqualToString:@"None"])
		[myPlayer setSubtitlesEncoding:[myPlayingItem objectForKey:@"SubtitlesEncoding"]];
	
	else if ([preferences objectForKey:@"SubtitlesEncoding"] 
				&& ![[preferences stringForKey:@"SubtitlesEncoding"] isEqualToString:@"None"])
		[myPlayer setSubtitlesEncoding:[preferences objectForKey:@"SubtitlesEncoding"]];
	
	else
		[myPlayer setSubtitlesEncoding:nil];
	
}
/************************************************************************************/
- (void) setVideoEqualizer
{
	NSUserDefaults *preferences = [appController preferences];
	if ([preferences objectForKey:@"VideoEqualizer"]) {
		NSArray *values = [NSArray arrayWithArray:[preferences arrayForKey:@"VideoEqualizer"]];
		
		// Adjust gamma values
		[myPlayer setVideoEqualizer: [NSArray arrayWithObjects: 
			[self gammaValue:[values objectAtIndex:0]],
			[values objectAtIndex:1],
			[values objectAtIndex:2],
			[values objectAtIndex:3],
			[self gammaValue:[values objectAtIndex:4]],
			[self gammaValue:[values objectAtIndex:5]],
			[self gammaValue:[values objectAtIndex:6]],
			[values objectAtIndex:7],
			nil
			]];
	}
}
/************************************************************************************/
- (NSNumber *) gammaValue:(NSNumber *)input
{
	if ([input floatValue] <= 10)
		return [NSNumber numberWithFloat: ([input floatValue] / 10.0)];
	else
		return [NSNumber numberWithFloat: ([input floatValue] - 9.0)];
}
/************************************************************************************
 ACTIONS
 ************************************************************************************/
// Apply volume and send it to mplayer
- (void) setVolume:(double)volume
{
	
	volume = fmin(fmax(volume,0.0),100.0);
	
	[self applyVolume:volume];
	
	[myPlayer setVolume:[[NSNumber numberWithDouble:volume] intValue]];
	[myPlayer applySettingsWithRestart:NO];
}

- (double)volume
{
	return [volumeSlider doubleValue];
}

// Apply volume to images and sliders (don't send it to mplayer)
- (void) applyVolume:(double)volume
{
	
	NSImage *volumeImage;
	
	if (volume > 0)
		[[appController preferences] setObject:[NSNumber numberWithDouble:volume] forKey:@"LastAudioVolume"];
	
	[[appController preferences] setBool:(volume == 0) forKey:@"LastAudioMute"];
		
	
	//set volume icon
	if (volume == 0)
		volumeImage = [[NSImage imageNamed:@"volume0"] retain];
	
	 else if (volume > 66)
		volumeImage = [[NSImage imageNamed:@"volume3"] retain];
	
	else if (volume > 33 && volume < 67)
		volumeImage = [[NSImage imageNamed:@"volume2"] retain];
	
	else if (volume > 0 && volume < 34)
		volumeImage = [[NSImage imageNamed:@"volume1"] retain];
	
	
	[volumeSlider setDoubleValue:volume];
	[volumeSliderToolbar setDoubleValue:volume];
	[volumeButton setImage:volumeImage];
	[volumeButtonToolbar setImage:volumeImage];
	[volumeButton setNeedsDisplay:YES];
	[volumeButtonToolbar setNeedsDisplay:YES];
	
	[fcVolumeSlider setDoubleValue:volume];
	
	[toggleMuteMenu setState:(volume == 0)];
	
	[volumeImage release];
}

// Volume change action from sliders
- (IBAction)changeVolume:(id)sender
{
	
	[self setVolume:[sender doubleValue]];
}

// Volume change from menus
- (IBAction)increaseVolume:(id)sender
{
	
	double newVolume = [[appController preferences] floatForKey:@"LastAudioVolume"] + volumeStep;
	if (newVolume > 100)
		newVolume = 100;
		
	[self setVolume:newVolume];
}

- (IBAction)decreaseVolume:(id)sender
{
	
	double newVolume = [[appController preferences] floatForKey:@"LastAudioVolume"] - volumeStep;
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
	if ([myPlayer status] > 0) {
		[myPlayer pause];				// if playing pause/unpause
		
	}
	else 
	{
		// set the item to play
		if ([playListController indexOfSelectedItem] < 0)
			[playListController selectItemAtIndex:0];
		
		// if it is not set in the prefs by default play in window
		if ([[appController preferences] objectForKey:@"DisplayType"])
		{
			if ([[appController preferences] integerForKey:@"DisplayType"] != 3 
					&& [[appController preferences] integerForKey:@"DisplayType"] != 4)
				[myPlayer setFullscreen:NO];
		}
		
		// play the items
		[self playItem:(NSMutableDictionary *)[playListController selectedItem]];
	}
	[playListController updateView];
}

/************************************************************************************/
- (void) seek:(float)seconds mode:(int)aMode
{
	isSeeking = YES;
	// Tell MPlayer to seek
	[myPlayer seek:seconds mode:aMode];
	// Force recheck of chapters
	lastChapterCheck = -MP_CHAPTER_CHECK_INTERVAL;
}

- (BOOL) isSeeking
{
	return isSeeking;
}

- (float)getSeekSeconds
{
	float seconds = 60;
	if ([NSApp currentEvent]) {
		if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) {
			seconds = 600;
		} else if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) {
			seconds = 10;
		}
	}
	return seconds;
}

- (IBAction)seekBack:(id)sender
{
	
	if ([myPlayer isRunning])
		[self seek:-[self getSeekSeconds] mode:MIRelativeSeekingMode];
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
		[self seek:[self getSeekSeconds] mode:MIRelativeSeekingMode];
	else {
		if ([playListController indexOfSelectedItem] < ([playListController itemCount]-1))
			[playListController selectItemAtIndex:
					([playListController indexOfSelectedItem]+1)];
		else
			[playListController selectItemAtIndex:([playListController itemCount]-1)];
	}
	[playListController updateView];
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
				[playListController finishedPlayingItem:myPlayingItem];
			else
				[self stop:nil];
			//[self seek:100 mode:MIPercentSeekingMode];
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
			[self seek:0 mode:MIPercentSeekingMode];
	}
}

/************************************************************************************/
- (void)skipToNextChapter {
	
	if ([myPlayer isRunning] && movieInfo && [movieInfo chapterCount] >= (currentChapter+1))
		[self goToChapter:(currentChapter+1)];
	else {
		if (playingFromPlaylist)
			[playListController finishedPlayingItem:myPlayingItem];
		else
			[self stop:nil];
		//[self seek:100 mode:MIPercentSeekingMode];
	}
}

- (void)skipToPreviousChapter {
	
	if ([myPlayer isRunning] && movieInfo&& [movieInfo chapterCount] > 0 && currentChapter > 1)
		[self goToChapter:(currentChapter-1)];
	else
		[self seek:0 mode:MIPercentSeekingMode];
}

- (void)goToChapter:(unsigned int)chapter {
	
	// only if playing
	if ([myPlayer isRunning]) {
		
		currentChapter = chapter;
		[myPlayer sendCommand:[NSString stringWithFormat:@"set_property chapter %d 1", currentChapter] withType:MI_CMD_SHOW_COND];
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
				[self seekFwd:nil];
				break;
			// Left: Seek back
            case kRemoteButtonLeft_Hold:
				[self seekBack:nil];
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
        if(appleRemoteHolding)
        {
            // re-schedule event
            [self performSelector:@selector(executeHoldActionForRemoteButton:)
					   withObject:buttonIdentifierNumber
					   afterDelay:0.25];
        }
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
		// Right: Skip forward
        case kRemoteButtonRight:
            [self seekNext:nil];
            break;
		// Left: Skip backward
        case kRemoteButtonLeft:
            [self seekPrevious:nil];
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
		[myPlayer setOntop:YES];
		isOntop = YES;
	}
	else
	{
		[playerWindow setLevel:NSNormalWindowLevel];
		[videoOpenGLView setOntop:NO];
		[myPlayer setOntop:NO];
		isOntop = NO;
	}
}
- (BOOL) isOntop
{
	return isOntop;
}
/************************************************************************************/
- (IBAction)switchFullscreen:(id)sender
{
	BOOL withRestart = NO;
	
	if ([myPlayer status] > 0) {
		
		if (![myPlayer fullscreen]) {
			
			NSUserDefaults *prefs = [appController preferences];
			
			// check if restart is needed (for non-integrated video and changed fullscreen device)
			if ([self fullscreenDeviceId] != [myPlayer getDeviceId] && [prefs integerForKey:@"VideoDriver"] != 0) {
				
				// Ask for restart if current movie is not seekable
				if (movieInfo && ![movieInfo isSeekable]) {
					
					int result = NSRunAlertPanel(@"Alert", @"The fullscreen device id has changed. A restart is required.", @"Cancel", @"Restart", nil);
					
					if(result == 0)
					{
						withRestart = YES;
					} else {
						return;
					}
				
				// Restart if current movie is seekable
				} else {
					
					withRestart = YES;
				}
			}
			
		}
		
		// Set device id for non-integrated video
		if (withRestart) {
			
			[myPlayer setDisplayType:3];
			[myPlayer setDeviceId:[self fullscreenDeviceId]];

		} else {
			
			// if mplayer is playing
			if ([myPlayer fullscreen])
				[myPlayer setFullscreen:NO];
			else
				[myPlayer setFullscreen:YES];
		}
		
		[myPlayer applySettingsWithRestart:withRestart];
	}
}
/************************************************************************************/
- (BOOL) startInFullscreen {
	
	NSUserDefaults *prefs = [appController preferences];
	return ([prefs integerForKey:@"DisplayType"] == 3);
}
/************************************************************************************/
- (int) fullscreenDeviceId {
	
	NSUserDefaults *prefs = [appController preferences];
	
	// Default value from preferences
	if (fullscreenDeviceId == -2) {
		
		if ([prefs integerForKey:@"FullscreenDeviceSameAsPlayer"])
			return [[NSScreen screens] indexOfObject:[playerWindow screen]];
		else if ([prefs integerForKey:@"FullscreenDevice"] < [[NSScreen screens] count])
			return [prefs integerForKey:@"FullscreenDevice"];
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
- (IBAction)displayStats:(id)sender
{
	[myPlayer setUpdateStatistics:YES];
	[statsPanel makeKeyAndOrderFront:self];
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(statsClosed)
			name: NSWindowWillCloseNotification
			object:statsPanel];
}
/************************************************************************************/
- (IBAction)takeScreenshot:(id)sender {
	if ([myPlayer status] > 0) {
		[myPlayer takeScreenshot];
	}
}
/************************************************************************************/
- (void)clearStreamMenus {
	
	NSMenu *menu;
	int j;
	
	for (j = 0; j < 3; j++) {
		
		switch (j) {
			case 0:
				menu = [videoStreamMenu submenu];
				[videoStreamMenu setEnabled:NO];
				break;
			case 1:
				menu = [audioStreamMenu submenu];
				[audioStreamMenu setEnabled:NO];
				[audioCycleButton setEnabled:NO];
				[fcAudioCycleButton setEnabled:NO];
				break;
			case 2:
				menu = [subtitleStreamMenu submenu];
				[subtitleStreamMenu setEnabled:NO];
				[subtitleCycleButton setEnabled:NO];
				[fcSubtitleCycleButton setEnabled:NO];
				break;
		}
		
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
		NSMenu *menu = [videoStreamMenu submenu];
		NSMenuItem* newItem;
		BOOL hasItems = NO;
		
		while ((key = [en nextObject])) {
			newItem = [[NSMenuItem alloc]
					   initWithTitle:[movieInfo descriptionForVideoStream:[key intValue]]
					   action:@selector(videoMenuAction:)
					   keyEquivalent:@""];
			[newItem setRepresentedObject:key];
			[menu addItem:newItem];
			[newItem release];
		}
		
		hasItems = ([menu numberOfItems] > 0);
		[videoStreamMenu setEnabled:hasItems];
		
		// audio stream menu
		en = [movieInfo getAudioStreamsEnumerator];
		menu = [audioStreamMenu submenu];
		
		while ((key = [en nextObject])) {
			newItem = [[NSMenuItem alloc]
					   initWithTitle:[movieInfo descriptionForAudioStream:[key intValue]]
					   action:@selector(audioMenuAction:)
					   keyEquivalent:@""];
			[newItem setRepresentedObject:key];
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
		[audioStreamMenu setEnabled:hasItems];
		[audioWindowMenu setEnabled:hasItems];
		[audioCycleButton setEnabled:([menu numberOfItems] > 1)];
		[fcAudioCycleButton setEnabled:([menu numberOfItems] > 1)];
		
		// subtitle stream menu
		menu = [subtitleStreamMenu submenu];
		
		// Add "disabled" item
		newItem = [[NSMenuItem alloc]
				   initWithTitle:@"Disabled"
				   action:NULL
				   keyEquivalent:@""];
		[newItem setRepresentedObject:[NSArray arrayWithObjects: [NSNumber numberWithInt:SubtitleTypeDemux], 
									   [NSNumber numberWithInt:-1], nil]];
		[newItem setAction:@selector(subtitleMenuAction:)];
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
		[subtitleStreamMenu setEnabled:hasItems];
		[subtitleWindowMenu setEnabled:hasItems];
		[subtitleCycleButton setEnabled:([menu numberOfItems] > 1)];
		[fcSubtitleCycleButton setEnabled:([menu numberOfItems] > 1)];
		
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
	
	[myPlayer sendCommands:[NSArray arrayWithObjects:
							@"set_property switch_audio -2",
							@"get_property switch_audio",
							nil]];
}
- (IBAction)cycleSubtitleStreams:(id)sender {
	
	[myPlayer sendCommands:[NSArray arrayWithObjects:
							@"sub_select",
							@"get_property sub_demux",@"get_property sub_file",
							nil]];
}
/************************************************************************************/
- (void)newVideoStreamId:(int)streamId {
	
	[self disableMenuItemsInMenu:[videoStreamMenu submenu]];
	videoStreamId = -1;
	
	if (streamId != -1) {
		
		videoStreamId = streamId;
		int index = [[videoStreamMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:streamId]];
		
		if (index != -1)
			[[[videoStreamMenu submenu] itemAtIndex:index] setState:NSOnState];
	}
}

- (void)newAudioStreamId:(int)streamId {
	
	[self disableMenuItemsInMenu:[audioStreamMenu submenu]];
	[self disableMenuItemsInMenu:[audioWindowMenu menu]];
	audioStreamId = -1;
	
	if (streamId != -1) {
		
		audioStreamId = streamId;
		int index = [[audioStreamMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:streamId]];
		
		if (index != -1) {
			[[[audioStreamMenu submenu] itemAtIndex:index] setState:NSOnState];
			[[[audioWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
		}
	}
}

- (void)newSubtitleStreamId:(int)streamId forType:(SubtitleType)type {
	
	[self disableMenuItemsInMenu:[subtitleStreamMenu submenu]];
	[self disableMenuItemsInMenu:[subtitleWindowMenu menu]];
	subtitleDemuxStreamId = -1; subtitleFileStreamId = -1;
	
	if (streamId != -1) {
		
		if (type == SubtitleTypeFile)
			subtitleFileStreamId = streamId;
		else
			subtitleDemuxStreamId = streamId;
			
		int index = [[subtitleStreamMenu submenu] indexOfItemWithRepresentedObject:[NSArray arrayWithObjects: [NSNumber numberWithInt:type], [NSNumber numberWithInt:streamId], nil]];
		
		if (index != -1) {
			[[[subtitleStreamMenu submenu] itemAtIndex:index] setState:NSOnState];
			[[[subtitleWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
		}
	
	} else {
		
		[[[subtitleStreamMenu submenu] itemAtIndex:0] setState:NSOnState];
		[[[subtitleWindowMenu menu] itemAtIndex:1] setState:NSOnState];
	}
}

- (void)disableMenuItemsInMenu:(NSMenu *)menu {
	
	NSArray *items = [menu itemArray];
	int i;
	for (i = 0; i < [items count]; i++) {
		[[menu itemAtIndex:i] setState:NSOffState];
	}
}
/************************************************************************************/
- (void)clearChapterMenu {
	
	[chapterMenu setEnabled:NO];
	[chapterWindowMenu setEnabled:NO];
	
	while ([[chapterMenu submenu] numberOfItems] > 0) {
		[[chapterMenu submenu] removeItemAtIndex:0];
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
		NSMenu *menu = [chapterMenu submenu];
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
		[chapterMenu setEnabled:([menu numberOfItems] > 0)];
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
			
			int index = [[chapterMenu submenu] indexOfItemWithRepresentedObject:bestKey];
			
			if (index != -1 && [[[chapterMenu submenu] itemAtIndex:index] state] != NSOnState) {
				
				[self disableMenuItemsInMenu:[chapterMenu submenu]];
				[self disableMenuItemsInMenu:[chapterWindowMenu menu]];
				
				[[[chapterMenu submenu] itemAtIndex:index] setState:NSOnState];
				[[[chapterWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
				currentChapter = [bestKey intValue];
			}
			return;
			
		} else {
			[self disableMenuItemsInMenu:[chapterMenu submenu]];
			[self disableMenuItemsInMenu:[chapterWindowMenu menu]];
		}
		
	}
	
	currentChapter = 0;
}
/************************************************************************************/
- (void)clearFullscreenMenu {
	
	[fullscreenMenu setEnabled:NO];
	[fullscreenWindowMenu setEnabled:NO];
	
	while ([[fullscreenMenu submenu] numberOfItems] > 0) {
		[[fullscreenMenu submenu] removeItemAtIndex:0];
	}
	while ([[fullscreenWindowMenu menu] numberOfItems] > 0) {
		[[fullscreenWindowMenu menu] removeItemAtIndex:0];
	}
}
/************************************************************************************/
- (void)fillFullscreenMenu {
	
	[self clearFullscreenMenu];
	
	NSMenu *menu = [fullscreenMenu submenu];
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
				   initWithTitle:[NSString stringWithFormat:@"Screen %d: %.0fx%.0f", i, [[screens objectAtIndex:i] frame].size.width, [[screens objectAtIndex:i] frame].size.height]
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
		NSMenu *other = [menu copy];
		[other setDelegate:self];
		newItem = [[NSMenuItem alloc]
				   initWithTitle:@""
				   action:NULL
				   keyEquivalent:@""];
		[other insertItem:newItem atIndex:0];
		[newItem release];
		
		[fullscreenWindowMenu setMenu:other];
	}
	
	[fullscreenMenu setEnabled:([menu numberOfItems] > 0)];
	[fullscreenWindowMenu setEnabled:([menu numberOfItems] > 0)];
}
/************************************************************************************/
- (void)fullscreenMenuAction:(id)sender {
	
	NSUserDefaults *prefs = [appController preferences];
	int devid = [[sender representedObject] intValue];
	
	if ([prefs integerForKey:@"VideoDriver"] != 0 && devid != fullscreenDeviceId) {
		
		if ([myPlayer status] > 0 && ![movieInfo isSeekable]) {
			
			int result = NSRunAlertPanel(@"Alert", @"Changing the fullscreen device requires a restart of the playback.", @"Cancel", @"Restart", nil);
			
			if(result != 0)
				return;
		}
		
		[myPlayer setDeviceId:devid];
		[myPlayer applySettingsWithRestart:YES];
	}
	
	if (devid >= -2 && devid < (int)[[NSScreen screens] count]) {
		
		fullscreenDeviceId = devid;
		[self selectFullscreenDevice];
	}
}
/************************************************************************************/
- (void)selectFullscreenDevice {
	
	[self disableMenuItemsInMenu:[fullscreenMenu submenu]];
	[self disableMenuItemsInMenu:[fullscreenWindowMenu menu]];
	
	// index of currently selected device
	int index = [[fullscreenMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:[self fullscreenDeviceId]]];
	int state = (fullscreenDeviceId < 0) ? NSMixedState : NSOnState;
	
	if (index != -1) {
		[[[fullscreenMenu submenu] itemAtIndex:index] setState:state];
		[[[fullscreenWindowMenu menu] itemAtIndex:(index+1)] setState:state];
	}
	
	// select auto entry
	if (fullscreenDeviceId == -2) {
		
		NSUserDefaults *prefs = [appController preferences];
		int index = [[fullscreenMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:-2]];
		
		[[[fullscreenMenu submenu] itemAtIndex:index] setState:NSOnState];
		[[[fullscreenWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
	
		// same entry implicit selection
		if ([prefs boolForKey:@"FullscreenDeviceSameAsPlayer"]) {
			
			int index = [[fullscreenMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:-1]];
			
			[[[fullscreenMenu submenu] itemAtIndex:index] setState:NSMixedState];
			[[[fullscreenWindowMenu menu] itemAtIndex:(index+1)] setState:NSMixedState];
		}
	}
	
	// select same entry
	if (fullscreenDeviceId == -1) {
		
		int index = [[fullscreenMenu submenu] indexOfItemWithRepresentedObject:[NSNumber numberWithInt:-1]];
		
		[[[fullscreenMenu submenu] itemAtIndex:index] setState:NSOnState];
		[[[fullscreenWindowMenu menu] itemAtIndex:(index+1)] setState:NSOnState];
	}
}
/************************************************************************************/
- (void)screensDidChange {
	
	// Reset devide id to preferences value if auto or unavailable
	if (fullscreenDeviceId == -2 || [self fullscreenDeviceId] >= [[NSScreen screens] count]) {
		NSUserDefaults *prefs = [appController preferences];
		fullscreenDeviceId = [prefs integerForKey:@"FullscreenDevice"];
	}
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
- (void) appWillFinishLaunching
{
	// Pass buffer name to interface
	[myPlayer setBufferName:[videoOpenGLView bufferName]];
}
/************************************************************************************/
- (void) appFinishedLaunching
{
	NSUserDefaults *prefs = [appController preferences];
	
	// play the last played movie if it is set to do so
	if ([prefs objectForKey:@"PlaylistRemember"] && [prefs objectForKey:@"LastTrack"]
			&& ![myPlayer isRunning]) {
		if ([prefs boolForKey:@"PlaylistRemember"] && [prefs objectForKey:@"LastTrack"]) {
			[self playItem:(NSMutableDictionary *)[playListController
					itemAtIndex:[[prefs objectForKey:@"LastTrack"] intValue]]];
			[playListController
					selectItemAtIndex:[[prefs objectForKey:@"LastTrack"] intValue]];
		}
	}
	[prefs removeObjectForKey:@"LastTrack"];	
	
}
/************************************************************************************/
- (void) appShouldTerminate
{
	// save values before all is saved to disk and released
	if ([myPlayer status] > 0 && [[appController preferences] objectForKey:@"PlaylistRemember"])
	{
		if ([[appController preferences] boolForKey:@"PlaylistRemember"])
		{
			//[[appController preferences] setObject:[NSNumber numberWithInt:[playListController indexOfItem:myPlayingItem]] forKey:@"LastTrack"];
			
			if (myPlayingItem)
				[myPlayingItem setObject:[NSNumber numberWithFloat:[myPlayer seconds]] forKey:@"LastSeconds"];			
		}
	}
	
	// stop mplayer
	[myPlayer stop];	
}
/************************************************************************************/
// when application is terminating
- (void)appTerminating
{
	// remove observers
	[[NSNotificationCenter defaultCenter] removeObserver:self
			name: @"PlaybackStartNotification" object:myPlayer];
	[[NSNotificationCenter defaultCenter] removeObserver:self
			name: @"MIStateUpdatedNotification" object:myPlayer];
}
/************************************************************************************/
- (void) playbackStarted
{
	// the info dictionary should now be ready to be imported
	if ([myPlayer info] && myPlayingItem) {
		[myPlayingItem setObject:[myPlayer info] forKey:@"MovieInfo"];
		[movieInfo release];
		movieInfo = [[myPlayer info] retain];
	}
	[playListController updateView];
}
/************************************************************************************/
- (void) statsClosed
{
	[myPlayer setUpdateStatistics:NO];
	[[NSNotificationCenter defaultCenter] removeObserver:self
			name: @"NSWindowWillCloseNotification" object:statsPanel];
}
/************************************************************************************/
- (void) statusUpdate:(NSNotification *)notification
{	
	// reset Idle time - Carbon PowerManager calls
//	if ([movieInfo isVideo])	// if there is a video
//		UpdateSystemActivity (UsrActivity);		// do not dim the display
/*	else									// if there's only audio
		UpdateSystemActivity (OverallAct);		// avoid sleeping only
*/
	
	// status did change
	if ([notification userInfo] && [[notification userInfo] objectForKey:@"PlayerStatus"]) {
		NSString *status = @"";
		// status is changing
		// switch Play menu item title and playbutton image
		
		switch ([[[notification userInfo] objectForKey:@"PlayerStatus"] unsignedIntValue]) {
		case kOpening :
		case kBuffering :
		case kIndexing :
		case kPlaying :
			[playButton setImage:pauseImageOff];
			[playButton setAlternateImage:pauseImageOn];
			[playButtonToolbar setImage:pauseImageOff];
			[playButtonToolbar setAlternateImage:pauseImageOn];
			[fcPlayButton setImage:fcPauseImageOff];
			[fcPlayButton setAlternateImage:fcPauseImageOn];
			[playMenuItem setTitle:@"Pause"];
			[stopMenuItem setEnabled:YES];
			[skipBeginningMenuItem setEnabled:YES];
			[skipEndMenuItem setEnabled:YES];
			[fullscreenButton setEnabled:YES];
			if (isOntopWhilePlaying)
				[self setOntop:YES];
			break;
		case kPaused :
		case kStopped :
		case kFinished :
			[playButton setImage:playImageOff];
			[playButton setAlternateImage:playImageOn];
			[playButtonToolbar setImage:playImageOff];
			[playButtonToolbar setAlternateImage:playImageOn];
			[fcPlayButton setImage:fcPlayImageOff];
			[fcPlayButton setAlternateImage:fcPlayImageOn];
			[playMenuItem setTitle:@"Play"];
			[stopMenuItem setEnabled:NO];
			[skipBeginningMenuItem setEnabled:NO];
			[skipEndMenuItem setEnabled:NO];
			[fullscreenButton setEnabled:NO];
			if (isOntopWhilePlaying)
				[self setOntop:NO];
			break;
		}
		
		switch ([[[notification userInfo] objectForKey:@"PlayerStatus"] unsignedIntValue]) {
		case kOpening :
		{
			
			NSMutableString *path = [[NSMutableString alloc] init];
			[path appendString:@"MPlayer OSX Extended - "];
			
			if ([myPlayingItem objectForKey:@"ItemTitle"])
			{
				[path appendString:[myPlayingItem objectForKey:@"ItemTitle"]];
			}
			else 
			{
				[path appendString:[[myPlayingItem objectForKey:@"MovieFile"] lastPathComponent]];
			}

			[playerWindow setTitle:path];
			[path release];
			
			// progress bars
			[scrubbingBar setScrubStyle:NSScrubbingBarProgressStyle];
			[scrubbingBar setIndeterminate:YES];
			[scrubbingBarToolbar setScrubStyle:NSScrubbingBarProgressStyle];
			[scrubbingBarToolbar setIndeterminate:YES];
			[fcScrubbingBar setScrubStyle:NSScrubbingBarProgressStyle];
			[fcScrubbingBar setIndeterminate:YES];
			break;
		}
		case kBuffering :
			status = NSLocalizedString(@"Buffering",nil);
			// progress bars
			[scrubbingBar setScrubStyle:NSScrubbingBarProgressStyle];
			[scrubbingBar setIndeterminate:YES];
			[scrubbingBarToolbar setScrubStyle:NSScrubbingBarProgressStyle];
			[scrubbingBarToolbar setIndeterminate:YES];
			[fcScrubbingBar setScrubStyle:NSScrubbingBarProgressStyle];
			[fcScrubbingBar setIndeterminate:YES];
			break;
		case kIndexing :
			status = NSLocalizedString(@"Indexing",nil);
			// progress bars
			[scrubbingBar setScrubStyle:NSScrubbingBarProgressStyle];
			[scrubbingBar setMaxValue:100];
			[scrubbingBar setIndeterminate:NO];
			[scrubbingBarToolbar setScrubStyle:NSScrubbingBarProgressStyle];
			[scrubbingBarToolbar setMaxValue:100];
			[scrubbingBarToolbar setIndeterminate:NO];
			[fcScrubbingBar setScrubStyle:NSScrubbingBarProgressStyle];
			[fcScrubbingBar setMaxValue:100];
			[fcScrubbingBar setIndeterminate:NO];
			break;
		case kPlaying :
			if (isSeeking) {
				isSeeking = NO;
				break;
			}
			status = NSLocalizedString(@"Playing",nil);
			// set default state of scrubbing bar
			[scrubbingBar setScrubStyle:NSScrubbingBarEmptyStyle];
			[scrubbingBar setIndeterminate:NO];
			[scrubbingBar setMaxValue:100];
			
			[scrubbingBarToolbar setScrubStyle:NSScrubbingBarEmptyStyle];
			[scrubbingBarToolbar setIndeterminate:NO];
			[scrubbingBarToolbar setMaxValue:100];
			
			[fcScrubbingBar setScrubStyle:NSScrubbingBarEmptyStyle];
			[fcScrubbingBar setIndeterminate:NO];
			[fcScrubbingBar setMaxValue:100];
			
			// Populate menus
			[self fillStreamMenus];
			[self fillChapterMenu];
			// Request the selected streams
			[myPlayer sendCommands:[NSArray arrayWithObjects:
									@"get_property switch_video",@"get_property switch_audio",
									@"get_property sub_demux",@"get_property sub_file",nil]];
			
			if ([movieInfo length] > 0) {
				[scrubbingBar setMaxValue: [movieInfo length]];
				[scrubbingBar setScrubStyle:NSScrubbingBarPositionStyle];
				[scrubbingBarToolbar setMaxValue: [movieInfo length]];
				[scrubbingBarToolbar setScrubStyle:NSScrubbingBarPositionStyle];
				[fcScrubbingBar setMaxValue: [movieInfo length]];
				[fcScrubbingBar setScrubStyle:NSScrubbingBarPositionStyle];
			}
			break;
		case kPaused :
			status = NSLocalizedString(@"Paused",nil);
			// stop progress bars
			break;
		case kStopped :
		case kFinished :
			//Set win title
			[playerWindow setTitle:@"MPlayer OSX Extended"];
			// reset status panel
			status = NSLocalizedString(@"N/A",nil);
			[statsCPUUsageBox setStringValue:status];
			[statsCacheUsageBox setStringValue:status];
			[statsAVsyncBox setStringValue:status];
			[statsDroppedBox setStringValue:status];
			[statsPostProcBox setStringValue:status];
			// reset status box
			status = @"";
			[timeTextField setStringValue:@"00:00:00"];
			[timeTextFieldToolbar setStringValue:@"00:00:00"];
			[fcTimeTextField setStringValue:@"00:00:00"];
			// hide progress bars
			[scrubbingBar setScrubStyle:NSScrubbingBarEmptyStyle];
			[scrubbingBar setDoubleValue:0];
			[scrubbingBar setIndeterminate:NO];
			[scrubbingBarToolbar setScrubStyle:NSScrubbingBarEmptyStyle];
			[scrubbingBarToolbar setDoubleValue:0];
			[scrubbingBarToolbar setIndeterminate:NO];
			[fcScrubbingBar setScrubStyle:NSScrubbingBarEmptyStyle];
			[fcScrubbingBar setDoubleValue:0];
			[fcScrubbingBar setIndeterminate:NO];
			// disable stream menus
			[videoStreamMenu setEnabled:NO];
			[audioStreamMenu setEnabled:NO];
			[subtitleStreamMenu setEnabled:NO];
			[audioWindowMenu setEnabled:NO];
			[subtitleWindowMenu setEnabled:NO];
			// release the retained playing item
			/*[myPlayingItem autorelease];
			myPlayingItem = nil;
			[movieInfo autorelease];
			movieInfo = nil;*/
			// update state of playlist
			[playListController updateView];
			// Playlist mode
			if (playingFromPlaylist) {
				// if playback finished itself (not by user) let playListController know
				if ([[[notification userInfo]
						objectForKey:@"PlayerStatus"] unsignedIntValue] == kFinished)
					[playListController finishedPlayingItem:myPlayingItem];
				// close view otherwise
				else if (!continuousPlayback)
					[self stopFromPlaylist];
				else
					continuousPlayback = NO;
			// Regular play mode
			} else {
				if (!continuousPlayback)
					[self cleanUpAfterStop];
				else
					continuousPlayback = NO;
			}
			
			IOPMAssertionRelease(sleepAssertionId);	
			
			break;
		}
		[statsStatusBox setStringValue:status];
		//[statusBox setStringValue:status];
	}
	
	// responses from commands
	if ([notification userInfo]) {
		
		// Streams
		if ([[notification userInfo] objectForKey:@"VideoStreamId"])
			[self newVideoStreamId:[[[notification userInfo] objectForKey:@"VideoStreamId"] intValue]];
		
		if ([[notification userInfo] objectForKey:@"AudioStreamId"])
			[self newAudioStreamId:[[[notification userInfo] objectForKey:@"AudioStreamId"] intValue]];
		
		if ([[notification userInfo] objectForKey:@"SubDemuxStreamId"])
			[self newSubtitleStreamId:[[[notification userInfo] objectForKey:@"SubDemuxStreamId"] intValue] forType:SubtitleTypeDemux];
		
		if ([[notification userInfo] objectForKey:@"SubFileStreamId"])
			[self newSubtitleStreamId:[[[notification userInfo] objectForKey:@"SubFileStreamId"] intValue] forType:SubtitleTypeFile];
		
		if ([[notification userInfo] objectForKey:@"Volume"])
			[self applyVolume:[[[notification userInfo] objectForKey:@"Volume"] doubleValue]];
		
	}
	
	// update values
	switch ([myPlayer status]) {
	case kOpening :
		break;
	case kBuffering :
		if ([statsPanel isVisible])
			[statsCacheUsageBox setStringValue:[NSString localizedStringWithFormat:@"%3.1f %%",
				[myPlayer cacheUsage]]];
		break;
	case kIndexing :
		[scrubbingBar setDoubleValue:[myPlayer cacheUsage]];
		[scrubbingBarToolbar setDoubleValue:[myPlayer cacheUsage]];
		[fcScrubbingBar setDoubleValue:[myPlayer cacheUsage]];
		break;
	case kSeeking :
	case kPlaying :
		// check for stream update
		if ([[notification userInfo] objectForKey:@"StreamsHaveChanged"])
			[self fillStreamMenus];
		[self statsUpdate:notification];
		break;
	case kPaused :
		break;
	}
}
/************************************************************************************/
- (void) statsUpdate:(NSNotification *)notification {
	if ([myPlayer status] == kPlaying || [myPlayer status] == kSeeking) {
		if (myPlayingItem) {
			// update windows
			if ([playerWindow isVisible])
				[self updatePlayerWindow];
			if ([[scrubbingBar window] isVisible])
				[self updatePlaylistWindow];
			if ([fcWindow isVisible])
				[self updateFullscreenControls];
			
			// stats window
			if ([statsPanel isVisible]) {
				[statsCPUUsageBox setStringValue:[NSString localizedStringWithFormat:@"%d %%",
												  [myPlayer cpuUsage]]];
				[statsCacheUsageBox setStringValue:[NSString localizedStringWithFormat:@"%d %%",
													[myPlayer cacheUsage]]];
				[statsAVsyncBox setStringValue:[NSString localizedStringWithFormat:@"%3.1f",
												[myPlayer syncDifference]]];
				[statsDroppedBox setStringValue:[NSString localizedStringWithFormat:@"%d",
												 [myPlayer droppedFrames]]];
				[statsPostProcBox setStringValue:[NSString localizedStringWithFormat:@"%d",
												  [myPlayer postProcLevel]]];
			}
		}
		// poll volume
		double timeDifference = ([NSDate timeIntervalSinceReferenceDate] - lastVolumePoll);
		if (timeDifference >= MP_VOLUME_POLL_INTERVAL) {
			lastVolumePoll = [NSDate timeIntervalSinceReferenceDate];
			[myPlayer sendCommand:@"get_property volume"];
		}
		// check chapters
		timeDifference = ([NSDate timeIntervalSinceReferenceDate] - lastChapterCheck);
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

- (void) updatePlaylistWindow
{
	int seconds = (int)[myPlayer seconds];
	
	if ([movieInfo length] > 0)
		[scrubbingBarToolbar setDoubleValue:seconds];
	else
		[scrubbingBarToolbar setDoubleValue:0];
	
	[timeTextFieldToolbar setStringValue:[NSString stringWithFormat:@"%02d:%02d:%02d", seconds/3600,(seconds%3600)/60,seconds%60]];
}

- (void) updateFullscreenControls
{
	int seconds = (int)[myPlayer seconds];
	
	if ([movieInfo length] > 0)
		[fcScrubbingBar setDoubleValue:seconds];
	else
		[fcScrubbingBar setDoubleValue:0];
	
	[fcTimeTextField setStringValue:[NSString stringWithFormat:@"%02d:%02d:%02d", seconds/3600,(seconds%3600)/60,seconds%60]];
}

/************************************************************************************/
- (void) progresBarClicked:(NSNotification *)notification
{
	if ([myPlayer status] == kPlaying || [myPlayer status] == kPaused || [myPlayer status] == kSeeking) {
		int theMode = MIPercentSeekingMode;
		if ([movieInfo length] > 0)
			theMode = MIAbsoluteSeekingMode;

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

@end
