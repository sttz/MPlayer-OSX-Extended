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
@synthesize playing;

/************************************************************************************
 INIT & UNINIT
 ************************************************************************************/
- (id)init;
{
	[self initWithPathToPlayer:@"/usr/local/bin/mplayer"];
	return self;
}
/************************************************************************************/
- (id)initWithPathToPlayer:(NSString *)aPath
{
	if (![super init])
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
								   nil] retain];
	
	// detect 64bit host
	int is64bit;
	size_t len = sizeof(is64bit);
	if (!sysctlbyname("hw.optional.x86_64",&is64bit,&len,NULL,0))
		is64bitHost = (BOOL)is64bit;
	
	myPathToPlayer = [aPath retain];
	buffer_name = @"mplayerosx";
	
	info = [[MovieInfo alloc] init];
	myCommandsBuffer = [[NSMutableArray array] retain];
	mySeconds = 0;
	myVolume = 100;
	
	mySubtitlesFiles = [[NSMutableArray alloc] init];
	
	// *** playback
	// addParams
	
	// *** display
	screenshotPath = nil;
	
	// *** text
	osdLevel = 1;
	
	// properties
	myRebuildIndex = NO;
//	myadvolume = 30;

	myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
	settingsChanged = NO;
	restartingPlayer = NO;
	pausedOnRestart = NO;
	isRunning = NO;
	takeEffectImediately = NO;
	myOutputReadMode = 0;
	myUpdateStatistics = NO;
	isPreflight = NO;
	
	windowedVO = NO;
	isFullscreen = NO;
	
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
	[myMplayerTask release];
	[myPathToPlayer release];
	[myMovieFile release];
	[mySubtitlesFiles release];
	[myAudioExportFile release];
	[myAudioFile release];
	[myFontFile release];
	[myCommandsBuffer release];
	[info release];
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
- (void) setPlayerPath:(NSString *)path
{
	[myPathToPlayer release];
	myPathToPlayer = [path retain];
}
/************************************************************************************/
- (void)registerPlayingItem:(NSDictionary *)item
{
	if (playingItem && playingItem != item)
		[self unregisterPlayingItem];
	NSLog(@"register!");
	playingItem = [item retain];
	
	[playingItem addObserver:self
				  forKeyPath:MPELoopMovie
					 options:0
					 context:nil];
}

- (void)unregisterPlayingItem
{
	NSLog(@"unregister!");
	[playingItem removeObserver:self forKeyPath:MPELoopMovie];
	
	[playingItem release];
	playingItem = nil;
}

/************************************************************************************
 PLAYBACK CONTROL
 ************************************************************************************/
