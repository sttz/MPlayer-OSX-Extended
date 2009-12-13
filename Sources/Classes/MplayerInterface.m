/*
 *  MplayerInterface.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "MplayerInterface.h"
#import "RegexKitLite.h"
#import <sys/sysctl.h>

#import "AppController.h"
#import "PreferencesController2.h"
#import "EqualizerController.h"
#import "Preferences.h"
#import "CocoaAdditions.h"

#import <objc/runtime.h>

// directly parsed mplayer output strings
// strings that are used to get certain data from output are not included
#define MI_PAUSED_STRING			"ID_PAUSED"
#define MI_OPENING_STRING			"Playing "
#define MI_AUDIO_FILE_STRING		"Audio file detected."
#define MI_STARTING_STRING			"Starting playback..."

#define MI_DEFINE_REGEX				@"^ID_(.*)=(.*)$"
#define MI_REPLY_REGEX				@"^ANS_(.*)=(.*)$"
#define MI_STREAM_REGEX				@"^ID_(.*)_(\\d+)_(.*)=(.*)$"
#define MI_MKVCHP_REGEX				@"^\\[mkv\\] Chapter (\\d+) from (\\d+):(\\d+):(\\d+\\.\\d+) to (\\d+):(\\d+):(\\d+\\.\\d+), (.+)$"
#define MI_EXIT_REGEX				@"^ID_EXIT=(.*)$"
#define MI_NEWLINE_REGEX			@"(?:\r\n|[\n\v\f\r\302\205\\p{Zl}\\p{Zp}])"

#define MI_STATS_UPDATE_INTERVAL	0.2f // Stats update interval when playing
#define MI_SEEK_UPDATE_INTERVAL		0.1f // Stats update interval while seeking

#define MI_LAVC_MAX_THREADS			8

// run loop modes in which we parse MPlayer's output
static NSArray* parseRunLoopModes;

// video equalizer keys to command mapping
static NSDictionary *videoEqualizerCommands;

@implementation MplayerInterface
@synthesize playing, movieOpen, state;

/************************************************************************************
 INIT & UNINIT
 ************************************************************************************/
- (id)init
{
	if (!(self = [super init]))
		return  nil;
	
	if (!parseRunLoopModes)
		parseRunLoopModes = [[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil] retain];
	
	if (!videoEqualizerCommands)
		videoEqualizerCommands = [[NSDictionary dictionaryWithObjectsAndKeys:
								   @"brightness", MPEVideoEqualizerBrightness,
								   @"contrast", MPEVideoEqualizerContrast,
								   @"gamma", MPEVideoEqualizerGamma,
								   @"hue", MPEVideoEqualizerHue,
								   @"saturation", MPEVideoEqualizerSaturation,
								   nil] retain];;
	
	// detect 64bit host
	int is64bit;
	size_t len = sizeof(is64bit);
	if (!sysctlbyname("hw.optional.x86_64",&is64bit,&len,NULL,0))
		is64bitHost = (BOOL)is64bit;
	
	buffer_name = @"mplayerosx";
	
	clients = [NSMutableArray new];
	
	myCommandsBuffer = [NSMutableArray new];
	mySeconds = 0;
	
	// *** playback
	// addParams
	
	// *** display
	screenshotPath = nil;
	
	// *** text
	osdLevel = 1;

	myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
	restartingPlayer = NO;
	pausedOnRestart = NO;
	isRunning = NO;
	myOutputReadMode = 0;
	myUpdateStatistics = NO;
	isPreflight = NO;
		
	// Disable MPlayer AppleRemote code unconditionally, as it causing problems 
	// when MPlayer runs in background only and we provide our own AR implementation.
	disableAppleRemote = YES;
	
	// Watch for framedrop changes
	[PREFS addObserver:self
			forKeyPath:MPEDropFrames
			   options:NSKeyValueObservingOptionNew
			   context:nil];
	
	// Watch for osd level changes
	[PREFS addObserver:self
			forKeyPath:MPEOSDLevel
			   options:NSKeyValueObservingOptionNew
			   context:nil];
	
	// Watch for video equalizer changes
	[PREFS addObserver:self
			forKeyPath:MPEVideoEqualizerValues
			   options:NSKeyValueObservingOptionNew
			   context:nil];
	
	return self;
}

/************************************************************************************/
// release any retained objects
- (void) dealloc
{
	[clients release];
	[myMplayerTask release];
	[myPathToPlayer release];
	[myCommandsBuffer release];
	[lastUnparsedLine release];
	[lastUnparsedErrorLine release];
	[buffer_name release];
	[prefs release];
	[screenshotPath release];
	[localPrefs release];
	[playingItem release];
	
	[super dealloc];
}
/************************************************************************************/
- (void) setBufferName:(NSString *)name
{
	[buffer_name release];
	buffer_name = [name retain];
}
/************************************************************************************/
- (void) addClient:(id<MplayerInterfaceClientProtocol>)client
{
	[clients addObject:client];
	// send initial state update
	[self notifyClientsWithSelector:@selector(interface:hasChangedStateTo:fromState:)
						  andObject:[NSNumber numberWithUnsignedInt:state]
						  andObject:[NSNumber numberWithUnsignedInt:MIStateInitializing]];
	// send initial time update
	[self notifyClientsWithSelector:@selector(interface:timeUpdate:)
						  andObject:[NSNumber numberWithFloat:mySeconds]];
	// send initial volume update
	[self notifyClientsWithSelector:@selector(interface:volumeUpdate:)
						  andObject:[[playingItem prefs] objectForKey:MPEAudioVolume]];
}

- (void) removeClient:(id<MplayerInterfaceClientProtocol>)client
{
	[clients removeObject:client];
}

- (void) notifyClientsWithSelector:(SEL)selector andObject:(id)object
{
	for (id<MplayerInterfaceClientProtocol> client in clients) {
		if (client && [client respondsToSelector:selector]) {
			[client performSelector:selector withObject:self withObject:object];
		}
	}
}

- (void) notifyClientsWithSelector:(SEL)selector andObject:(id)object andObject:(id)otherObject
{
	// Creating a method signature for a protocol is unfortunately not supported by Cocoa
	struct objc_method_description desc = protocol_getMethodDescription(@protocol(MplayerInterfaceClientProtocol),
																		selector, NO, YES);
	if (!desc.name)
		return;
	NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:desc.types];
	performer = [NSInvocation invocationWithMethodSignature:sig];
	
	[performer setSelector:selector];
	[performer setArgument:&self atIndex:2];
	[performer setArgument:&object atIndex:3];
	[performer setArgument:&otherObject atIndex:4];
	
	for (id<MplayerInterfaceClientProtocol> client in clients) {
		if (client && [client respondsToSelector:selector]) {
			[performer invokeWithTarget:client];
		}
	}
}

/************************************************************************************/
- (void)registerPlayingItem:(MovieInfo *)item
{
	if (playingItem && playingItem != item)
		[self unregisterPlayingItem];
	
	playingItem = [item retain];
	
	[[playingItem prefs] addObserver:self
						  forKeyPath:MPELoopMovie
							 options:0
							 context:nil];
	
	[[playingItem prefs] addObserver:self
						  forKeyPath:MPEAudioVolume
							 options:0
							 context:nil];
	
	[[playingItem prefs] addObserver:self
						  forKeyPath:MPEAudioMute
							 options:0
							 context:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(loadNewSubtitleFile:)
												 name:MPEMovieInfoAddedExternalSubtitleNotification
											   object:playingItem];
}

- (void)unregisterPlayingItem
{
	[[playingItem prefs] removeObserver:self forKeyPath:MPELoopMovie];
	[[playingItem prefs] removeObserver:self forKeyPath:MPEAudioVolume];
	[[playingItem prefs] removeObserver:self forKeyPath:MPEAudioMute];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:MPEMovieInfoAddedExternalSubtitleNotification
												  object:playingItem];
	
	[playingItem release];
	playingItem = nil;
}

/************************************************************************************
 PLAYBACK CONTROL
 ************************************************************************************/
