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

@implementation PlayerController

/************************************************************************************/
-(void)awakeFromNib
{
	NSUserDefaults *prefs = [appController preferences];
    NSString *playerPath;
	saveTime = YES;
	fullscreenStatus = NO;	// by default we play in window
	isOntop = NO;
	
	//resize window 
	[playerWindow setContentSize:[playerWindow contentMinSize] ];
	
	// make window ontop
	if ([prefs integerForKey:@"DisplayType"] == 2)
		[self setOntop:YES];
	
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
	
    NSString *player = @"External_Binaries/mplayer.app/Contents/MacOS/mplayer";
    NSString *player_noaltivec = @"External_Binaries/mplayer_noaltivec.app/Contents/MacOS/mplayer";
    
    // init player
    playerPath = player;
    
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
    
    myPlayer = [[MplayerInterface alloc] initWithPathToPlayer: [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: playerPath]];
	
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

	// register for notification on clicking progress bar
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(progresBarClicked:)
			name: @"SBBarClickedNotification"
			object:scrubbingBar];
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(progresBarClicked:)
			name: @"SBBarClickedNotification"
			object:scrubbingBarToolbar];
			
    // register for app launch finish
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appFinishedLaunching)
			name: NSApplicationDidFinishLaunchingNotification
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
	playImageOff = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"play_button_off"
							ofType:@"png"]];
	playImageOn = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"play_button_on"
							ofType:@"png"]];
	pauseImageOff = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"pause_button_off"
							ofType:@"png"]];
	pauseImageOn = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"pause_button_on"
							ofType:@"png"]];
	
	// set up prograss bar
	[scrubbingBar setStyle:NSScrubbingBarEmptyStyle];
	[scrubbingBar setIndeterminate:NO];
	[scrubbingBarToolbar setStyle:NSScrubbingBarEmptyStyle];
	[scrubbingBarToolbar setIndeterminate:NO];

	// set volume to the last used value
	if ([prefs objectForKey:@"LastAudioVolume"]) {
		[volumeSlider setDoubleValue:[[prefs objectForKey:@"LastAudioVolume"] doubleValue]];
		[volumeSliderToolbar setDoubleValue:[[prefs objectForKey:@"LastAudioVolume"] doubleValue]];
		[myPlayer setVolume:[[prefs objectForKey:@"LastAudioVolume"] intValue]];
	}
	else
	{
		[volumeSlider setDoubleValue:50];
		[volumeSliderToolbar setDoubleValue:50];
		[myPlayer setVolume:50];
	}
	
	[self changeVolume:volumeSlider];
	[self changeVolume:volumeSliderToolbar];

	[self displayWindow:self];
		
	//setup drag & drop
	[playerWindow registerForDraggedTypes:[NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
	
	// apply prefs to player
	[self applyPrefs];

}

/************************************************************************************
 DRAG & DROP
 ************************************************************************************/
 
 /*
	Validate Drop Opperation on player window
 */
- (unsigned int) draggingEntered:(id <NSDraggingInfo>)sender
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
					if ([appController isExtension:[[propertyList objectAtIndex:i] pathExtension] ofType:@"Movie file"])
						return NSDragOperationCopy; //its a movie file, good
			
					if ([appController isExtension:[[propertyList objectAtIndex:i] pathExtension] ofType:@"Audio file"])
						return NSDragOperationCopy; //its an audio file, good
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
				// create an item from it and play it
				myItem = [NSMutableDictionary dictionaryWithObject:filename forKey:@"MovieFile"];
				[self playItem:myItem];
			}
		}
    }
	
	return YES;
}

/************************************************************************************
 INTERFACE
 ************************************************************************************/
- (IBAction)displayWindow:(id)sender;
{
		[playerWindow makeKeyAndOrderFront:nil];
}
/************************************************************************************/
- (BOOL)preflightItem:(NSMutableDictionary *)anItem
{
	BOOL result;
	NSDictionary *theInfo;

	// set movie
	[myPlayer setMovieFile:[anItem objectForKey:@"MovieFile"]];
	// perform preflight
	theInfo = [myPlayer loadInfo];
	
	if (theInfo) {
		[anItem addEntriesFromDictionary:theInfo];
		result = YES;
	}
	else
		result = NO;

	return result;
}