- (void) playItem:(NSMutableDictionary *)item
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
		localPrefs = [item copy];
	}
	
	// combine global and local preferences
	NSMutableDictionary *cPrefs = [NSMutableDictionary new];
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
	if (is64bitHost && [[prefs objectForKey:MPEUse32bitBinaryon64bit] boolValue]) {
		NSDictionary *binaryInfo = [[[AppController sharedController] preferencesController] binaryInfo];
		NSDictionary *thisInfo = [binaryInfo objectForKey:[cPrefs objectForKey:MPESelectedBinary]];
		if ([[thisInfo objectForKey:@"MPEBinaryArchs"] containsObject:@"i386"])
			force32bitBinary = YES;
	}
	
	// *** FILES
	
	// add movie file
	if (myMovieFile) {
		if ([[myMovieFile lastPathComponent] isEqualToString:@"VIDEO_TS"]) {
			[params addObject:@"dvd://"];
			[params addObject:@"-dvd-device"];
		}
		[params addObject:myMovieFile];
	}
	else
		return;
	
	// add subtitles file
	if ([mySubtitlesFiles count] > 0) {
		[params addObject:@"-sub"];
		[params addObject:[mySubtitlesFiles componentsJoinedByString:@","]];
	}
	else {
		//[params addObject:@"-noautosub"];
	}
	
	// add audioexport file
	if (myAudioExportFile) {
		[params addObject:@"-ao"];
		[params addObject:@"pcm"];
		[params addObject:@"-aofile"];
		[params addObject:myAudioExportFile];
	}
	
	//add audio file
	if (myAudioFile) {
		[params addObject:@"-ao"];
		[params addObject:@"pcm"];
		[params addObject:@"-audiofile"];
		[params addObject:myAudioFile];
	}
	
	
	
	// *** PLAYBACK
	
	// audio languages
	if ([cPrefs objectForKey:MPEDefaultAudioLanguages]) {
		NSArray *audioLangs = [cPrefs objectForKey:MPEDefaultAudioLanguages];
		if ([audioLangs count] > 0) {
			[params addObject:@"-alang"];
			[params addObject:[[LanguageCodes sharedInstance] mplayerArgumentFromArray:audioLangs]];
		}
	}
	
	// subtitle languages
	if ([cPrefs objectForKey:MPEDefaultSubtitleLanguages]) {
		NSArray *subtitleLangs = [cPrefs objectForKey:MPEDefaultSubtitleLanguages];
		if ([subtitleLangs count] > 0) {
			[params addObject:@"-slang"];
			[params addObject:[[LanguageCodes sharedInstance] mplayerArgumentFromArray:subtitleLangs]];
		}
	}
	
	
	// *** PLAYBACK
	
	// cache settings
	if ([cPrefs objectForKey:MPECacheSizeInMB]) {
		int cacheSize = [[cPrefs objectForKey:MPECacheSizeInMB] floatValue] * 1024;
		if (cacheSize > 0) {
			[params addObject:@"-cache"];
			[params addObject:[NSString stringWithFormat:@"%d",cacheSize]];
		} else
			[params addObject:@"-nocache"];
	}
	
	// number of threads
	if (numberOfThreads > 0) {
		[params addObject:@"-lavdopts"];
		[params addObject:[NSString stringWithFormat:@"threads=%d",numberOfThreads]];
	}
	
	// rootwin
	if ([[cPrefs objectForKey:MPEStartPlaybackDisplayType] intValue] == MPEStartPlaybackDisplayTypeDesktop) {
		[params addObject:@"-rootwin"];
		[params addObject:@"-fs"];
	}
	
	// flip vertical
	if ([[cPrefs objectForKey:MPEFlipDisplayVertically] boolValue]) {
		[videoFilters addObject:@"flip"];
	}
	// flip horizontal
	if ([[cPrefs objectForKey:MPEFlipDisplayHorizontally] boolValue]) {
		[videoFilters addObject:@"mirror"];
	}
	
	// select video out (if video is enabled and not playing in rootwin)
	if ([[cPrefs objectForKey:MPEStartPlaybackDisplayType] intValue] != MPEStartPlaybackDisplayTypeDesktop
			&& [[cPrefs objectForKey:MPEEnableVideo] boolValue]) {
		[params addObject:@"-vo"];
		[params addObject:[NSString stringWithFormat:@"corevideo:buffer_name=%@",buffer_name]];
	}
	
	
	// *** TEXT
	
	// add font
	if ([cPrefs objectForKey:MPEFont]) {
		NSString *fcPattern = [cPrefs objectForKey:MPEFont];
		if ([cPrefs objectForKey:MPEFontStyle])
			fcPattern = [NSString stringWithFormat:@"%@:style=%@", fcPattern, [cPrefs objectForKey:MPEFontStyle]];
		[params addObject:@"-font"];
		[params addObject:fcPattern];
	}
	
	// guess encoding with enca
	if ([cPrefs objectForKey:MPEGuessTextEncoding] && 
			![[cPrefs objectForKey:MPEGuessTextEncoding] isEqualToString:@"disabled"]) {
		NSString *subEncoding = [cPrefs objectForKey:MPETextEncoding];
		if (!subEncoding)
			subEncoding = @"none";
		[params addObject:@"-subcp"];
		[params addObject:[NSString stringWithFormat:@"enca:%@:%@", 
						   [cPrefs objectForKey:MPEGuessTextEncoding], subEncoding]];
	// fix encoding
	} else if ([cPrefs objectForKey:MPETextEncoding]
			   && ![[cPrefs objectForKey:MPETextEncoding] isEqualToString:@"None"]) {
		[params addObject:@"-subcp"];
		[params addObject:[cPrefs objectForKey:MPETextEncoding]];
	}
	
	// *** TEXT
	
	// enable ass subtitles
	[params addObject:@"-ass"];
	
	// subtitles scale
	if ([cPrefs objectForKey:MPESubtitleScale]) {
		float subtitleScale = [[cPrefs objectForKey:MPESubtitleScale] floatValue];
		if (subtitleScale > 0) {
			[params addObject:@"-ass-font-scale"];
			[params addObject:[NSString stringWithFormat:@"%.3f",subtitleScale]];
		}
	}
	
	// embedded fonts
	if ([[cPrefs objectForKey:MPELoadEmbeddedFonts] boolValue]) {
		[params addObject:@"-embeddedfonts"];
	}
	
	// ass pre filter
	if ([[cPrefs objectForKey:MPERenderSubtitlesFirst] boolValue]) {
		[videoFilters insertObject:@"ass" atIndex:0];
	}
	
	// subtitles color
	if ([cPrefs objectForKey:MPESubtitleTextColor]) {
		NSColor *textColor = [PreferencesController2 unarchiveColor:[cPrefs objectForKey:MPESubtitleTextColor]];
		CGFloat red, green, blue, alpha;
		[textColor getRed:&red green:&green blue:&blue alpha:&alpha];
		[params addObject:@"-ass-color"];
		[params addObject:[NSString stringWithFormat:@"%02X%02X%02X%02X",(unsigned)(red*255),(unsigned)(green*255),(unsigned)(blue*255),(unsigned)((1-alpha)*255)]];
	}
	// subtitles color
	if ([cPrefs objectForKey:MPESubtitleBorderColor]) {
		NSColor *borderColor = [PreferencesController2 unarchiveColor:[cPrefs objectForKey:MPESubtitleBorderColor]];
		CGFloat red, green, blue, alpha;
		[borderColor getRed:&red green:&green blue:&blue alpha:&alpha];
		[params addObject:@"-ass-border-color"];
		[params addObject:[NSString stringWithFormat:@"%02X%02X%02X%02X",(unsigned)(red*255),(unsigned)(green*255),(unsigned)(blue*255),(unsigned)((1-alpha)*255)]];
	}
	
	if ([cPrefs objectForKey:MPEOSDLevel]) {
		osdLevel = [[cPrefs objectForKey:MPEOSDLevel] intValue];
		if (osdLevel != 1 && osdLevel != 2) {
			[params addObject:@"-osdlevel"];
			[params addObject:[NSString stringWithFormat:@"%i",(osdLevel == 0 ? 0 : osdLevel - 1)]];
		}
	}
	
	// subtitles scale
	if ([cPrefs objectForKey:MPEOSDScale]) {
		float osdScale = [[cPrefs objectForKey:MPEOSDScale] floatValue];
		if (osdScale > 0) {
			[params addObject:@"-subfont-osd-scale"];
			[params addObject:[NSString stringWithFormat:@"%.3f",osdScale*6.0]];
		}
	}
	
	
	// *** VIDEO
	
	// disable video
	if (![[cPrefs objectForKey:MPEEnableVideo] boolValue]) {
		[params addObject:@"-vc"];
		[params addObject:@"null"];
		[params addObject:@"-vo"];
		[params addObject:@"null"];
	// video codecs
	} else if ([cPrefs objectForKey:MPEOverrideVideoCodecs]) {
		[params addObject:@"-vc"];
		[params addObject:[cPrefs objectForKey:MPEOverrideVideoCodecs]];
	}
	
	// framedrop
	if ([cPrefs objectForKey:MPEDropFrames]) {
		int dropFrames = [[cPrefs objectForKey:MPEDropFrames] intValue];
		if (dropFrames == MPEDropFramesSoft)
			[params addObject:@"-framedrop"];
		else if (dropFrames == MPEDropFramesHard)
			[params addObject:@"-hardframedrop"];
	}
	
	// fast decoding
	if ([[cPrefs objectForKey:MPEFastDecoding] boolValue]) {
		[params addObject:@"-lavdopts"];
		[params addObject:@"fast:skiploopfilter=all"];
	}
	
	// deinterlace
	if ([cPrefs objectForKey:MPEDeinterlaceFilter]) {
		int deinterlace = [[cPrefs objectForKey:MPEDeinterlaceFilter] intValue];
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
		int postprocessing = [[cPrefs objectForKey:MPEPostprocessingFilter] intValue];
		if (postprocessing == MPEPostprocessingFilterDefault)
			[videoFilters addObject:@"pp=default"];
		else if (postprocessing == MPEPostprocessingFilterFast)
			[videoFilters addObject:@"pp=fast"];
		else if (postprocessing == MPEPostprocessingFilterHighQuality)
			[videoFilters addObject:@"pp=ac"];
	}
	
	
	// *** AUDIO
	
	// disable audio
	if (![[cPrefs objectForKey:MPEEnableAudio] boolValue])
		[params addObject:@"-nosound"];
	// audio codecs
	else if ([cPrefs objectForKey:MPEOverrideAudioCodecs]) {
		[audioCodecsArr addObject:[cPrefs objectForKey:MPEOverrideAudioCodecs]];
	}
	
	// ac3/dts passthrough
	if ([[cPrefs objectForKey:MPEHardwareAC3Passthrough] boolValue]) {
		[audioCodecsArr insertObject:@"hwac3" atIndex:0];
	}
	if ([[cPrefs objectForKey:MPEHardwareDTSPassthrough] boolValue]) {
		[audioCodecsArr insertObject:@"hwdts" atIndex:0];
	}
	
	// hrtf filter
	if ([[cPrefs objectForKey:MPEHRTFFilter] boolValue]) {
		[audioFilters addObject:@"resample=48000"];
		[audioFilters addObject:@"hrtf"];
	}
	// bs2b filter
	if ([[cPrefs objectForKey:MPEBS2BFilter] boolValue]) {
		[audioFilters addObject:@"bs2b"];
	}
	// karaoke filter
	if ([[cPrefs objectForKey:MPEKaraokeFilter] boolValue]) {
		[audioFilters addObject:@"karaoke"];
	}
	
	// set initial volume
	[params addObject:@"-volume"];
	[params addObject:[NSString stringWithFormat:@"%u", myVolume]];
	
	
	// *** ADVANCED
	
	// *** Video filters
	// add screenshot filter
	if ([cPrefs objectForKey:MPEScreenshotSaveLocation]) {
		int screenshot = [[cPrefs objectForKey:MPEScreenshotSaveLocation] intValue];
		
		if (screenshot != MPEScreenshotsDisabled) {
			[videoFilters addObject:@"screenshot"];
			
			[screenshotPath release];
			
			if (screenshot == MPEScreenshotSaveLocationCustom
					&& [cPrefs objectForKey:MPECustomScreenshotsSavePath])
				screenshotPath = [cPrefs objectForKey:MPECustomScreenshotsSavePath];
			
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
	if ([[cPrefs objectForKey:MPEVideoEqualizerEnabled] boolValue]) {
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
	if ([[cPrefs objectForKey:MPEAudioEqualizerEnabled] boolValue]) {
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
				|| [(NSString*)[cPrefs objectForKey:MPEOverrideAudioCodecs] length] == 0)
			acstring = [acstring stringByAppendingString:@","];
		
		[params addObject:@"-ac"];
		[params addObject:acstring];
	}
	
	
	
	// *** OPTIONS
	
	// rebuilding index
	if (myRebuildIndex)
		[params addObject:@"-forceidx"];

	// position from which to play
	if (mySeconds != 0) {
		[params addObject:@"-ss"];
		[params addObject:[NSString stringWithFormat:@"%1.1f",mySeconds]];
	}
	
	// additional parameters
	if ([cPrefs objectForKey:MPEAdvancedOptions]) {
		NSArray *options = [cPrefs objectForKey:MPEAdvancedOptions];
		for (NSDictionary *option in options) {
			if ([[option objectForKey:MPEAdvancedOptionsEnabledKey] boolValue])
				[params addObjectsFromArray:
					[[option objectForKey:MPEAdvancedOptionsStringKey] componentsSeparatedByString:@" "]];
		}
	}
	
	[params addObject:@"-slave"];
	[params addObject:@"-identify"];
	
	// Disable Apple Remote
	if (disableAppleRemote)
		[params addObject:@"-noar"];
	
	// MovieInfo
	MovieInfo *mf = [localPrefs objectForKey:@"MovieInfo"];
	if (mf == nil && (info == nil || ![myMovieFile isEqualToString:[info filename]])) {
		[info release];
		info = [[MovieInfo alloc] init];		// prepare it for getting new values
	} else if (mf != nil)
		info = mf;
	
	[myCommandsBuffer removeAllObjects];	// empty buffer before launch
	settingsChanged = NO;					// every startup settings has been made
	videoOutChanged = NO;
	
	// Disable preflight mode
	isPreflight = NO;
	
	// Set binary path
	[myPathToPlayer release];
	myPathToPlayer = [[[[AppController sharedController] preferencesController] 
					   pathForBinaryWithIdentifier:[cPrefs objectForKey:MPESelectedBinary]] retain];
	
	[self runMplayerWithParams:params];
	
	// apply initial video equalizer values
	if ([[cPrefs objectForKey:MPEVideoEqualizerEnabled] boolValue])
		[self applyVideoEqualizer];
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
		switch (myState) {
		case kPlaying :
		case kSeeking :
//			[myMplayerTask terminate];
			[self sendCommand:@"quit"];
			break;
		case kPaused :
			[myCommandsBuffer addObject:@"quit"];
			[self sendCommand:@"pause"];
//			[self sendCommand:@"quit"];
			break;
		case kStopped:
			break;
		case kFinished:
			break;
		default :
			[myCommandsBuffer addObject:@"quit"];
			break;
		}
		[self waitUntilExit];
	}
}
/************************************************************************************/
- (void) pause
{
	if (myMplayerTask) {
		switch (myState) {
		case kPlaying:					// mplayer is just playing then pause it
		case kSeeking :
			[self sendCommand:@"pause"];
			break;
		case kPaused:					// mplayer is paused then unpause it
			[self sendCommand:@"pause"];
			break;
		case kStopped:					// if stopped do nothing
			break;
		case kFinished:					// if stopped do nothing
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
	case MIRelativeSeekingMode :
		mySeconds += seconds;
		break;
	case MIPercentSeekingMode :
		
		break;
	case MIAbsoluteSeekingMode :
		mySeconds = seconds;
		break;
	default :
		break;
	}
	
	if (myMplayerTask) {
		switch (myState) {
		case kPlaying:
		case kPaused:
				[self sendCommand:[NSString stringWithFormat:@"seek %1.1f %d",seconds, aMode] 
						  withOSD:MI_CMD_SHOW_COND andPausing:MI_CMD_PAUSING_KEEP];
				[self setState:kSeeking];
			break;
		case kSeeking:
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
	switch (myState) {
	case kPlaying:					// if is playing send it directly to player
	case kSeeking:
		[self sendCommand:aCommand];
		break;
	case kStopped:					// if stopped do nothing
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
		[self sendCommand:[NSString stringWithFormat:@"set_property loop %d",((int)[playingItem boolForKey:MPELoopMovie] - 1)]];
	}
}
/************************************************************************************
 SETTINGS
 ************************************************************************************/
- (void) setMovieFile:(NSString *)aFile
{
	if (aFile) {
		if (![aFile isEqualToString:myMovieFile]) {
			[myMovieFile autorelease];
			myMovieFile = [aFile retain];
			settingsChanged = YES;
		}
	}
	else {
		if (myMovieFile) {
			[myMovieFile release];
			settingsChanged = YES;
		}
		myMovieFile = nil;
	}
}
/************************************************************************************/
- (void) setSubtitlesFile:(NSString *)aFile
{
	if (aFile) {
		if (![mySubtitlesFiles containsObject:aFile]) {
			[mySubtitlesFiles addObject:aFile];
			if (isRunning) {
				[self performCommand: [NSString stringWithFormat:@"sub_load '%@'", [aFile stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
				if (info)
					[self performCommand: [NSString stringWithFormat:
							@"sub_file %u", [info subtitleCountForType:SubtitleTypeFile]]];
			} else
				settingsChanged = YES;
		}
	}
	else {
		[mySubtitlesFiles release];
		mySubtitlesFiles = [[NSMutableArray alloc] init];
		settingsChanged = YES;
	}
}

//beta
/************************************************************************************/
- (void) setAudioExportFile:(NSString *)aFile
{
	if (aFile) {
		if (![aFile isEqualToString:myAudioExportFile]) {
			[myAudioExportFile autorelease];
			myAudioExportFile = [aFile retain];
			settingsChanged = YES;
		}
	}
	else {
		if (myAudioExportFile) {
			[myAudioExportFile release];
			settingsChanged = YES;
		}
		myAudioExportFile = nil;
	}
}


/************************************************************************************/
- (void) setAudioFile:(NSString *)aFile
{
	if (aFile) {
		if (![aFile isEqualToString:myAudioFile]) {
			[myAudioFile autorelease];
			myAudioFile = [aFile retain];
			settingsChanged = YES;
		}
	}
	else {
		if (myAudioFile) {
			[myAudioFile release];
			settingsChanged = YES;
		}
		myAudioFile = nil;
	}
}
/************************************************************************************/
- (void) setRebuildIndex:(BOOL)aBool
{
	if (myRebuildIndex != aBool) {
		myRebuildIndex = aBool;
		settingsChanged = YES;
	}
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
- (void) setVolume:(unsigned int)percents
{
	if (myVolume != percents) {
		myVolume = percents;
		if (myState == kPlaying || myState == kPaused || myState == kSeeking)
			[self sendCommand:[NSString stringWithFormat:@"volume %d 1",myVolume] 
					  withOSD:MI_CMD_SHOW_COND andPausing:MI_CMD_PAUSING_KEEP];
	}
}
/************************************************************************************/

/************************************************************************************/
- (void) applySettingsWithRestart
{
	[localPrefs release];
	localPrefs = [playingItem copy];
	
	if ([self isRunning]) {
		restartingPlayer = YES;		// set it not to send termination notification
		[self play];				// restart playback if player is running
		takeEffectImediately = NO;
	}
	
}
/************************************************************************************/
- (void) waitUntilExit
{
	if (isRunning) {
		[myMplayerTask waitUntilExit];
//		[self mplayerTerminated];		// remove observers to not recieve notif.
	}
}
/************************************************************************************
 INFO
 ************************************************************************************/
- (void) loadInfo
{
	// clear the class
	[info release];
	info = [[MovieInfo alloc] init];
	
	// Set preflight mode
	isPreflight = YES;
	
	// run mplayer for identify
	if (myMovieFile)
		[self runMplayerWithParams:[NSMutableArray arrayWithObjects:
									myMovieFile, @"-msglevel", 
									@"identify=4:demux=6", @"-frames",
									@"0", @"-ao", @"null", 
									@"-vo", @"null", 
									nil]];
}
/************************************************************************************/
- (MovieInfo *) info
{
	return info;
}
/************************************************************************************/
- (int) status
{	
	return myState;		
}
- (void) setState:(int)newState
{
	BOOL newIsPlaying = (newState == kPlaying || newState == kSeeking || newState == kPaused);
	
	if ([self isPlaying] != newIsPlaying)
		[self setPlaying:newIsPlaying];
	
	myState = newState;
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
		id op2 = [playingItem objectForKey:option];
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
	[self sendCommand:aCommand withOSD:MI_CMD_SHOW_ALWAYS andPausing:MI_CMD_PAUSING_KEEP];
}
/************************************************************************************/
- (void)sendCommands:(NSArray *)aCommands withOSD:(uint)osdMode andPausing:(uint)pausing
{	
	if ([aCommands count] == 0)
		return;
	
	BOOL quietCommand = (osdMode == MI_CMD_SHOW_NEVER || (osdMode == MI_CMD_SHOW_COND && osdLevel == 1));
	
	if (quietCommand && !osdSilenced) {
		[Debug log:ASL_LEVEL_DEBUG withMessage:@"osd 0 (%@, %i, %i)\n",[aCommands objectAtIndex:0], osdMode, osdLevel];
		[self sendToMplayersInput:@"pausing_keep osd 0\n"];
		osdSilenced = YES;
	}
	
	NSString *pausingPrefix = @"";
	if (pausing == MI_CMD_PAUSING_KEEP)
		pausingPrefix = @"pausing_keep ";
	else if (pausing == MI_CMD_PAUSING_TOGGLE)
		pausingPrefix = @"pausing_toggle ";
	else if (pausing == MI_CMD_PAUSING_FORCE)
		pausingPrefix = @"pausing_keep_force ";
	
	int i;
	for (i=0; i < [aCommands count]; i++) {
		[Debug log:ASL_LEVEL_DEBUG withMessage:@"Send Command: %@%@",pausingPrefix,[aCommands objectAtIndex:i]];
		[self sendToMplayersInput:[NSString stringWithFormat:@"%@%@\n",pausingPrefix,[aCommands objectAtIndex:i]]];
	}
		
	if (quietCommand) {
		if (myState == kPlaying)
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
	[self sendCommands:aCommands withOSD:MI_CMD_SHOW_ALWAYS andPausing:MI_CMD_PAUSING_KEEP];
}
/************************************************************************************/
- (void)reactivateOsdAfterDelay {
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reactivateOsd) object:nil];
	[self performSelector:@selector(reactivateOsd) withObject:nil afterDelay:1.2];
}

- (void)reactivateOsd {
	//[Debug log:ASL_LEVEL_DEBUG withMessage:@"osd %d\n", (osdLevel < 2 ? osdLevel : osdLevel - 1)];
	
	if (myState == kPlaying || myState == kSeeking) {
		[self sendToMplayersInput:[NSString stringWithFormat:@"pausing_keep osd %d\n", (osdLevel < 2 ? osdLevel : osdLevel - 1)]];
	} else if (myState == kPaused) {
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
		if (myState == kPaused && restartingPlayer)
			pausedOnRestart = YES;
		else
			pausedOnRestart = NO;
		NSLog(@"pausedOnRestart: %d",pausedOnRestart);
		[self stop];
		[myMplayerTask release];
		myMplayerTask = nil;
	}
	
	// if no path or movie file specified the return
	if (!myPathToPlayer || !myMovieFile)
		return;
	
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
	[self setState:kInitializing];
	
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
		
		if (!restartingPlayer && myState > 0) {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			
			[self setState:kStopped];
			// save value to userInfo
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
			// post notification
			[[NSNotificationCenter defaultCenter]
					postNotificationName:@"MIStateUpdatedNotification"
					object:self
					userInfo:[NSDictionary dictionaryWithDictionary:userInfo]];
		}
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
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	
	/*unsigned dataLength = [(NSData *)[[notification userInfo]
			objectForKey:@"NSFileHandleNotificationDataItem"] length] / sizeof(char);
	char *stringPtr = NULL, *dataPtr = malloc([(NSData *)[[notification userInfo]
			objectForKey:@"NSFileHandleNotificationDataItem"] length] + sizeof(char));
	
	// load data and terminate it with null character
	[[[notification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"]
				getBytes:(void *)dataPtr];
	*(dataPtr+dataLength) = '\0';*/
	
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
			if ((myState == kSeeking && timeDifference >= MI_SEEK_UPDATE_INTERVAL)
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
					[[NSNotificationCenter defaultCenter]
							postNotificationName:@"MIStatsUpdatedNotification"
							object:self
							userInfo:nil];
					
					// finish seek
					if (myState == kSeeking && lastMissedSeek) {
						[self setState:kPlaying];
						[self seek:[[lastMissedSeek objectForKey:@"seconds"] floatValue]
							  mode:[[lastMissedSeek objectForKey:@"mode"] intValue]];
						[lastMissedSeek release];
						lastMissedSeek = nil;
						continue;
					}
					
					// if it was not playing before (launched or unpaused)
					if (myState != kPlaying) {
						[self setState:kPlaying];
						[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
						
						// perform commands buffer
						[self sendCommands:myCommandsBuffer 
								   withOSD:MI_CMD_SHOW_COND
								andPausing:MI_CMD_PAUSING_NONE];
						[myCommandsBuffer removeAllObjects];	// clear command buffer
			
						continue; 							// continue on next line
					}
					
					continue;
				}
				else
					myOutputReadMode = 0;
			}
			else
				continue;
		}
		
/*	
		// if we don't have output mode try to parse playback output and get output mode
		if (myOutputReadMode == 0) {
			float aFloat;
			int aInt;
			if (sscanf(stringPtr,
					"A: %f V: %*f A-V: %f ct: %*f %*d/%*d %d%% %d%% %*f%% %d %d %d%%",
					&aFloat, &aFloat, &aInt, &aInt, &aInt, &aInt, &aInt) == 7)
				myOutputReadMode = 1;			// audio and video
			else if (sscanf(stringPtr, "V: %f %*d %d%% %d%% %*f%% %d %d %d%%",
					&aFloat, &aInt, &aInt, &aInt, &aInt, &aInt) == 6)
				myOutputReadMode = 2;			// only video
			else if (sscanf(stringPtr, "A: %d:%2d:%f %f%% %d%%",
					&aInt, &aInt, &aFloat, &aFloat, &aInt) == 3)
				myOutputReadMode = 3;			// only audio in hours:minutes:seconds
			else if (sscanf(stringPtr, "A: %2d:%f %f%% %d%%",
					&aInt, &aFloat, &aFloat, &aInt) == 3)
				myOutputReadMode = 4;			// only audio in minutes:second
			else if (sscanf(stringPtr, "A: %f %f%% %d%%",
					&aFloat, &aFloat, &aInt) == 3)
				myOutputReadMode = 5;			// only audio in seconds
		}
*/		
		//  =====  PAUSE  ===== test for paused state
		if (strstr(stringPtr, MI_PAUSED_STRING) != NULL) {
			[self setState:kPaused];
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			
			continue; 							// continue on next line
		}
		
		// Exiting... test for player termination
		if ([line isMatchedByRegex:MI_EXIT_REGEX]) {
			NSString *exitType = [line stringByMatching:MI_EXIT_REGEX capture:1];
			
			// player reached end of file
			if ([exitType isEqualToString:@"EOF"])
				[self setState:kFinished];
			// player was stopped (by user or with an error)
			else
				[self setState:kStopped];
			
			// remove observer for output
				// it's here because the NSTask sometimes do not terminate
				// as it is supposed to do
			[[NSNotificationCenter defaultCenter] removeObserver:self
					name: NSFileHandleReadCompletionNotification
					object:[[myMplayerTask standardOutput] fileHandleForReading]];
			[[NSNotificationCenter defaultCenter] removeObserver:self
					name: NSFileHandleReadCompletionNotification
					object:[[myMplayerTask standardError] fileHandleForReading]];
			
			// post notification for finish of parsing
			NSMutableDictionary *preflightInfo = [NSMutableDictionary dictionaryWithCapacity:2];
			[preflightInfo setObject:myMovieFile forKey:@"MovieFile"];
			[preflightInfo setObject:info forKey:@"MovieInfo"];
			
			[[NSNotificationCenter defaultCenter]
				 postNotificationName:@"MIFinishedParsing"
				 object:self
				 userInfo:preflightInfo];
			
			// when player is not restarting
			if (!restartingPlayer) {
				// save value to userInfo
				[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
			}

			myOutputReadMode = 0;				// reset output read mode
						
			restartingPlayer = NO;
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithFormat:@"Exited with state %d",myState]];
			continue;							// continue on next line
		}
		
		
		// parse command replies
		if ([line isMatchedByRegex:MI_REPLY_REGEX]) {
			
			// extract matches
			idName = [line stringByMatching:MI_REPLY_REGEX capture:1];
			idValue = [line stringByMatching:MI_REPLY_REGEX capture:2];
			
			// streams
			if ([idName isEqualToString:@"switch_video"]) {
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
			}
			
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
					
					[info setVideoStreamName:streamInfoValue forId:streamId];
					continue;
				}
			}
			
			// audio streams
			if ([streamType isEqualToString:@"AID"]) {
				
				if ([streamInfoName isEqualToString:@"NAME"]) {
					
					[info setAudioStreamName:streamInfoValue forId:streamId];
					continue;
				}
				
				if ([streamInfoName isEqualToString:@"LANG"]) {
					
					[info setAudioStreamLanguage:streamInfoValue forId:streamId];
					continue;
				}
			}
			
			// subtitle demuxer streams
			if ([streamType isEqualToString:@"SID"]) {
				
				if ([streamInfoName isEqualToString:@"NAME"]) {
					
					[info setSubtitleStreamName:streamInfoValue forId:streamId andType:SubtitleTypeDemux];
					continue;
				}
				
				if ([streamInfoName isEqualToString:@"LANG"]) {
					
					[info setSubtitleStreamLanguage:streamInfoValue forId:streamId andType:SubtitleTypeDemux];
					continue;
				}
			}
			
			// chapters
			if ([streamType isEqualToString:@"CHAPTER"]) {
				
				if ([streamInfoName isEqualToString:@"NAME"]) {
					[info setChapterName:streamInfoValue forId:streamId];
					continue;
				}
				
				if ([streamInfoName isEqualToString:@"START"]) {
					[info setChapterStartTime:[NSNumber numberWithFloat:[streamInfoValue floatValue]/1000.] forId:streamId];
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
				[info setLength:[idValue intValue]];
				continue;
			}
			
			// seekability
			if ([idName isEqualToString:@"SEEKABLE"]) {
				[info setIsSeekable:(BOOL)[idValue intValue]];
				continue;
			}
			
			// movie width and height
			if ([idName isEqualToString:@"VIDEO_WIDTH"]) {
				[info setVideoWidth:[idValue intValue]];
				continue;
			}
			if ([idName isEqualToString:@"VIDEO_HEIGHT"]) {
				[info setVideoHeight:[idValue intValue]];
				continue;
			}
			
			// filename
			if ([idName isEqualToString:@"FILENAME"]) {
				[info setFilename:idValue];
				continue;
			}
			
			// video format
			if ([idName isEqualToString:@"VIDEO_FORMAT"]) {
				[info setVideoFormat:idValue];
				continue;
			}
			
			// video codec
			if ([idName isEqualToString:@"VIDEO_CODEC"]) {
				[info setVideoCodec:idValue];
				continue;
			}
			
			// video bitrate
			if ([idName isEqualToString:@"VIDEO_BITRATE"]) {
				[info setVideoBitrate:[idValue intValue]];
				continue;
			}
			
			// video fps
			if ([idName isEqualToString:@"VIDEO_FPS"]) {
				[info setVideoFps:[idValue floatValue]];
				continue;
			}
			
			// video aspect
			if ([idName isEqualToString:@"VIDEO_ASPECT"]) {
				[info setVideoAspect:[idValue floatValue]];
				continue;
			}
			
			// audio format
			if ([idName isEqualToString:@"AUDIO_FORMAT"]) {
				[info setAudioFormat:idValue];
				continue;
			}
			
			// audio codec
			if ([idName isEqualToString:@"AUDIO_CODEC"]) {
				[info setAudioCodec:idValue];
				continue;
			}
			
			// audio bitrate
			if ([idName isEqualToString:@"AUDIO_BITRATE"]) {
				[info setAudioBitrate:[idValue intValue]];
				continue;
			}
			
			// audio sample rate
			if ([idName isEqualToString:@"AUDIO_RATE"]) {
				[info setAudioSampleRate:[idValue floatValue]];
				continue;
			}
			
			// audio channels
			if ([idName isEqualToString:@"AUDIO_NCH"]) {
				[info setAudioChannels:[idValue intValue]];
				continue;
			}
			
			// video streams
			if ([idName isEqualToString:@"VIDEO_ID"]) {
				[info newVideoStream:[idValue intValue]];
				[userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"StreamsHaveChanged"];
				continue;
			}
			
			// audio streams
			if ([idName isEqualToString:@"AUDIO_ID"]) {
				[info newAudioStream:[idValue intValue]];
				[userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"StreamsHaveChanged"];
				continue;
			}
			
			// subtitle demux streams
			if ([idName isEqualToString:@"SUBTITLE_ID"]) {
				[info newSubtitleStream:[idValue intValue] forType:SubtitleTypeDemux];
				[userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"StreamsHaveChanged"];
				continue;
			}
			
			// subtitle file streams
			if ([idName isEqualToString:@"FILE_SUB_ID"]) {
				[info newSubtitleStream:[idValue intValue] forType:SubtitleTypeFile];
				[userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"StreamsHaveChanged"];
				subtitleFileId = [idValue intValue];
				continue;
			}
			
			if ([idName isEqualToString:@"FILE_SUB_FILENAME"]) {
				[info setSubtitleStreamName:[idValue lastPathComponent] forId:subtitleFileId andType:SubtitleTypeFile];
				continue;
			}
			
			// chapter
			if ([idName isEqualToString:@"CHAPTER_ID"]) {
				[info newChapter:[idValue intValue]];
				[userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"StreamsHaveChanged"];
				continue;
			}
			
			// Unmatched IDENTIFY lines
			[Debug log:ASL_LEVEL_DEBUG withMessage:@"IDENTIFY not matched: %@ = %@", idName, idValue];
			[info setInfo:idValue forKey:idName];
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
			[self setState:kOpening];
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			continue; 							// continue on next line	
		}
		
		// filling cache
		if (strncmp(stringPtr, "Cache fill:", 11) == 0) {
			float cacheUsage;
			[self setState:kBuffering];
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
			if (sscanf(stringPtr, "Cache fill: %f%%", &cacheUsage) == 1) {
				[userInfo setObject:[NSNumber numberWithFloat:cacheUsage]
						forKey:@"CacheUsage"];
				myCacheUsage = cacheUsage;
			}
			// if the string is longer then supposed divide it and continue
			/*[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			if (strlen(stringPtr) > 32) {
				*(stringPtr + 31) = '\0';
				stringPtr = (stringPtr + 32);
			}
			else	*/							// if string is not longer than supposed
				continue; 						// continue on next line
		}
		// get format of audio
		if (strstr(stringPtr, MI_AUDIO_FILE_STRING) != NULL) {
			[info setFileFormat:@"Audio"];
			continue; 							// continue on next line	
		}
		// get format of movie
		tempPtr = strstr(stringPtr, " file format detected.");
		if (tempPtr != NULL) {
			*(tempPtr) = '\0';
			[info setFileFormat:[NSString stringWithUTF8String:stringPtr]];
			continue; 							// continue on next line	
		}
		
		// rebuilding index
		if ((tempPtr = strstr(stringPtr, "Generating Index:")) != NULL) {
			int cacheUsage;
			[self setState:kIndexing];
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
			if (sscanf(tempPtr, "Generating Index: %d", &cacheUsage) == 1) {
				[userInfo setObject:[NSNumber numberWithInt:cacheUsage]
						forKey:@"CacheUsage"];
				myCacheUsage = cacheUsage;
			}
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			continue; 							// continue on next line	
		}
		
		
		// mkv chapters
		/*if ([line isMatchedByRegex:MI_MKVCHP_REGEX]) {
			
			// extract
			chapterId		= [[line stringByMatching:MI_MKVCHP_REGEX capture:1] intValue];
			chapterTime[0]	= [[line stringByMatching:MI_MKVCHP_REGEX capture:2] floatValue];
			chapterTime[1]	= [[line stringByMatching:MI_MKVCHP_REGEX capture:3] floatValue];
			chapterTime[2]	= [[line stringByMatching:MI_MKVCHP_REGEX capture:4] floatValue];
			chapterTime[3]	= [[line stringByMatching:MI_MKVCHP_REGEX capture:5] floatValue];
			chapterTime[4]	= [[line stringByMatching:MI_MKVCHP_REGEX capture:6] floatValue];
			chapterTime[5]	= [[line stringByMatching:MI_MKVCHP_REGEX capture:7] floatValue];
			chapterName		=  [line stringByMatching:MI_MKVCHP_REGEX capture:8];
			
			[info newChapter:(chapterId+1) from:(chapterTime[0]*3600+chapterTime[1]*60+chapterTime[2])
						  to:(chapterTime[3]*3600+chapterTime[4]*60+chapterTime[5]) withName:chapterName];
			continue;
		}*/
		
		// mplayer is starting playback -- ignore for preflight
		if (strstr(stringPtr, MI_STARTING_STRING) != NULL && !isPreflight) {
			[self setState:kPlaying];
			myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
	
			// perform commands buffer
			[self sendCommands:myCommandsBuffer withOSD:MI_CMD_SHOW_COND andPausing:MI_CMD_PAUSING_NONE];
			if (pausedOnRestart) {
				NSLog(@"pause after restart");
				[self sendCommand:@"pause"];
			}
			[myCommandsBuffer removeAllObjects];
	
			// post status playback start
			[[NSNotificationCenter defaultCenter]
					postNotificationName:@"MIInfoReadyNotification"
					object:self
					userInfo:nil];
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			continue;
		}
		
		// print unused output
		//[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
		
	} // while
	
	// post notification if there is anything in user info
	if (!isPreflight && [userInfo count] > 0) {
		// post notification
		[[NSNotificationCenter defaultCenter]
				postNotificationName:@"MIStateUpdatedNotification"
				object:self
				userInfo:userInfo];
		[userInfo removeAllObjects];
	}

	//free((char *)dataPtr);
	[data release];
}

@end

/************************************************************************************/