- (void) playItem:(MovieInfo *)item
{
	NSMutableArray *params = [NSMutableArray array];
	NSMutableArray *videoFilters = [NSMutableArray array];
	NSMutableArray *audioFilters = [NSMutableArray array];
	NSMutableArray *audioCodecsArr = [NSMutableArray array];
	
	// register/unregister observers for local values
	if (item) {
		if (playingItem && playingItem != item)
			[self unregisterPlayingItem];
		if (!playingItem)
			[self registerPlayingItem:item];
	}
	
	// copy preferences to keep track of changes
	[prefs release];
	prefs = [[PREFS dictionaryRepresentation] copy];
	
	// copy local preferences
	if (item) {
		[localPrefs release];
		localPrefs = [[item prefs] copy];
	}
	
	// combine global and local preferences
	NSMutableDictionary *cPrefs = [NSMutableDictionary dictionary];
	[cPrefs addEntriesFromDictionary:prefs];
	[cPrefs addEntriesFromDictionary:localPrefs];
	
	// Detect number of cores/cpus
	size_t len = sizeof(numberOfThreads);
	if (sysctlbyname("hw.ncpu",&numberOfThreads,&len,NULL,0))
		numberOfThreads = 1;
	if (numberOfThreads > MI_LAVC_MAX_THREADS)
		numberOfThreads = MI_LAVC_MAX_THREADS;
	
	// force using 32bit arch of binary
	force32bitBinary = NO;
	if (is64bitHost && [prefs boolForKey:MPEUse32bitBinaryon64bit]) {
		NSDictionary *binaryInfo = [[[AppController sharedController] preferencesController] binaryInfo];
		NSDictionary *thisInfo = [binaryInfo objectForKey:[cPrefs objectForKey:MPESelectedBinary]];
		if ([[thisInfo objectForKey:@"MPEBinaryArchs"] containsObject:@"i386"])
			force32bitBinary = YES;
	}
	
	// *** FILES
	
	// add movie file
	if ([[[playingItem filename] lastPathComponent] isEqualToString:@"VIDEO_TS"]) {
		[params addObject:@"dvd://"];
		[params addObject:@"-dvd-device"];
	}
	[params addObject:[playingItem filename]];
	
	// add subtitles file
	if ([[playingItem externalSubtitles] count] > 0) {
		[params addObject:@"-sub"];
		[params addObject:[[playingItem externalSubtitles] componentsJoinedByString:@","]];
	}
	else {
		//[params addObject:@"-noautosub"];
	}
	
	
	// *** PLAYBACK
	
	// audio languages
	if ([cPrefs objectForKey:MPEDefaultAudioLanguages]) {
		NSArray *audioLangs = [cPrefs arrayForKey:MPEDefaultAudioLanguages];
		if ([audioLangs count] > 0) {
			[params addObject:@"-alang"];
			[params addObject:[[LanguageCodes sharedInstance] mplayerArgumentFromArray:audioLangs]];
		}
	}
	
	// subtitle languages
	if ([cPrefs objectForKey:MPEDefaultSubtitleLanguages]) {
		NSArray *subtitleLangs = [cPrefs arrayForKey:MPEDefaultSubtitleLanguages];
		if ([subtitleLangs count] > 0) {
			[params addObject:@"-slang"];
			[params addObject:[[LanguageCodes sharedInstance] mplayerArgumentFromArray:subtitleLangs]];
		}
	}
	
	
	// *** PLAYBACK
	
	// cache settings
	if ([cPrefs floatForKey:MPECacheSizeInMB] > 0) {
		[params addObject:@"-cache"];
		[params addObject:[NSString stringWithFormat:@"%d",
						   (int)([cPrefs floatForKey:MPECacheSizeInMB] * 1024)]];
	} else
		[params addObject:@"-nocache"];
	
	// number of threads
	if (numberOfThreads > 0) {
		[params addObject:@"-lavdopts"];
		[params addObject:[NSString stringWithFormat:@"threads=%d",numberOfThreads]];
	}
	
	// rootwin
	if ([cPrefs integerForKey:MPEStartPlaybackDisplayType] == MPEStartPlaybackDisplayTypeDesktop) {
		[params addObject:@"-rootwin"];
		[params addObject:@"-fs"];
	}
	
	// flip vertical
	if ([cPrefs boolForKey:MPEFlipDisplayVertically]) {
		[videoFilters addObject:@"flip"];
	}
	// flip horizontal
	if ([cPrefs boolForKey:MPEFlipDisplayHorizontally]) {
		[videoFilters addObject:@"mirror"];
	}
	
	// select video out (if video is enabled and not playing in rootwin)
	if ([cPrefs integerForKey:MPEStartPlaybackDisplayType] != MPEStartPlaybackDisplayTypeDesktop
			&& [cPrefs boolForKey:MPEEnableVideo]) {
		[params addObject:@"-vo"];
		[params addObject:[NSString stringWithFormat:@"corevideo:buffer_name=%@",buffer_name]];
	}
	
	
	// *** TEXT
	
	// add font
	if ([cPrefs objectForKey:MPEFont]) {
		NSString *fcPattern = [cPrefs stringForKey:MPEFont];
		if ([cPrefs stringForKey:MPEFontStyle])
			fcPattern = [NSString stringWithFormat:@"%@:style=%@", fcPattern, [cPrefs stringForKey:MPEFontStyle]];
		[params addObject:@"-font"];
		[params addObject:fcPattern];
	}
	
	// guess encoding with enca
	if ([cPrefs objectForKey:MPEGuessTextEncoding] && 
			![[cPrefs stringForKey:MPEGuessTextEncoding] isEqualToString:@"disabled"]) {
		NSString *subEncoding = [cPrefs stringForKey:MPETextEncoding];
		if (!subEncoding)
			subEncoding = @"none";
		[params addObject:@"-subcp"];
		[params addObject:[NSString stringWithFormat:@"enca:%@:%@", 
						   [cPrefs stringForKey:MPEGuessTextEncoding], subEncoding]];
	// fix encoding
	} else if ([cPrefs objectForKey:MPETextEncoding]
			   && ![[cPrefs stringForKey:MPETextEncoding] isEqualToString:@"None"]) {
		[params addObject:@"-subcp"];
		[params addObject:[cPrefs objectForKey:MPETextEncoding]];
	}
	
	// *** TEXT
	
	// enable ass subtitles
	[params addObject:@"-ass"];
	
	// subtitles scale
	if ([cPrefs floatForKey:MPESubtitleScale] > 0) {
		[params addObject:@"-ass-font-scale"];
		[params addObject:[NSString stringWithFormat:@"%.3f",[cPrefs floatForKey:MPESubtitleScale]]];
	}
	
	// embedded fonts
	if ([cPrefs boolForKey:MPELoadEmbeddedFonts]) {
		[params addObject:@"-embeddedfonts"];
	}
	
	// ass pre filter
	if ([cPrefs boolForKey:MPERenderSubtitlesFirst]) {
		[videoFilters insertObject:@"ass" atIndex:0];
	}
	
	// subtitles color
	NSColor *textColor;
	if (textColor = [cPrefs colorForKey:MPESubtitleTextColor]) {
		CGFloat red, green, blue, alpha;
		[textColor getRed:&red green:&green blue:&blue alpha:&alpha];
		[params addObject:@"-ass-color"];
		[params addObject:[NSString stringWithFormat:@"%02X%02X%02X%02X",(unsigned)(red*255),(unsigned)(green*255),(unsigned)(blue*255),(unsigned)((1-alpha)*255)]];
	}
	// subtitles color
	NSColor *borderColor;
	if (borderColor = [cPrefs colorForKey:MPESubtitleBorderColor]) {
		CGFloat red, green, blue, alpha;
		[borderColor getRed:&red green:&green blue:&blue alpha:&alpha];
		[params addObject:@"-ass-border-color"];
		[params addObject:[NSString stringWithFormat:@"%02X%02X%02X%02X",(unsigned)(red*255),(unsigned)(green*255),(unsigned)(blue*255),(unsigned)((1-alpha)*255)]];
	}
	
	if ([cPrefs objectForKey:MPEOSDLevel]) {
		osdLevel = [cPrefs integerForKey:MPEOSDLevel];
		if (osdLevel != 1 && osdLevel != 2) {
			[params addObject:@"-osdlevel"];
			[params addObject:[NSString stringWithFormat:@"%i",(osdLevel == 0 ? 0 : osdLevel - 1)]];
		}
	}
	
	// subtitles scale
	if ([cPrefs floatForKey:MPEOSDScale] > 0) {
		[params addObject:@"-subfont-osd-scale"];
		[params addObject:[NSString stringWithFormat:@"%.3f",[cPrefs floatForKey:MPEOSDScale]*6.0]];
	}
	
	
	// *** VIDEO
	
	// disable video
	if (![cPrefs boolForKey:MPEEnableVideo]) {
		[params addObject:@"-vc"];
		[params addObject:@"null"];
		[params addObject:@"-vo"];
		[params addObject:@"null"];
	// video codecs
	} else if ([cPrefs stringForKey:MPEOverrideVideoCodecs]) {
		[params addObject:@"-vc"];
		[params addObject:[cPrefs stringForKey:MPEOverrideVideoCodecs]];
	}
	
	// framedrop
	if ([cPrefs objectForKey:MPEDropFrames]) {
		int dropFrames = [cPrefs integerForKey:MPEDropFrames];
		if (dropFrames == MPEDropFramesSoft)
			[params addObject:@"-framedrop"];
		else if (dropFrames == MPEDropFramesHard)
			[params addObject:@"-hardframedrop"];
	}
	
	// fast decoding
	if ([cPrefs boolForKey:MPEFastDecoding]) {
		[params addObject:@"-lavdopts"];
		[params addObject:@"fast:skiploopfilter=all"];
	}
	
	// deinterlace
	if ([cPrefs objectForKey:MPEDeinterlaceFilter]) {
		int deinterlace = [cPrefs integerForKey:MPEDeinterlaceFilter];
		if (deinterlace == MPEDeinterlaceFilterYadif)
			[videoFilters addObject:@"yadif=1"];
		else if (deinterlace == MPEDeinterlaceFilterKernel)
			[videoFilters addObject:@"kerndeint"];
		else if (deinterlace == MPEDeinterlaceFilterFFmpeg)
			[videoFilters addObject:@"pp=fd"];
		else if (deinterlace == MPEDeinterlaceFilterFilm)
			[videoFilters addObject:@"filmdint"];
		else if (deinterlace == MPEDeinterlaceFilterBlend)
			[videoFilters addObject:@"pp=lb"];
	}
	
	// postprocessing
	if ([cPrefs objectForKey:MPEPostprocessingFilter]) {
		int postprocessing = [cPrefs integerForKey:MPEPostprocessingFilter];
		if (postprocessing == MPEPostprocessingFilterDefault)
			[videoFilters addObject:@"pp=default"];
		else if (postprocessing == MPEPostprocessingFilterFast)
			[videoFilters addObject:@"pp=fast"];
		else if (postprocessing == MPEPostprocessingFilterHighQuality)
			[videoFilters addObject:@"pp=ac"];
	}
	
	
	// *** AUDIO
	
	// disable audio
	if (![cPrefs boolForKey:MPEEnableAudio])
		[params addObject:@"-nosound"];
	// audio codecs
	else if ([cPrefs stringForKey:MPEOverrideAudioCodecs]) {
		[audioCodecsArr addObject:[cPrefs stringForKey:MPEOverrideAudioCodecs]];
	}
	
	// ac3/dts passthrough
	if ([cPrefs boolForKey:MPEHardwareAC3Passthrough]) {
		[audioCodecsArr insertObject:@"hwac3" atIndex:0];
	}
	if ([cPrefs boolForKey:MPEHardwareDTSPassthrough]) {
		[audioCodecsArr insertObject:@"hwdts" atIndex:0];
	}
	
	// hrtf filter
	if ([cPrefs boolForKey:MPEHRTFFilter]) {
		[audioFilters addObject:@"resample=48000"];
		[audioFilters addObject:@"hrtf"];
	}
	// bs2b filter
	if ([cPrefs boolForKey:MPEBS2BFilter]) {
		[audioFilters addObject:@"bs2b"];
	}
	// karaoke filter
	if ([cPrefs boolForKey:MPEKaraokeFilter]) {
		[audioFilters addObject:@"karaoke"];
	}
	
	// set initial volume
	if ([cPrefs objectForKey:MPEAudioVolume] && ![cPrefs boolForKey:MPEAudioMute]) {
		[params addObject:@"-volume"];
		[params addObject:[NSString stringWithFormat:@"%.2f", [cPrefs floatForKey:MPEAudioVolume]]];	
	} else if ([cPrefs boolForKey:MPEAudioMute]) {
		[params addObject:@"-volume"];
		[params addObject:@"0"];
	}
	
	
	// *** ADVANCED
	
	// *** Video filters
	// add screenshot filter
	if ([cPrefs objectForKey:MPEScreenshotSaveLocation]) {
		int screenshot = [cPrefs integerForKey:MPEScreenshotSaveLocation];
		
		if (screenshot != MPEScreenshotsDisabled) {
			[videoFilters addObject:@"screenshot"];
			
			[screenshotPath release];
			
			if (screenshot == MPEScreenshotSaveLocationCustom
					&& [cPrefs stringForKey:MPECustomScreenshotsSavePath])
				screenshotPath = [cPrefs stringForKey:MPECustomScreenshotsSavePath];
			
			else if (screenshot == MPEScreenshotSaveLocationHomeFolder)
				screenshotPath = NSHomeDirectory();
			
			else if (screenshot == MPEScreenshotSaveLocationDocumentsFolder)
				screenshotPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) 
									objectAtIndex:0];
			
			else if (screenshot == MPEScreenshotSaveLocationPicturesFolder)
				screenshotPath = [NSHomeDirectory() stringByAppendingString:@"/Pictures"];
			
			else // fallback, if (screenshot == MPEScreenshotSaveLocationDesktop)
				screenshotPath = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) 
									objectAtIndex:0];
			
			[screenshotPath retain];
		}
	}
	
	// video equalizer
	if ([cPrefs boolForKey:MPEVideoEqualizerEnabled]) {
		[videoFilters addObject:[NSString stringWithFormat:@"eq2=%@",[EqualizerController eq2FilterValues]]];
		[videoFilters addObject:[NSString stringWithFormat:@"hue=%@",[EqualizerController hueFilterValue]]];
		[videoFilters addObject:@"scale"];
	}
	
	// add filter chain
	if ([videoFilters count] > 0) {
		[params addObject:@"-vf-add"];
		[params addObject:[videoFilters componentsJoinedByString:@","]];
	}
	
	// audio equalizer
	if ([cPrefs boolForKey:MPEAudioEqualizerEnabled]) {
		[audioFilters addObject:[NSString stringWithFormat:@"equalizer=%@",[EqualizerController equalizerFilterValues]]];
	}
	
	// *** Audio Filters
	if ([audioFilters count] > 0) {
		[params addObject:@"-af-add"];
		[params addObject:[audioFilters componentsJoinedByString:@","]];
	}
	
	// *** Audio Codecs
	if ([audioCodecsArr count] > 0) {
		NSString *acstring = [audioCodecsArr componentsJoinedByString:@","];
		// add trailing , if audioCodecs is empty
		if (![cPrefs objectForKey:MPEOverrideAudioCodecs]
				|| [[cPrefs stringForKey:MPEOverrideAudioCodecs] length] == 0)
			acstring = [acstring stringByAppendingString:@","];
		
		[params addObject:@"-ac"];
		[params addObject:acstring];
	}
	
	
	
	// *** OPTIONS

	// position from which to play
	if ([cPrefs floatForKey:MPEStartTime] > 0) {
		[params addObject:@"-ss"];
		[params addObject:[NSString stringWithFormat:@"%1.1f",[cPrefs floatForKey:MPEStartTime]]];
	}
	
	// additional parameters
	if ([cPrefs objectForKey:MPEAdvancedOptions]) {
		NSArray *options = [cPrefs arrayForKey:MPEAdvancedOptions];
		for (NSDictionary *option in options) {
			if ([option boolForKey:MPEAdvancedOptionsEnabledKey])
				[params addObjectsFromArray:
					[[option stringForKey:MPEAdvancedOptionsStringKey] componentsSeparatedByString:@" "]];
		}
	}
	
	[params addObject:@"-slave"];
	[params addObject:@"-identify"];
	
	// Disable Apple Remote
	if (disableAppleRemote)
		[params addObject:@"-noar"];
	
	[myCommandsBuffer removeAllObjects];	// empty buffer before launch
	
	// Disable preflight mode
	isPreflight = NO;
	
	// Set binary path
	[myPathToPlayer release];
	myPathToPlayer = [[[[AppController sharedController] preferencesController] 
					   pathForBinaryWithIdentifier:[cPrefs objectForKey:MPESelectedBinary]] retain];
	
	[self runMplayerWithParams:params];
}
/************************************************************************************/
- (void) play
{
	[self playItem:nil];
}
/************************************************************************************/
- (void) stop
{
	if (myMplayerTask) {
		switch (state) {
		case MIStatePlaying :
		case MIStateSeeking :
//			[myMplayerTask terminate];
			[self sendCommand:@"quit"];
			break;
		case MIStatePaused :
			[myCommandsBuffer addObject:@"quit"];
			[self sendCommand:@"pause"];
//			[self sendCommand:@"quit"];
			break;
		case MIStateStopped:
			break;
		case MIStateFinished:
			break;
		default :
			[myCommandsBuffer addObject:@"quit"];
			break;
		}
		[myMplayerTask waitUntilExit];
	}
}
/************************************************************************************/
- (void) pause
{
	if (myMplayerTask) {
		switch (state) {
		case MIStatePlaying:					// mplayer is just playing then pause it
		case MIStateSeeking :
			[self sendCommand:@"pause"];
			break;
		case MIStatePaused:					// mplayer is paused then unpause it
			[self sendCommand:@"pause"];
			break;
		case MIStateStopped:					// if stopped do nothing
			break;
		case MIStateFinished:					// if stopped do nothing
			break;
		default:						// otherwise save command to the buffer
			[myCommandsBuffer addObject:@"pause"];
			break;
		}
	}
}
/************************************************************************************/
- (void) seek:(float)seconds mode:(int)aMode
{		
	switch (aMode) {
	case MISeekingModeRelative :
		mySeconds += seconds;
		break;
	case MISeekingModePercent :
		
		break;
	case MISeekingModeAbsolute :
		mySeconds = seconds;
		break;
	default :
		break;
	}
	
	if (myMplayerTask) {
		switch (state) {
		case MIStatePlaying:
		case MIStatePaused:
				[self sendCommand:[NSString stringWithFormat:@"seek %1.1f %d",seconds, aMode] 
						  withOSD:MISurpressCommandOutputConditionally andPausing:MICommandPausingKeep];
				[self setState:MIStateSeeking];
			break;
		case MIStateSeeking:
			// Save missed seek
			[lastMissedSeek release];
			lastMissedSeek = [[NSDictionary alloc] initWithObjectsAndKeys:
				[NSNumber numberWithFloat:seconds], @"seconds",
				[NSNumber numberWithInt:aMode], @"mode", nil];
			break;
		default :
			break;
		}
	}
}
/************************************************************************************/
- (void) performCommand:(NSString *)aCommand
{
	switch (state) {
	case MIStatePlaying:					// if is playing send it directly to player
	case MIStateSeeking:
		[self sendCommand:aCommand];
		break;
	case MIStateStopped:					// if stopped do nothing
		break;
	default :						// otherwise save the command to the buffer
		[myCommandsBuffer addObject:aCommand];
		break;
	}
}
/************************************************************************************/
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (![self isRunning])
		return;
	
	if ([keyPath isEqualToString:MPEDropFrames]) {
		int framedrop = [[change objectForKey:NSKeyValueChangeNewKey] intValue];
		[self sendCommand:[NSString stringWithFormat:@"set_property framedropping %d",framedrop]];
		
	} else if ([keyPath isEqualToString:MPEOSDLevel]) {
		osdLevel = [[change objectForKey:NSKeyValueChangeNewKey] intValue];
		[self sendCommand:[NSString stringWithFormat:@"set_property osdlevel %d",(osdLevel < 2 ? osdLevel : osdLevel - 1)]];
	
	} else if ([keyPath isEqualToString:MPEVideoEqualizerValues]) {
		[self applyVideoEqualizer];
	
	} else if ([keyPath isEqualToString:MPELoopMovie]) {
		[self sendCommand:[NSString stringWithFormat:@"set_property loop %d",((int)[[playingItem prefs] boolForKey:MPELoopMovie] - 1)]];
	
	} else if ([keyPath isEqualToString:MPEAudioVolume] || [keyPath isEqualToString:MPEAudioMute]) {
		[self applyVolume];
	}
}
/************************************************************************************
 SETTINGS
 ************************************************************************************/