/************************************************************************************/
- (void)playItem:(NSMutableDictionary *)anItem
{
	NSString *aPath;
	BOOL loadInfo;
	
	//[self displayWindow:self];
	
	// prepare player
	// set movie file
	aPath = [anItem objectForKey:@"MovieFile"];
	if (aPath) {
		// stops mplayer if it is running
		if ([myPlayer isRunning]) {
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
   		return;
	}

	// backup item that is playing
	myPlayingItem = [anItem retain];
	
	// apply item settings
	[self applySettings];
	
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
	if ([myPlayingItem objectForKey:@"ID_FILENAME"])
		loadInfo = NO;
	else
		loadInfo = YES;
	[myPlayer loadInfoBeforePlayback:loadInfo];

	// start playback
	[myPlayer play];
	
	// its enough to load info only once so disable it
	if (loadInfo)
		[myPlayer loadInfoBeforePlayback:NO];
		
	[playListController updateView];
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
// applay values from preferences to player controller
- (void) applyPrefs;
{
	NSUserDefaults *preferences = [appController preferences];
	
	// *** Playback
	
	// audio languages
	if ([[preferences stringForKey:@"AudioLanguages"] length] > 0)
		[myPlayer setAduioLanguages: [preferences stringForKey:@"AudioLanguages"]];
	
	// subtitle languages
	if ([[preferences stringForKey:@"SubtitleLanguages"] length] > 0)
		[myPlayer setSubtitleLanguages: [preferences stringForKey:@"SubtitleLanguages"]];
	
	// correct pts
	if ([preferences objectForKey:@"CorrectPTS"])
		[myPlayer setCorrectPTS: [preferences boolForKey:@"CorrectPTS"]];
	
	// cache size
	if ([preferences objectForKey:@"CacheSize"])
		[myPlayer setCacheSize: [[NSNumber numberWithFloat: ([preferences floatForKey:@"CacheSize"] * 1024)] unsignedIntValue]];
	
	
	
	// *** Display
	
	// display type
	if ([preferences objectForKey:@"DisplayType"])
		[myPlayer setDisplayType: [preferences integerForKey:@"DisplayType"]];
	
	// ontop
	if ([preferences integerForKey:@"DisplayType"] == 2)
		[self setOntop:YES];
	else
		[self setOntop:NO];
	
	// flip vertical
	if ([preferences objectForKey:@"FlipVertical"])
		[myPlayer setFlipVertical: [preferences boolForKey:@"FlipVertical"]];
	
	// flip horizontal
	if ([preferences objectForKey:@"FlipHorizontal"])
		[myPlayer setFlipHorizontal: [preferences boolForKey:@"FlipHorizontal"]];
	
	// set video size
	[self setMovieSize];
	
	// set aspect ratio
	if ([preferences objectForKey:@"VideoAspectRatio"]) {
		switch ([[preferences objectForKey:@"VideoAspectRatio"] intValue]) {
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
			// TODO: support x:y input
			[myPlayer setAspectRatio:[[preferences objectForKey:@"CustomVideoAspect"] floatValue]];	// custom
			break;
		default :
			[myPlayer setAspectRatio:0];
			break;
		}
	}
	else
		[myPlayer setAspectRatio:0];
	
	// fullscreen device id
	if ([preferences objectForKey:@"FullscreenDevice"])
		[myPlayer setDeviceId: [preferences integerForKey:@"FullscreenDevice"]];
	
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
	
	// Screenshots
	if ([preferences objectForKey:@"Screenshots"])
		[myPlayer setScreenshotPath: [preferences integerForKey:@"Screenshots"]];
	
	
	
	
	// *** Video
	
	// enable video
	if ([preferences objectForKey:@"EnableVideo"])
		[myPlayer setVideoEnabled: [preferences boolForKey:@"EnableVideo"]];
	
	// video codecs
	if ([[preferences stringForKey:@"VideoCodecs"] length] > 0)
		[myPlayer setVideoCodecs: [preferences stringForKey:@"VideoCodecs"]];
	
	// framedrop
	if ([preferences objectForKey:@"Framedrop"])
		[myPlayer setFramedrop: [preferences integerForKey:@"Framedrop"]];
	
	// fast libavcodec decoding
	if ([preferences objectForKey:@"FastLibavcodecDecoding"])
		[myPlayer setFastLibavcodec: [preferences boolForKey:@"FastLibavcodecDecoding"]];
	
	// deinterlace
	if ([preferences objectForKey:@"Deinterlace"])
		[myPlayer setDeinterlace: [preferences integerForKey:@"Deinterlace"]];
	
	// postprocessing
	if ([preferences objectForKey:@"Postprocessing"])
		[myPlayer setPostprocessing: [preferences integerForKey:@"Postprocessing"]];
	
	// ass subtitles
	if ([preferences objectForKey:@"ASSSubtitles"])
		[myPlayer setAssSubtitles: [preferences boolForKey:@"ASSSubtitles"]];
	
	// embedded fonts
	if ([preferences objectForKey:@"EmbeddedFonts"])
		[myPlayer setEmbeddedFonts: [preferences boolForKey:@"EmbeddedFonts"]];
	
	// subtitle font path
	if ([preferences objectForKey:@"SubtitlesFontName"])
	{
		// if subtitles font is specified, set the font
		[myPlayer setFontFile:[preferences objectForKey:@"SubtitlesFontName"]];
		
		/*if ([[[preferences objectForKey:@"SubtitlesFontPath"] lastPathComponent] caseInsensitiveCompare:@"font.desc"] == NSOrderedSame)
		{
			// if prerendered font selected
			[myPlayer setSubtitlesScale:0];
		}
		else
		{*/
		// if true type font selected
			// set subtitles size
			if ([preferences objectForKey:@"SubtitlesSize"]) {
				switch ([[preferences objectForKey:@"SubtitlesSize"] intValue]) {
				case 0 : 		// smaller
					[myPlayer setSubtitlesScale:3];
					break;
				case 1 : 		// normal
					[myPlayer setSubtitlesScale:4];
					break;
				case 2 :		// larger
					[myPlayer setSubtitlesScale:5];
					break;
				case 3 :		// largest
					[myPlayer setSubtitlesScale:7];
					break;
				default :
					[myPlayer setSubtitlesScale:0];
					break;
				}
			}
		//}
	}
	else {
	// if ther's no subtitles font
		[myPlayer setFontFile:nil];
		[myPlayer setSubtitlesScale:0];
	}

	// subtitle encoding
	[self setSubtitlesEncoding];
	
	// ass pre filter
	if ([preferences objectForKey:@"ASSPreFilter"])
		[myPlayer setAssPreFilter: [preferences boolForKey:@"ASSPreFilter"]];
	
	
	
	// *** Audio
	
	// enable audio
	if ([preferences objectForKey:@"EnableAudio"])
		[myPlayer setAudioEnabled: [preferences boolForKey:@"EnableAudio"]];
	
	// audio codecs
	if ([[preferences stringForKey:@"AudioCodecs"] length] > 0)
		[myPlayer setAudioCodecs: [preferences stringForKey:@"AudioCodecs"]];
	
	// hrtf filter
	if ([preferences objectForKey:@"HRTFFilter"])
		[myPlayer setHRTFFilter: [preferences boolForKey:@"HRTFFilter"]];
	
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
	if ([myPlayingItem objectForKey:@"SubtitlesEncoding"])
		[self setSubtitlesEncoding];
	else
		[myPlayer setSubtitlesEncoding:nil];
}
/************************************************************************************/
- (BOOL) changesRequireRestart
{
	if ([myPlayer isRunning])
		return [myPlayer changesNeedsRestart];
	return NO;
}
/************************************************************************************/
- (void) applyChangesWithRestart:(BOOL)restart
{
	[myPlayer applySettingsWithRestart:restart];	
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
			break;
		case 1 :		// half
			[myPlayer setMovieSize:NSMakeSize(0.5, 0)];
			break;
		case 2 :		// double
			[myPlayer setMovieSize:NSMakeSize(2, 0)];
			break;
		case 3 :		// fit screen it (it is set before actual playback)
			if ([myPlayingItem objectForKey:@"ID_VIDEO_WIDTH"] &&
				[myPlayingItem objectForKey:@"ID_VIDEO_HEIGHT"]) {
				NSSize screenSize = [[NSScreen mainScreen] visibleFrame].size;
				double theWidth = ((screenSize.height - 28) /	// 28 pixels for window caption
						[[myPlayingItem objectForKey:@"ID_VIDEO_HEIGHT"] intValue] *
						[[myPlayingItem objectForKey:@"ID_VIDEO_WIDTH"] intValue]);
				if (theWidth < screenSize.width)
					[myPlayer setMovieSize:NSMakeSize(theWidth, 0)];
				else
					[myPlayer setMovieSize:NSMakeSize(screenSize.width, 0)];
			}
			break;
		case 4 :		// fit width
			if ([preferences objectForKey:@"CustomVideoSize"])
				[myPlayer setMovieSize:NSMakeSize([[preferences
						objectForKey:@"CustomVideoSize"] unsignedIntValue], 0)];
			else
				[myPlayer setMovieSize:kDefaultMovieSize];
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
	if ([preferences objectForKey:@"SubtitlesFontPath"]) {
		if ([[[preferences objectForKey:@"SubtitlesFontPath"] lastPathComponent]
				caseInsensitiveCompare:@"font.desc"] != NSOrderedSame) {
		// if font is not a font.desc font then set subtitles encoding
			if (myPlayingItem) {
				if ([myPlayingItem objectForKey:@"SubtitlesEncoding"])
					[myPlayer setSubtitlesEncoding:[myPlayingItem objectForKey:@"SubtitlesEncoding"]];
				else
					[myPlayer setSubtitlesEncoding:
							[preferences objectForKey:@"SubtitlesEncoding"]];
			}
			else
				[myPlayer setSubtitlesEncoding:
						[preferences objectForKey:@"SubtitlesEncoding"]];
		}
		else
			[myPlayer setSubtitlesEncoding:nil];
	}
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
- (IBAction)changeVolume:(id)sender
{
	NSImage *volumeImage;
	
	[[appController preferences] setObject:[NSNumber numberWithDouble:[sender doubleValue]] forKey:@"LastAudioVolume"];

	//set volume icon
	[sender setDoubleValue:[sender doubleValue]];
	
	if([sender doubleValue] == 0)
		volumeImage = [[NSImage imageNamed:@"volume0"] retain];

	if( ([sender doubleValue] > 66) )
		volumeImage = [[NSImage imageNamed:@"volume3"] retain];
		
	if( ([sender doubleValue] > 33) && ([sender doubleValue] < 67) )
		volumeImage = [[NSImage imageNamed:@"volume2"] retain];

	if( ([sender doubleValue] > 0) && ([sender doubleValue] < 34) )
		volumeImage = [[NSImage imageNamed:@"volume1"] retain];


	[volumeSlider setDoubleValue:[sender doubleValue]];
	[volumeSliderToolbar setDoubleValue:[sender doubleValue]];
	[volumeIconImage setImage:volumeImage];
	[volumeIconImageToolbar setImage:volumeImage];
	[volumeIconImage display];
	[volumeIconImageToolbar display];
	[volumeImage release];
	
	[myPlayer setVolume:[sender intValue]];
	[myPlayer applySettingsWithRestart:NO];
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
- (IBAction)seekBack:(id)sender
{
	if ([myPlayer isRunning])
		[myPlayer seek:-10 mode:MIRelativeSeekingMode];
	else {
		if ([playListController indexOfSelectedItem] < 1)
			[playListController selectItemAtIndex:0];
		else
			[playListController selectItemAtIndex:
					([playListController indexOfSelectedItem]-1)];
	}
	
	[playListController updateView];
}

/************************************************************************************/
- (IBAction)seekFwd:(id)sender
{
	if ([myPlayer isRunning])
		[myPlayer seek:10 mode:MIRelativeSeekingMode];
	else {
		if ([playListController indexOfSelectedItem] < ([playListController itemCount]-1))
			[playListController selectItemAtIndex:
					([playListController indexOfSelectedItem]+1)];
		else
			[playListController selectItemAtIndex:([playListController itemCount]-1)];
	}
	[playListController updateView];
	[myPlayer seek:10 mode:MIRelativeSeekingMode];
}

- (IBAction)seekBegin:(id)sender
{
	if ([myPlayer isRunning])
	{
		[myPlayer seek:0 mode:MIPercentSeekingMode];
	}
}

- (IBAction)seekEnd:(id)sender
{
	if ([myPlayer isRunning])
	{
		[myPlayer seek:100 mode:MIPercentSeekingMode];
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
- (void)setOntop:(BOOL)aBool
{
    if(aBool)
	{
		[playerWindow setLevel:NSScreenSaverWindowLevel];
		isOntop = YES;
	}
	else
	{
		[playerWindow setLevel:NSNormalWindowLevel];
		isOntop = NO;
	}
}
/************************************************************************************/
- (IBAction)switchFullscreen:(id)sender
{
    if ([myPlayer status] > 0) {
		// if mplayer is playing
		if ([myPlayer fullscreen])
			[myPlayer setFullscreen:NO];
		else
			[myPlayer setFullscreen:YES];
		[myPlayer applySettingsWithRestart:NO];
	}
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
/************************************************************************************
 NOTIFICATION OBSERVERS
 ************************************************************************************/
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
	
	[playImageOn release];
	[playImageOff release];
	[pauseImageOn release];
	[pauseImageOff release];
	
	[myPlayer release];
}
/************************************************************************************/
- (void) playbackStarted
{
	// the info dictionary should now be ready to be imported
	if ([myPlayer info] && myPlayingItem) {
		[myPlayingItem addEntriesFromDictionary:[myPlayer info]];
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
- (void) statusUpdate:(NSNotification *)notification;
{
	int seconds;
	NSMutableDictionary *playingItem = myPlayingItem;
	
	// reset Idle time - Carbon PowerManager calls
	if ([playingItem objectForKey:@"ID_VIDEO_FORMAT"])	// if there is a video
		UpdateSystemActivity (UsrActivity);		// do not dim the display
/*	else									// if there's only audio
		UpdateSystemActivity (OverallAct);		// avoid sleeping only
*/
	// status did change
	if ([notification userInfo] && [[notification userInfo] objectForKey:@"PlayerStatus"]) {
		NSString *status = NULL;
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
			break;
		case kPaused :
		case kStopped :
		case kFinished :
			[playButton setImage:playImageOff];
			[playButton setAlternateImage:playImageOn];
			[playButtonToolbar setImage:playImageOff];
			[playButtonToolbar setAlternateImage:playImageOn];
			break;
		}
		switch ([[[notification userInfo] objectForKey:@"PlayerStatus"] unsignedIntValue]) {
		case kOpening :
		{
			NSMutableString *path = [[NSMutableString alloc] init];
			[path appendString:@"MPlayer OSX - "];
			
			if ([playingItem objectForKey:@"ItemTitle"])
			{
				[path appendString:[playingItem objectForKey:@"ItemTitle"]];
			}
			else 
			{
				[path appendString:[[playingItem objectForKey:@"MovieFile"] lastPathComponent]];
			}

			[playerWindow setTitle:path];
			[path release];
	
			// progress bars
			[scrubbingBar setStyle:NSScrubbingBarProgressStyle];
			[scrubbingBar setIndeterminate:YES];
			[scrubbingBarToolbar setStyle:NSScrubbingBarProgressStyle];
			[scrubbingBarToolbar setIndeterminate:YES];
		}
			break;
		case kBuffering :
			status = NSLocalizedString(@"Buffering",nil);
			// progress bars
			[scrubbingBar setStyle:NSScrubbingBarProgressStyle];
			[scrubbingBar setIndeterminate:YES];
			[scrubbingBarToolbar setStyle:NSScrubbingBarProgressStyle];
			[scrubbingBarToolbar setIndeterminate:YES];
			break;
		case kIndexing :
			status = NSLocalizedString(@"Indexing",nil);
			// progress bars
			[scrubbingBar setStyle:NSScrubbingBarProgressStyle];
			[scrubbingBar setMaxValue:100];
			[scrubbingBar setIndeterminate:NO];
			[scrubbingBarToolbar setStyle:NSScrubbingBarProgressStyle];
			[scrubbingBarToolbar setMaxValue:100];
			[scrubbingBarToolbar setIndeterminate:NO];
			break;
		case kPlaying :
			status = NSLocalizedString(@"Playing",nil);
			// set default state of scrubbing bar
			[scrubbingBar setStyle:NSScrubbingBarEmptyStyle];
			[scrubbingBar setIndeterminate:NO];
			[scrubbingBar setMaxValue:100];
			
			[scrubbingBarToolbar setStyle:NSScrubbingBarEmptyStyle];
			[scrubbingBarToolbar setIndeterminate:NO];
			[scrubbingBarToolbar setMaxValue:100];
			
			if ([playingItem objectForKey:@"ID_LENGTH"]) {
				if ([[playingItem objectForKey:@"ID_LENGTH"] intValue] > 0) {
					[scrubbingBar setMaxValue: [[playingItem objectForKey:@"ID_LENGTH"] intValue]];
					[scrubbingBar setStyle:NSScrubbingBarPositionStyle];
					[scrubbingBarToolbar setMaxValue: [[playingItem objectForKey:@"ID_LENGTH"] intValue]];
					[scrubbingBarToolbar setStyle:NSScrubbingBarPositionStyle];
				}
			}
			break;
		case kPaused :
			status = NSLocalizedString(@"Paused",nil);
			// stop progress bars
			break;
		case kStopped :
		case kFinished :
			//Set win title
			[playerWindow setTitle:@"MPlayer OSX"];
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
			// hide progress bars
			[scrubbingBar setStyle:NSScrubbingBarEmptyStyle];
			[scrubbingBar setDoubleValue:0];
			[scrubbingBar setIndeterminate:NO];
			[scrubbingBarToolbar setStyle:NSScrubbingBarEmptyStyle];
			[scrubbingBarToolbar setDoubleValue:0];
			[scrubbingBarToolbar setIndeterminate:NO];
			// release the retained playing item
			[playingItem autorelease];
			myPlayingItem = nil;
			// update state of playlist
			[playListController updateView];
			// if playback finished itself (not by user) let playListController know
			if ([[[notification userInfo]
					objectForKey:@"PlayerStatus"] unsignedIntValue] == kFinished)
				[playListController finishedPlayingItem:playingItem];

			break;
		}
		[statsStatusBox setStringValue:status];
		//[statusBox setStringValue:status];
	}
	
	seconds = (int)[myPlayer seconds];
	
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
		break;
	case kPlaying :
		if ([[scrubbingBar window] isVisible]) 
		{
			if ([playingItem objectForKey:@"ID_LENGTH"])
				if ([[playingItem objectForKey:@"ID_LENGTH"] intValue] > 0)
					[scrubbingBar setDoubleValue:[myPlayer seconds]];
				else
					[scrubbingBar setDoubleValue:0];
			else
				[scrubbingBar setDoubleValue:0];
		}
		if ([[scrubbingBarToolbar window] isVisible]) 
		{
			if ([playingItem objectForKey:@"ID_LENGTH"])
				if ([[playingItem objectForKey:@"ID_LENGTH"] intValue] > 0)
					[scrubbingBarToolbar setDoubleValue:[myPlayer seconds]];
				else
					[scrubbingBarToolbar setDoubleValue:0];
			else
				[scrubbingBarToolbar setDoubleValue:0];
		}
		if ([[timeTextField window] isVisible])
		{
				[timeTextField setStringValue:[NSString stringWithFormat:@"%02d:%02d:%02d", seconds/3600,(seconds%3600)/60,seconds%60]];
		}
		if ([[timeTextFieldToolbar window] isVisible])
		{
				[timeTextFieldToolbar setStringValue:[NSString stringWithFormat:@"%02d:%02d:%02d", seconds/3600,(seconds%3600)/60,seconds%60]];
		}
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
		break;
	case kPaused :
		break;
	}
}

/************************************************************************************/
- (void) progresBarClicked:(NSNotification *)notification
{
	if ([myPlayer status] == kPlaying || [myPlayer status] == kPaused) {
		int theMode = MIPercentSeekingMode;
		if ([myPlayingItem objectForKey:@"ID_LENGTH"])
			if ([[myPlayingItem objectForKey:@"ID_LENGTH"] floatValue] != 0)
				theMode = MIAbsoluteSeekingMode;

		[myPlayer seek:[[[notification userInfo] 
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
	[self stop:nil];
	return YES;
}

@end