- (void) loadNewSubtitleFile:(NSNotification *)notification
{
	NSString *path = [[notification userInfo] objectForKey:MPEMovieInfoAddedExternalSubtitlePathKey];
	NSString *escaped = [path stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
	
	[self sendCommand:[NSString stringWithFormat:@"sub_load '%@'", escaped]];
	// Also select the newly loaded subtitle
	[self sendCommand:[NSString stringWithFormat:@"sub_file %u",[playingItem subtitleCountForType:SubtitleTypeFile]]];
}
/************************************************************************************/
- (void) applyVideoEqualizer
{
	NSDictionary *values = [PREFS objectForKey:MPEVideoEqualizerValues];
	int value;
	
	for (NSString *key in videoEqualizerCommands) {
		if ([values objectForKey:key])
			value = [[values objectForKey:key] intValue];
		else
			value = 0;
		[self sendCommand:[NSString stringWithFormat:@"set_property %@ %d",
						   [videoEqualizerCommands objectForKey:key], value]];
	}
}
/************************************************************************************/
- (void) applyVolume
{
	if ([[playingItem prefs] boolForKey:MPEAudioMute])
		[self sendCommand:[NSString stringWithFormat:@"set_property mute %d",
						   [[playingItem prefs] boolForKey:MPEAudioMute]]];
	else
		[self sendCommand:[NSString stringWithFormat:@"set_property volume %.2f",
						   [[playingItem prefs] floatForKey:MPEAudioVolume]]];
	
	// Inform clients of change
	float volume = [[playingItem prefs] floatForKey:MPEAudioVolume];
	if ([[playingItem prefs] boolForKey:MPEAudioMute])
		volume = 0;
	
	[self notifyClientsWithSelector:@selector(interface:volumeUpdate:) 
						  andObject:[NSNumber numberWithFloat:volume]];
}
/************************************************************************************/

/************************************************************************************/
- (void) applySettingsWithRestart
{
	[localPrefs release];
	localPrefs = [[playingItem prefs] copy];
	
	if ([self isRunning]) {
		restartingPlayer = YES;		// set it not to send termination notification
		[self play];				// restart playback if player is running
	}
	
}
/************************************************************************************
 INFO
 ************************************************************************************/
- (void) loadInfo:(MovieInfo *)item
{
	[playingItem release];
	playingItem = [item retain];
	
	// Set preflight mode
	isPreflight = YES;
	
	// Set binary path
	[myPathToPlayer release];
	myPathToPlayer = [[[[AppController sharedController] preferencesController] 
					   pathForBinaryWithIdentifier:[PREFS objectForKey:MPESelectedBinary]] retain];
	
	// run mplayer for identify
	[self runMplayerWithParams:[NSMutableArray arrayWithObjects:
								[playingItem filename], @"-identify",
								 @"-frames", @"0", 
								 @"-ao", @"null", 
								 @"-vo", @"null", 
								 nil]];
}
/************************************************************************************/
- (MovieInfo *) info
{
	return playingItem;
}
/************************************************************************************/
- (void) setState:(MIState)newState
{
	unsigned int newStateMask = (1<<newState);
	
	// Update isMovieOpen
	BOOL newIsMovieOpen = !!(newStateMask & MIStateRespondMask);
	if ([self isMovieOpen] != newIsMovieOpen)
		[self setMovieOpen:newIsMovieOpen];
	
	// Update isPlaying
	BOOL newIsPlaying = !!(newStateMask & MIStatePlayingMask);
	if ([self isPlaying] != newIsPlaying)
		[self setPlaying:newIsPlaying];
	
	// Notifiy clients of state change
	if (state != newState)
		[self notifyClientsWithSelector:@selector(interface:hasChangedStateTo:fromState:) 
							  andObject:[NSNumber numberWithUnsignedInt:newState]
							  andObject:[NSNumber numberWithUnsignedInt:state]];
	
	state = newState;
	stateMask = newStateMask;
}
/************************************************************************************/
- (float) seconds
{	
	return mySeconds;
}
/************************************************************************************/
- (BOOL) changesNeedRestart
{
	NSArray *requiresRestart = [[AppController sharedController] preferencesRequiringRestart];
	NSDictionary *currentPrefs = [PREFS dictionaryRepresentation];
	
	BOOL different = NO;
	for (NSString *option in requiresRestart) {
		// ignore options overriden locally
		if ([localPrefs objectForKey:option])
			continue;
		// check if option has changed
		id op1 = [prefs objectForKey:option];
		id op2 = [currentPrefs objectForKey:option];
		if (op1 == nil && op2 == nil)
			continue;
		if (!op1 || ![op1 isEqual:op2]) {
			different = YES;
			break;
		}
	}
	
	return different;
}
/************************************************************************************/
- (BOOL) localChangesNeedRestart
{
	NSArray *requiresRestart = [[AppController sharedController] preferencesRequiringRestart];
	
	BOOL different = NO;
	for (NSString *option in requiresRestart) {
		// check if option has changed
		id op1 = [localPrefs objectForKey:option];
		id op2 = [[playingItem prefs] objectForKey:option];
		if (op1 == nil && op2 == nil)
			continue;
		if (!op1 || ![op1 isEqual:op2]) {
			different = YES;
			break;
		}
	}
	
	return different;
}
/************************************************************************************/
- (BOOL)isRunning
{	
	return isRunning;
}
/************************************************************************************
 STATISTICS
 ************************************************************************************/
- (void) setUpdateStatistics:(BOOL)aBool
{
	myUpdateStatistics = aBool;
}
/************************************************************************************/
- (float) syncDifference
{
	return mySyncDifference;
}
/************************************************************************************/
- (int) cpuUsage
{
	return myCPUUsage;
}
/************************************************************************************/
- (int) cacheUsage
{
	return myCacheUsage;
}
/************************************************************************************/
- (int) droppedFrames
{
	return myDroppedFrames;
}
/************************************************************************************/
- (int) postProcLevel
{
	return myPostProcLevel;
}

/************************************************************************************
 ADVANCED
 ************************************************************************************/
- (void)sendCommand:(NSString *)aCommand withOSD:(uint)osdMode andPausing:(uint)pausing
{
	[self sendCommands:[NSArray arrayWithObject:aCommand] withOSD:osdMode andPausing:pausing];
}
/************************************************************************************/
- (void)sendCommand:(NSString *)aCommand
{
	[self sendCommand:aCommand withOSD:MISurpressCommandOutputConditionally andPausing:MICommandPausingKeep];
}
/************************************************************************************/
- (void)sendCommands:(NSArray *)aCommands withOSD:(uint)osdMode andPausing:(uint)pausing
{	
	if ([aCommands count] == 0)
		return;
	
	BOOL quietCommand = (osdMode == MISurpressCommandOutputNever || (osdMode == MISurpressCommandOutputConditionally && osdLevel == 1));
	
	if (quietCommand && !osdSilenced) {
		[Debug log:ASL_LEVEL_DEBUG withMessage:@"osd 0 (%@, %i, %i)\n",[aCommands objectAtIndex:0], osdMode, osdLevel];
		[self sendToMplayersInput:@"pausing_keep osd 0\n"];
		osdSilenced = YES;
	}
	
	NSString *pausingPrefix = @"";
	if (pausing == MICommandPausingKeep)
		pausingPrefix = @"pausing_keep ";
	else if (pausing == MICommandPausingToggle)
		pausingPrefix = @"pausing_toggle ";
	else if (pausing == MICommandPausingKeepForce)
		pausingPrefix = @"pausing_keep_force ";
	
	int i;
	for (i=0; i < [aCommands count]; i++) {
		[Debug log:ASL_LEVEL_DEBUG withMessage:@"Send Command: %@%@",pausingPrefix,[aCommands objectAtIndex:i]];
		[self sendToMplayersInput:[NSString stringWithFormat:@"%@%@\n",pausingPrefix,[aCommands objectAtIndex:i]]];
	}
		
	if (quietCommand) {
		if (state == MIStatePlaying)
			[self reactivateOsdAfterDelay];
		else {
			[self sendToMplayersInput:[NSString stringWithFormat:@"pausing_keep osd %d\n", (osdLevel < 2 ? osdLevel : osdLevel - 1)]];
			osdSilenced = NO;
		}
	}
}
/************************************************************************************/
- (void)sendCommands:(NSArray *)aCommands
{
	[self sendCommands:aCommands withOSD:MISurpressCommandOutputConditionally andPausing:MICommandPausingKeep];
}
/************************************************************************************/
- (void)reactivateOsdAfterDelay {
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reactivateOsd) object:nil];
	[self performSelector:@selector(reactivateOsd) withObject:nil afterDelay:1.2];
}

- (void)reactivateOsd {
	//[Debug log:ASL_LEVEL_DEBUG withMessage:@"osd %d\n", (osdLevel < 2 ? osdLevel : osdLevel - 1)];
	
	if (stateMask & MIStatePlayingMask) {
		[self sendToMplayersInput:[NSString stringWithFormat:@"pausing_keep osd %d\n", (osdLevel < 2 ? osdLevel : osdLevel - 1)]];
	} else if (state == MIStatePaused) {
		[myCommandsBuffer addObject:[NSString stringWithFormat:@"osd %d\n", (osdLevel < 2 ? osdLevel : osdLevel - 1)]];
	}
	osdSilenced = NO;
}
/************************************************************************************/

/************************************************************************************/
- (void) takeScreenshot
{
	[self sendCommand:@"screenshot 0"];
}
/************************************************************************************/
- (void)runMplayerWithParams:(NSMutableArray *)aParams
{
	NSMutableDictionary *env;

	// terminate mplayer if it is running
	if (myMplayerTask) {
		if (state == MIStatePaused && restartingPlayer)
			pausedOnRestart = YES;
		else
			pausedOnRestart = NO;
		[self stop];
		[myMplayerTask release];
		myMplayerTask = nil;
	}
	
	// if no path or movie file specified the return
	if (!myPathToPlayer || !playingItem || ![playingItem fileIsValid]) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to start MPlayer (%@,%@,%d)",myPathToPlayer,playingItem,(![playingItem fileIsValid])];
		return;
	}
	
	// initialize  mplayer task object
	myMplayerTask=[[NSTask alloc] init];
	
	// create standard input and output for application
	[myMplayerTask setStandardInput: [NSPipe pipe]];
	[myMplayerTask setStandardOutput: [NSPipe pipe]];
	[myMplayerTask setStandardError: [NSPipe pipe]];
	
	// add observer for termination of mplayer
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(mplayerTerminated) 
			name:NSTaskDidTerminateNotification
			object:myMplayerTask];
	// add observer for available data at mplayers output 
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(readOutputC:)
			name:NSFileHandleReadCompletionNotification
			object:[[myMplayerTask standardOutput] fileHandleForReading]];
	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(readError:)
			name:NSFileHandleReadCompletionNotification
			object:[[myMplayerTask standardError] fileHandleForReading]];
	
	// set working directory for screenshots
	if (screenshotPath)
		[myMplayerTask setCurrentDirectoryPath:screenshotPath];
	
	// set launch path and params
	if (force32bitBinary) {
		[myMplayerTask setLaunchPath:@"/usr/bin/arch"];
		[aParams insertObject:@"-i386" atIndex:0];
		[aParams insertObject:myPathToPlayer atIndex:1];
	} else
		[myMplayerTask setLaunchPath:myPathToPlayer];
	
	// set launch arguments
	[myMplayerTask setArguments:aParams];
	
	// get current environment and make appropriate changes
	env = [[[NSProcessInfo processInfo] environment] mutableCopy];
	[env autorelease];
	// enable bind-at-launch behavior for dyld to use DLL codecs
    [env setObject:@"1" forKey:@"DYLD_BIND_AT_LAUNCH"];
    // set fontconfig path
	[env setObject:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"fonts"] forKey:@"FONTCONFIG_PATH"];
	// Apply environment variables
	[myMplayerTask setEnvironment:env];

	//Print Command line to console
	[Debug log:ASL_LEVEL_INFO withMessage:@"Path to MPlayer: %@", myPathToPlayer];
	
	NSMutableArray *quotedParams = [[aParams mutableCopy] autorelease];
	int i;
	for (i=0; i < [quotedParams count]; i++) {
		if ([[quotedParams objectAtIndex:i] rangeOfRegex:@"[ ;()\\[\\]{}]"].location != NSNotFound)
			[quotedParams replaceObjectAtIndex:i withObject:
			 [NSString stringWithFormat:@"\"%@\"",[quotedParams objectAtIndex:i]]];
	}
	[Debug log:ASL_LEVEL_INFO withMessage:@"Command: mplayer %@", [quotedParams componentsJoinedByString:@" "]];
	
	// activate notification for available data at output
	[[[myMplayerTask standardOutput] fileHandleForReading]
			readInBackgroundAndNotifyForModes:parseRunLoopModes];
	[[[myMplayerTask standardError] fileHandleForReading]
			readInBackgroundAndNotifyForModes:parseRunLoopModes];
	
	// reset output read mode
	myOutputReadMode = 0;
	
	// reset subtitle file id
	subtitleFileId = 0;
	
	// launch mplayer task
	[myMplayerTask launch];
	isRunning = YES;
	[self setState:MIStateInitializing];
	
	[Debug log:ASL_LEVEL_INFO withMessage:@"Path to fontconfig: %@", [[myMplayerTask environment] objectForKey:@"FONTCONFIG_PATH"]];
}
/************************************************************************************/
- (void)sendToMplayersInput:(NSString *)aCommand
{
    if (myMplayerTask) {
		if ([myMplayerTask isRunning]) {
			NSFileHandle *thePipe = [[myMplayerTask standardInput] fileHandleForWriting];
			[thePipe writeData:[aCommand dataUsingEncoding:NSUTF8StringEncoding]];
		}
	}
}
/************************************************************************************/
// should be removed!
- (void)terminateMplayer
{
	if (myMplayerTask) {
		if (isRunning) {
			[myMplayerTask terminate];
			[myMplayerTask waitUntilExit];
			[self mplayerTerminated];
		}
	}
}


/************************************************************************************
 NOTIFICATION HANDLERS
 ************************************************************************************/
// Even after mplayer is terminated, readOutputC: might still be called with unparsed output!
- (void)mplayerTerminated
{
	int returnCode;
	
	// remove observers
	if (isRunning) {
		[[NSNotificationCenter defaultCenter] removeObserver:self
				name: NSTaskDidTerminateNotification object:myMplayerTask];
		
		if (!restartingPlayer && state > MIStateStopped)
			[self setState:MIStateStopped];
		restartingPlayer = NO;
		isRunning = NO;
	}
	
	returnCode = [myMplayerTask terminationStatus];
	[Debug log:ASL_LEVEL_INFO withMessage:@"MPlayer process exited with code %d",returnCode];
	
	//abnormal mplayer task termination
	if (returnCode != 0)
	{
		// post notification
		[[NSNotificationCenter defaultCenter]
		 postNotificationName:@"MIMplayerExitedAbnormally"
		 object:self];
		
		[Debug log:ASL_LEVEL_ERR withMessage:@"Abnormal playback error. mplayer returned error code: %d", returnCode];
	}
}
/************************************************************************************/
- (void)readError:(NSNotification *)notification
{
	NSString *data = [[NSString alloc] 
					  initWithData:[[notification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"] 
					  encoding:NSUTF8StringEncoding];
	
	// register for another read
	if ([myMplayerTask isRunning] || (data && [data length] > 0))
		[[[myMplayerTask standardError] fileHandleForReading]
				readInBackgroundAndNotifyForModes:parseRunLoopModes];
	
	if (!data || [data length] == 0) {
		[data release];
		return;
	}
	
	// Split data by newline characters
	NSArray *myLines = [data componentsSeparatedByRegex:MI_NEWLINE_REGEX 
							 options:RKLMultiline range:NSMakeRange(0, [data length]) error:NULL];
	NSString *line;
	
	int lineIndex = -1;
	
	while (1) {
		// Read next line of data
		lineIndex++;
		// check if end reached (save last unfinished line)
		if (lineIndex >= [myLines count] - 1) {
			[lastUnparsedErrorLine release];
			if (lineIndex < [myLines count])
				lastUnparsedErrorLine = [[myLines objectAtIndex:lineIndex] retain];
			else
				lastUnparsedErrorLine = nil;
			break;
		}
		// load line
		line = [myLines objectAtIndex:lineIndex];
		// prepend unfinished line
		if (lastUnparsedErrorLine) {
			line = [lastUnparsedErrorLine stringByAppendingString:line];
			[lastUnparsedErrorLine release];
			lastUnparsedErrorLine = nil;
		}
		// skip empty lines
		if ([[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0)
			continue;
		
		[Debug log:ASL_LEVEL_INFO withMessage:line];
	}
	
	[data release];
}
/************************************************************************************/
- (void)readOutputC:(NSNotification *)notification
{	
	NSString *data = [[NSString alloc] 
						initWithData:[[notification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"] 
						encoding:NSUTF8StringEncoding];
	
	// register for another read
	if ([myMplayerTask isRunning] || (data && [data length] > 0))
		[[[myMplayerTask standardOutput] fileHandleForReading]
			readInBackgroundAndNotifyForModes:parseRunLoopModes];
		
	if (!data) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Couldn\'t read MPlayer data. Lost bytes: %u",
			[(NSData *)[[notification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"] length]];
		[data release];
		return;
	}
	
	if ([data length] == 0) {
		[data release];
		return;
	}
	
	BOOL streamsHaveChanged = NO;
	
	const char *stringPtr;
	NSString *line;
	
	// For ID_ and ANS_ matching
	NSString *idName;
	NSString *idValue;
	
	// For stream matching
	NSString *streamType;
	int streamId;
	NSString *streamInfoName;
	NSString *streamInfoValue;
	
	// Split data by newline characters
	NSArray *myLines = [data componentsSeparatedByRegex:MI_NEWLINE_REGEX 
							 options:RKLMultiline range:NSMakeRange(0, [data length]) error:NULL];
	
	int lineIndex = -1;
	
	while (++lineIndex < [myLines count]) {
		char *tempPtr;
		
		// Read next line of data
		line = [myLines objectAtIndex:lineIndex];
		
		// skip empty lines
		if ([[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0)
			continue;
		
		// create cstring for legacy code
		stringPtr = [line UTF8String];
		
		if (strstr(stringPtr, "A:") == stringPtr ||
				strstr(stringPtr, "V:") == stringPtr) {
			double timeDifference = ([NSDate timeIntervalSinceReferenceDate] - myLastUpdate);
				
			// parse the output according to the preset mode
			if ((state == MIStateSeeking && timeDifference >= MI_SEEK_UPDATE_INTERVAL)
					|| timeDifference >= MI_STATS_UPDATE_INTERVAL) {
				float audioCPUUsage = 0;
				int videoCPUUsage = 0, voCPUUsage = 0;
				int hours = 0, mins = 0;
				myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
				
				if (myUpdateStatistics) {
					switch (myOutputReadMode) {
					case 0:
					case 1:
						if (sscanf(stringPtr, "A: %f V: %*f A-V: %f ct: %*f %*d/%*d %d%% %d%% %f%% %d %d %d%%",
								&mySeconds, &mySyncDifference, &videoCPUUsage, &voCPUUsage,
								&audioCPUUsage, &myDroppedFrames, &myPostProcLevel,
								&myCacheUsage) >= 7) {
							myCPUUsage = (int)(audioCPUUsage + videoCPUUsage + voCPUUsage);
							myOutputReadMode = 1;
							break;
						}
					case 2:			// only video
						if (sscanf(stringPtr, "V: %f %*d/%*d %d%% %*f%% %d %d %d%%",
								&mySeconds, &videoCPUUsage, &voCPUUsage, &myDroppedFrames,
								&myPostProcLevel, &myCacheUsage) >= 5) {
							myCPUUsage = (int)(videoCPUUsage + voCPUUsage);
							myOutputReadMode = 2;
							break;
						}
					case 3:			// only audio
						if (sscanf(stringPtr, "A: %d:%2d:%f %f%% %d%%", &hours, &mins,
								&mySeconds, &audioCPUUsage, &myCacheUsage) >= 4) {
							myCPUUsage = (int)audioCPUUsage;
							mySeconds += (3600 * hours + 60 * mins);
						}
						else if (sscanf(stringPtr, "A: %2d:%f %f%% %d%%", &mins,
								&mySeconds, &audioCPUUsage, &myCacheUsage) >= 3) {
							myCPUUsage = (int)audioCPUUsage;
							mySeconds += 60 * mins;
						}
						else if (sscanf(stringPtr, "A: %f %f%% %d%%", &mySeconds,
								&audioCPUUsage, &myCacheUsage) >= 2) {
							myCPUUsage = (int)audioCPUUsage;
						}
						else {
							myOutputReadMode = 0;
							break;
						}
						myOutputReadMode = 3;
						break;
					default :
						break;
					}
				}
				else {
					switch (myOutputReadMode) {
					case 0:
					case 1:
						if (sscanf(stringPtr, "A: %f V: %*f A-V: %f", &mySeconds,
								&mySyncDifference) == 2) {
							myOutputReadMode = 1;
							break;
						}
					case 2:
						if (sscanf(stringPtr, "V: %f ", &mySeconds) == 1) {
							myOutputReadMode = 2;
							break;
						}
					case 3:
						if (sscanf(stringPtr, "A: %d:%2d:%f ", &hours, &mins,
								&mySeconds) == 3) {
							mySeconds += (3600 * hours + 60 * mins);
							myOutputReadMode = 3;
							break;
						}
						else if (sscanf(stringPtr, "A: %2d:%f ", &mins, &mySeconds) == 2) {
							mySeconds += 60 * mins;
							myOutputReadMode = 3;
							break;
						}
						else if (sscanf(stringPtr, "A: %f ", &mySeconds) == 1) {
							myOutputReadMode = 3;
							break;
						}
					default :
						break;
					}
				}
				
				// if the line was parsed then post notification and continue on next line
				if (myOutputReadMode > 0) {
					
					// post notification
					// TODO: Update stats
					/*[[NSNotificationCenter defaultCenter]
							postNotificationName:@"MIStatsUpdatedNotification"
							object:self
							userInfo:nil];*/
					
					[self notifyClientsWithSelector:@selector(interface:timeUpdate:) 
										  andObject:[NSNumber numberWithFloat:mySeconds]];
					
					// finish seek
					if (state == MIStateSeeking && lastMissedSeek) {
						[self setState:MIStatePlaying];
						[self seek:[[lastMissedSeek objectForKey:@"seconds"] floatValue]
							  mode:[[lastMissedSeek objectForKey:@"mode"] intValue]];
						[lastMissedSeek release];
						lastMissedSeek = nil;
						continue;
					}
					
					// if it was not playing before (launched or unpaused)
					if (state != MIStatePlaying) {
						[self setState:MIStatePlaying];
						
						// perform commands buffer
						[self sendCommands:myCommandsBuffer 
								   withOSD:MISurpressCommandOutputConditionally
								andPausing:MICommandPausingNone];
						[myCommandsBuffer removeAllObjects];	// clear command buffer
			
						continue; 							// continue on next line
					}
					
					continue;
				}
			} else
				continue;
		}
		
		//  =====  PAUSE  ===== test for paused state
		if (strstr(stringPtr, MI_PAUSED_STRING) != NULL) {
			[self setState:MIStatePaused];
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			
			continue; 							// continue on next line
		}
		
		// Exiting... test for player termination
		if ([line isMatchedByRegex:MI_EXIT_REGEX]) {
			NSString *exitType = [line stringByMatching:MI_EXIT_REGEX capture:1];
			
			// player reached end of file
			if ([exitType isEqualToString:@"EOF"])
				[self setState:MIStateFinished];
			// player was stopped (by user or with an error)
			else
				[self setState:MIStateStopped];
			
			// remove observer for output
				// it's here because the NSTask sometimes do not terminate
				// as it is supposed to do
			[[NSNotificationCenter defaultCenter] removeObserver:self
					name: NSFileHandleReadCompletionNotification
					object:[[myMplayerTask standardOutput] fileHandleForReading]];
			[[NSNotificationCenter defaultCenter] removeObserver:self
					name: NSFileHandleReadCompletionNotification
					object:[[myMplayerTask standardError] fileHandleForReading]];
			
			myOutputReadMode = 0;				// reset output read mode
			
			// Parsing should now be finished
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MIFinishedParsing"
																object:self];
			
			restartingPlayer = NO;
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithFormat:@"Exited with state %d",state]];
			continue;							// continue on next line
		}
		
		
		// parse command replies
		if ([line isMatchedByRegex:MI_REPLY_REGEX]) {
			
			// extract matches
			idName = [line stringByMatching:MI_REPLY_REGEX capture:1];
			idValue = [line stringByMatching:MI_REPLY_REGEX capture:2];
			
			// streams
			// TODO: Stream responses
			/*if ([idName isEqualToString:@"switch_video"]) {
				[userInfo setObject:[NSNumber numberWithInt:[idValue intValue]] forKey:@"VideoStreamId"];
				continue;
			}
			
			if ([idName isEqualToString:@"switch_audio"]) {
				[userInfo setObject:[NSNumber numberWithInt:[idValue intValue]] forKey:@"AudioStreamId"];
				continue;
			}
			
			if ([idName isEqualToString:@"sub_demux"]) {
				[userInfo setObject:[NSNumber numberWithInt:[idValue intValue]] forKey:@"SubDemuxStreamId"];
				continue;
			}
			
			if ([idName isEqualToString:@"sub_file"]) {
				[userInfo setObject:[NSNumber numberWithInt:[idValue intValue]] forKey:@"SubFileStreamId"];
				continue;
			}
			
			// current volume
			if ([idName isEqualToString:@"volume"]) {
				[userInfo setObject:[NSNumber numberWithDouble:[idValue doubleValue]] forKey:@"Volume"];
				continue;
			}*/
			
			// unparsed ans lines
			[Debug log:ASL_LEVEL_DEBUG withMessage:@"REPLY not matched : %@ = %@", idName, idValue];
			continue;
		}
		
		// stream info
		if ([line isMatchedByRegex:MI_STREAM_REGEX]) {
			
			// extract matches
			streamType		=  [line stringByMatching:MI_STREAM_REGEX capture:1];
			streamId		= [[line stringByMatching:MI_STREAM_REGEX capture:2] intValue];
			streamInfoName  =  [line stringByMatching:MI_STREAM_REGEX capture:3];
			streamInfoValue =  [line stringByMatching:MI_STREAM_REGEX capture:4];
			
			// video streams
			if ([streamType isEqualToString:@"VID"]) {
				
				if ([streamInfoName isEqualToString:@"NAME"]) {
					
					[playingItem setVideoStreamName:streamInfoValue forId:streamId];
					continue;
				}
			}
			
			// audio streams
			if ([streamType isEqualToString:@"AID"]) {
				
				if ([streamInfoName isEqualToString:@"NAME"]) {
					
					[playingItem setAudioStreamName:streamInfoValue forId:streamId];
					continue;
				}
				
				if ([streamInfoName isEqualToString:@"LANG"]) {
					
					[playingItem setAudioStreamLanguage:streamInfoValue forId:streamId];
					continue;
				}
			}
			
			// subtitle demuxer streams
			if ([streamType isEqualToString:@"SID"]) {
				
				if ([streamInfoName isEqualToString:@"NAME"]) {
					
					[playingItem setSubtitleStreamName:streamInfoValue forId:streamId andType:SubtitleTypeDemux];
					continue;
				}
				
				if ([streamInfoName isEqualToString:@"LANG"]) {
					
					[playingItem setSubtitleStreamLanguage:streamInfoValue forId:streamId andType:SubtitleTypeDemux];
					continue;
				}
			}
			
			// chapters
			if ([streamType isEqualToString:@"CHAPTER"]) {
				
				if ([streamInfoName isEqualToString:@"NAME"]) {
					[playingItem setChapterName:streamInfoValue forId:streamId];
					continue;
				}
				
				if ([streamInfoName isEqualToString:@"START"]) {
					[playingItem setChapterStartTime:[NSNumber numberWithFloat:[streamInfoValue floatValue]/1000.] forId:streamId];
					continue;
				}
			}
			
			// Unmatched stream lines
			[Debug log:ASL_LEVEL_DEBUG withMessage:@"STREAM not matched: %@ for #%d, %@ = %@",streamType,streamId,streamInfoName,streamInfoValue];
			continue;
		}
		
		
		// parse identify lines
		if ([line isMatchedByRegex:MI_DEFINE_REGEX]) {
			
			// extract matches
			idName  = [line stringByMatching:MI_DEFINE_REGEX capture:1];
			idValue = [line stringByMatching:MI_DEFINE_REGEX capture:2];
			
			// getting length
			if ([idName isEqualToString:@"LENGTH"]) {
				[playingItem setLength:[idValue intValue]];
				continue;
			}
			
			// seekability
			if ([idName isEqualToString:@"SEEKABLE"]) {
				[playingItem setSeekable:(BOOL)[idValue intValue]];
				continue;
			}
			
			// movie width and height
			if ([idName isEqualToString:@"VIDEO_WIDTH"]) {
				[playingItem setVideoWidth:[idValue intValue]];
				continue;
			}
			if ([idName isEqualToString:@"VIDEO_HEIGHT"]) {
				[playingItem setVideoHeight:[idValue intValue]];
				continue;
			}
			
			// filename
			if ([idName isEqualToString:@"FILENAME"]) {
				[playingItem setFilename:idValue];
				continue;
			}
			
			// video format
			if ([idName isEqualToString:@"VIDEO_FORMAT"]) {
				[playingItem setVideoFormat:idValue];
				continue;
			}
			
			// video codec
			if ([idName isEqualToString:@"VIDEO_CODEC"]) {
				[playingItem setVideoCodec:idValue];
				continue;
			}
			
			// video bitrate
			if ([idName isEqualToString:@"VIDEO_BITRATE"]) {
				[playingItem setVideoBitrate:[idValue intValue]];
				continue;
			}
			
			// video fps
			if ([idName isEqualToString:@"VIDEO_FPS"]) {
				[playingItem setVideoFPS:[idValue floatValue]];
				continue;
			}
			
			// video aspect
			if ([idName isEqualToString:@"VIDEO_ASPECT"]) {
				[playingItem setVideoAspect:[idValue floatValue]];
				continue;
			}
			
			// audio format
			if ([idName isEqualToString:@"AUDIO_FORMAT"]) {
				[playingItem setAudioFormat:idValue];
				continue;
			}
			
			// audio codec
			if ([idName isEqualToString:@"AUDIO_CODEC"]) {
				[playingItem setAudioCodec:idValue];
				continue;
			}
			
			// audio bitrate
			if ([idName isEqualToString:@"AUDIO_BITRATE"]) {
				[playingItem setAudioBitrate:[idValue intValue]];
				continue;
			}
			
			// audio sample rate
			if ([idName isEqualToString:@"AUDIO_RATE"]) {
				[playingItem setAudioSampleRate:[idValue floatValue]];
				continue;
			}
			
			// audio channels
			if ([idName isEqualToString:@"AUDIO_NCH"]) {
				[playingItem setAudioChannels:[idValue intValue]];
				continue;
			}
			
			// video streams
			if ([idName isEqualToString:@"VIDEO_ID"]) {
				[playingItem newVideoStream:[idValue intValue]];
				streamsHaveChanged = YES;
				continue;
			}
			
			// audio streams
			if ([idName isEqualToString:@"AUDIO_ID"]) {
				[playingItem newAudioStream:[idValue intValue]];
				streamsHaveChanged = YES;
				continue;
			}
			
			// subtitle demux streams
			if ([idName isEqualToString:@"SUBTITLE_ID"]) {
				[playingItem newSubtitleStream:[idValue intValue] forType:SubtitleTypeDemux];
				streamsHaveChanged = YES;
				continue;
			}
			
			// subtitle file streams
			if ([idName isEqualToString:@"FILE_SUB_ID"]) {
				[playingItem newSubtitleStream:[idValue intValue] forType:SubtitleTypeFile];
				streamsHaveChanged = YES;
				subtitleFileId = [idValue intValue];
				continue;
			}
			
			if ([idName isEqualToString:@"FILE_SUB_FILENAME"]) {
				[playingItem setSubtitleStreamName:[idValue lastPathComponent] forId:subtitleFileId andType:SubtitleTypeFile];
				continue;
			}
			
			// chapter
			if ([idName isEqualToString:@"CHAPTER_ID"]) {
				[playingItem newChapter:[idValue intValue]];
				streamsHaveChanged = YES;
				continue;
			}
			
			// Unmatched IDENTIFY lines
			[Debug log:ASL_LEVEL_DEBUG withMessage:@"IDENTIFY not matched: %@ = %@", idName, idValue];
			[playingItem setInfo:idValue forKey:idName];
			continue;
			
		}
		
		// *** if player is playing then do not bother with parse anything else
		if (myOutputReadMode > 0) {
			// print unused line
			//[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			continue;
		}
		
		
		// mplayer starts to open a file
		if (strncmp(stringPtr, MI_OPENING_STRING, 8) == 0) {
			[self setState:MIStateOpening];
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			continue; 							// continue on next line	
		}
		
		// filling cache
		if (strncmp(stringPtr, "Cache fill:", 11) == 0) {
			float cacheUsage;
			[self setState:MIStateBuffering];
			if (sscanf(stringPtr, "Cache fill: %f%%", &cacheUsage) == 1) {
				// TODO: Update stats
				//[userInfo setObject:[NSNumber numberWithFloat:cacheUsage]
				//		forKey:@"CacheUsage"];
				myCacheUsage = cacheUsage;
			}
			continue;
		}
		
		// get format of audio
		if (strstr(stringPtr, MI_AUDIO_FILE_STRING) != NULL) {
			[playingItem setFileFormat:@"Audio"];
			continue; 							// continue on next line	
		}
		
		// get format of movie
		tempPtr = strstr(stringPtr, " file format detected.");
		if (tempPtr != NULL) {
			*(tempPtr) = '\0';
			[playingItem setFileFormat:[NSString stringWithUTF8String:stringPtr]];
			continue; 							// continue on next line	
		}
		
		// rebuilding index
		if ((tempPtr = strstr(stringPtr, "Generating Index:")) != NULL) {
			int cacheUsage;
			[self setState:MIStateIndexing];
			if (sscanf(tempPtr, "Generating Index: %d", &cacheUsage) == 1) {
				// TODO: update stats
				//[userInfo setObject:[NSNumber numberWithInt:cacheUsage]
				//		forKey:@"CacheUsage"];
				myCacheUsage = cacheUsage;
			}
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			continue; 							// continue on next line	
		}
		
		// mplayer is starting playback -- ignore for preflight
		if (strstr(stringPtr, MI_STARTING_STRING) != NULL && !isPreflight) {
			[self setState:MIStatePlaying];
			myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
	
			// perform commands buffer
			[self sendCommands:myCommandsBuffer withOSD:MISurpressCommandOutputConditionally andPausing:MICommandPausingNone];
			if (pausedOnRestart) {
				NSLog(@"pause after restart");
				[self sendCommand:@"pause"];
			}
			[myCommandsBuffer removeAllObjects];
			
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			continue;
		}
		
		// print unused output
		[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
		
	} // while
	
	// post notification if there is anything in user info
	if (streamsHaveChanged) {
		[self notifyClientsWithSelector:@selector(interface:streamUpate:) andObject:playingItem];
	}
	
	[data release];
}

@end

/************************************************************************************/
