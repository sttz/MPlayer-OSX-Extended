/*
 *  MPlayerInterface.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "MPlayerInterface.h"
#import "RegexKitLite.h"
#import <sys/sysctl.h>

#import "AppController.h"
#import "PreferencesController2.h"
#import "EqualizerController.h"
#import "Preferences.h"
#import "CocoaAdditions.h"

#import <objc/runtime.h>

NSString* const MIStatsStatusStringKey	= @"MIStatsStatusString";
NSString* const MIStatsCPUUsageKey		= @"MIStatsCPUUsage";
NSString* const MIStatsAudioCPUUsageKey	= @"MIStatsAudioCPUUsage";
NSString* const MIStatsVideoCPUUsageKey	= @"MIStatsVideoCPUUsage";
NSString* const MIStatsCacheUsageKey	= @"MIStatsCacheUsage";
NSString* const MIStatsAVSyncKey		= @"MIStatsAVSync";
NSString* const MIStatsDroppedFramesKey = @"MIStatsDroppedFrames";

// Strings used for output parsing
static NSString *MI_PAUSED_STRING		= @"ID_PAUSED";
static NSString *MI_OPENING_STRING		= @"Playing ";
static NSString *MI_AUDIO_FILE_STRING	= @"Audio file detected.";
static NSString *MI_STARTING_STRING		= @"Starting playback...";

// Regexes used for output parsing
static NSString *MI_DEFINE_REGEX		= @"^ID_(.*)=(.*)$";
static NSString *MI_REPLY_REGEX			= @"^ANS_(.*)=(.*)$";
static NSString *MI_STREAM_REGEX		= @"^ID_(.*)_(\\d+)_(.*)=(.*)$";
static NSString *MI_EXIT_REGEX			= @"^ID_EXIT=(.*)$";
static NSString *MI_NEWLINE_REGEX		= @"(?:\r\n|[\n\v\f\r\302\205\\p{Zl}\\p{Zp}])";
static NSString *MI_CACHE_FILL_REGEX	= @"^Cache fill:\\s+([0-9.]+)%";
static NSString *MI_INDEXING_REGEX		= @"^Generating Index:\\s+(\\d+) %";
static NSString *MI_FORMAT_REGEX		= @"^(.*) file format detected.$";

// Short status line parsing regex (only for time)
static NSString *MI_STATUS_SHORT_REGEX  = @"^(?:A:\\s*([0-9.-]+)\\s*)?"
											"(?:V:\\s*([0-9.-]+)\\s*)?";
// Full status line parsing regex			// Audio-time "A: 00.0 (00.0) of 00.0 (0:00:00.0)"
static NSString *MI_STATUS_REGEX		= @"^(?:A:\\s*([0-9.-]+)(?:\\s*\\([0-9.-]+\\) of [0-9.-]+ \\([ 0-9.-:]+\\))?\\s*)?"
											// Video-time "V: 00.0"
											"(?:V:\\s*([0-9.-]+)\\s*)?"
											// Audio-Video sync "A-V: -0.000"
											"(?:A-V:\\s*([0-9.-]+)\\s*)?"
											// Sync correction "c-t: -0.000"
											"(?:ct:\\s*[0-9.-]+\\s*)?"
											// Video stats "0/ 0" 
											"(?:\\d+\\/\\s*\\d+\\s*)?"
											// First two percent values "00% 00%"
											"(?:([0-9.-?]+)%(?:\\s*([0-9.-?]+)%)?"
											// Third percent value "00%"
											"(?:\\s*([0-9.-?,]+)?%)?\\s*)?"
											// VO-Statistics (dropped frames and postprocessing) "0 0"
											"(?:(\\d+)\\s*\\d+\\s*)?"
											// Last percent value "00%"
											"(?:(\\d+)%\\s*)?"
											// Playback speed "00.0x"
											"(?:[0-9.-]+x\\s*)?";

// Capture group indexes for the status regexes
static const int MI_STATUS_AUDIO_TIME_INDEX     = 1;
static const int MI_STATUS_VIDEO_TIME_INDEX     = 2;
static const int MI_STATUS_AV_SYNC_INDEX        = 3;
static const int MI_STATUS_FIRST_PERCENT_INDEX  = 4;
static const int MI_STATUS_SECOND_PERCENT_INDEX = 5;
static const int MI_STATUS_THIRD_PERCENT_INDEX  = 6;
static const int MI_STATUS_DROPPED_FRAMES_INDEX = 7;
static const int MI_STATUS_FORUTH_PERCENT_INDEX = 8;

// Status update interval (regular & while seeking)
static float MI_STATS_UPDATE_INTERVAL	= 0.2f;
static float MI_SEEK_UPDATE_INTERVAL	= 0.1f;

static unsigned int MI_LAVC_MAX_THREADS	= 8;

// run loop modes in which we parse MPlayer's output
static NSArray* parseRunLoopModes;

// video equalizer keys to command mapping
static NSDictionary *videoEqualizerCommands;

static BOOL is64bitHost					= NO;

// Local MovieInfo prefs to observe using KVO
static NSArray* localPrefsToObserve;

// String names for states
static NSArray* statusNames;

@implementation MPlayerInterface
@synthesize playing, movieOpen, state, stateMask;

+ (void)initialize
{
	if (self != [MPlayerInterface class])
		return;
	
	parseRunLoopModes = [[NSArray alloc] initWithObjects:
						 NSRunLoopCommonModes,
						 nil];
	
	videoEqualizerCommands = [[NSDictionary alloc] initWithObjectsAndKeys:
							   @"brightness", MPEVideoEqualizerBrightness,
							   @"contrast", MPEVideoEqualizerContrast,
							   @"gamma", MPEVideoEqualizerGamma,
							   @"hue", MPEVideoEqualizerHue,
							   @"saturation", MPEVideoEqualizerSaturation,
							   nil];
	
	localPrefsToObserve = [[NSArray alloc] initWithObjects:
						   MPELoopMovie,
						   MPEAudioItemRelativeVolume,
						   MPEPlaybackSpeed,
						   MPEAudioDelay,
						   MPESubtitleDelay,
						   MPEOSDLevel,
						   nil];
	
	statusNames = [[NSArray alloc] initWithObjects:
				   @"Finished",
				   @"Stopped",
				   @"Error",
				   @"Playing",
				   @"Paused",
				   @"Opening",
				   @"Buffering",
				   @"Indexing",
				   @"Initializing",
				   @"Seeking",
				   nil];
	
	// detect 64bit host
	int is64bit;
	size_t len = sizeof(is64bit);
	if (!sysctlbyname("hw.optional.x86_64",&is64bit,&len,NULL,0))
		is64bitHost = (BOOL)is64bit;
}

/************************************************************************************
 INIT & UNINIT
 ************************************************************************************/
- (id)init
{
	if (!(self = [super init]))
		return  nil;
	
	buffer_name = @"mplayerosx";
	
	clients = [NSMutableArray new];
	
	osdLevel = 1;

	myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
	
	stateMask = (1<<state);
	
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
	
	// Watch for subtitle size changes
	[PREFS addObserver:self
			forKeyPath:MPESubtitleScale
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
- (void) addClient:(id<MPlayerInterfaceClientProtocol>)client
{
	if ([clients containsObject:client])
		return;
	
	[clients addObject:client];
	
	// send initial state update
	if ([client respondsToSelector:@selector(interface:hasChangedStateTo:fromState:)])
		[client interface:self hasChangedStateTo:[NSNumber numberWithUnsignedInt:state] 
									   fromState:[NSNumber numberWithUnsignedInt:MIStateInitializing]];
	// send initial time update
	if ([client respondsToSelector:@selector(interface:timeUpdate:)])
		[client interface:self timeUpdate:[NSNumber numberWithFloat:mySeconds]];
	// send initial volume update
	if ([client respondsToSelector:@selector(interface:volumeUpdate:isMuted:)])
		[client interface:self volumeUpdate:[NSNumber numberWithFloat:playerVolume]
									isMuted:[NSNumber numberWithBool:playerMute]];
}

- (void) removeClient:(id<MPlayerInterfaceClientProtocol>)client
{
	[clients removeObject:client];
}

- (void) notifyClientsWithSelector:(SEL)selector andObject:(id)object
{
	for (id<MPlayerInterfaceClientProtocol> client in clients) {
		if (client && [client respondsToSelector:selector]) {
			[client performSelector:selector withObject:self withObject:object];
		}
	}
}

- (void) notifyClientsWithSelector:(SEL)selector andObject:(id)object andObject:(id)otherObject
{
	NSMethodSignature *sig = [@protocol(MPlayerInterfaceClientProtocol) methodSignatureForSelector:selector
																						isRequired:NO
																				  isInstanceMethod:YES];
	NSInvocation *performer = [NSInvocation invocationWithMethodSignature:sig];
	
	[performer setSelector:selector];
	[performer setArgument:&self atIndex:2];
	[performer setArgument:&object atIndex:3];
	[performer setArgument:&otherObject atIndex:4];
	
	for (id<MPlayerInterfaceClientProtocol> client in clients) {
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
	
	for (NSString *name in localPrefsToObserve) {
		[[playingItem prefs] addObserver:self
							  forKeyPath:name
								 options:NSKeyValueObservingOptionNew
								 context:nil];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(loadNewSubtitleFile:)
												 name:MPEMovieInfoAddedExternalSubtitleNotification
											   object:playingItem];
}

- (void)unregisterPlayingItem
{
	for (NSString *name in localPrefsToObserve) {
		[[playingItem prefs] removeObserver:self forKeyPath:name];
	}
	
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
	
	PreferencesController2 *pc = [[AppController sharedController] preferencesController];
	
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
		NSArray *arches = [pc objectForInfoKey:@"MPEBinaryArchs" 
									  ofBinary:[cPrefs objectForKey:MPESelectedBinary]];
		if ([arches containsObject:@"i386"])
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
	
	// playback speed
	if ([cPrefs objectForKey:MPEPlaybackSpeed] && [cPrefs floatForKey:MPEPlaybackSpeed] != 1.0) {
		[params addObject:@"-speed"];
		[params addObject:[NSString stringWithFormat:@"%.2f", [cPrefs floatForKey:MPEPlaybackSpeed]]];
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
		if ([self mplayerOSDLevel] != 1) {
			[params addObject:@"-osdlevel"];
			[params addObject:[NSString stringWithFormat:@"%i",[self mplayerOSDLevel]]];
		}
	}
	
	// subtitles scale
	if ([cPrefs floatForKey:MPEOSDScale] > 0) {
		[params addObject:@"-subfont-osd-scale"];
		[params addObject:[NSString stringWithFormat:@"%.3f",[cPrefs floatForKey:MPEOSDScale]*6.0]];
	}
	
	// subtitle delay
	if ([cPrefs floatForKey:MPESubtitleDelay] != 0) {
		[params addObject:@"-subdelay"];
		[params addObject:[NSString stringWithFormat:@"%.2f", [cPrefs floatForKey:MPESubtitleDelay]]];
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
	if (!playerMute) {
		float volume = playerVolume;
		if ([cPrefs objectForKey:MPEAudioItemRelativeVolume])
			volume *= [cPrefs floatForKey:MPEAudioItemRelativeVolume];
		[params addObject:@"-volume"];
		[params addObject:[NSString stringWithFormat:@"%.2f", volume]];	
	} else {
		[params addObject:@"-volume"];
		[params addObject:@"0"];
	}
	
	// audio delay
	if ([cPrefs floatForKey:MPEAudioDelay] != 0) {
		[params addObject:@"-delay"];
		[params addObject:[NSString stringWithFormat:@"%.2f", [cPrefs floatForKey:MPEAudioDelay]]];
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
	}
	
	// add yuy2 or scale filter filter
	if ([cPrefs boolForKey:MPEUseYUY2VideoFilter]) {
		// MPlayer-GIT builds don't usually have the yuy2 filter
		BOOL hasFilter = [[pc objectForInfoKey:@"HasYUY2Filter" 
									  ofBinary:[cPrefs stringForKey:MPESelectedBinary]] boolValue];
		if (hasFilter) {
			// ass filter needs to in front of yuy2
			if (![cPrefs boolForKey:MPERenderSubtitlesFirst])
				[videoFilters addObject:@"ass"];
			[videoFilters addObject:@"yuy2"];
		}
	} else if ([cPrefs boolForKey:MPEVideoEqualizerEnabled])
		[videoFilters addObject:@"scale"];
	
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
	// seek after a restart
	} else if (mySeconds > 0) {
		[params addObject:@"-ss"];
		[params addObject:[NSString stringWithFormat:@"%1.1f",mySeconds]];
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
	if (isRunning) {
		if (!(stateMask & MIStateStoppedMask))
			[self sendCommand:@"quit"];
		[myMplayerTask waitUntilExit];
	}
}
/************************************************************************************/
- (void) pause
{
	[self sendToMplayersInput:@"pause\n"];
}
/************************************************************************************/
- (void) seek:(float)seconds mode:(int)aMode
{
	[self seek:seconds mode:aMode force:NO];
}

- (void) seek:(float)seconds mode:(int)aMode force:(BOOL)forced
{
	// Optimistically update local seconds
	if (aMode == MISeekingModeRelative)
		mySeconds += seconds;
	else if (aMode == MISeekingModeAbsolute)
		mySeconds = seconds;
	
	if (mySeconds < 0)
		mySeconds = 0;
	
	if (stateMask & MIStateCanSeekMask || forced) {
		
		// Don't use pausing_keep with seek to detect when MPlayer is playing
		// again and ready for the next seek. Instead use stateBeforeSeeking to
		// repause after seeking.
		[self sendCommand:[NSString stringWithFormat:@"seek %1.1f %d",seconds, aMode] 
				  withOSD:MISurpressCommandOutputConditionally andPausing:MICommandPausingNone];
		
		if (state != MIStateSeeking) {
			stateBeforeSeeking = state;
			[self setState:MIStateSeeking];
		}
		
	} else if (state == MIStateSeeking) {
		
		// Save missed seek
		[lastMissedSeek release];
		lastMissedSeek = [[NSDictionary alloc] initWithObjectsAndKeys:
						  [NSNumber numberWithFloat:seconds], @"seconds",
						  [NSNumber numberWithInt:aMode], @"mode", nil];
	}
}

- (BOOL) finishSeek
{
	if (state == MIStateSeeking && lastMissedSeek) {
		[self seek:[[lastMissedSeek objectForKey:@"seconds"] floatValue]
			  mode:[[lastMissedSeek objectForKey:@"mode"] intValue]
			 force:YES];
		[lastMissedSeek release];
		lastMissedSeek = nil;
		return YES;
	}
	return NO;
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
		[self sendCommand:[NSString stringWithFormat:@"osd %d",[self mplayerOSDLevel]]];
		if (object == [playingItem prefs] && osdLevel < 3)
			[self sendCommand:[NSString stringWithFormat:@"osd_show_property_text 'OSD: %@'",
							   [PreferencesController2 osdLevelDescriptionForLevel:osdLevel]]];
		
	} else if ([keyPath isEqualToString:MPEVideoEqualizerValues]) {
		[self applyVideoEqualizer];
	
	} else if ([keyPath isEqualToString:MPELoopMovie]) {
		[self sendCommand:[NSString stringWithFormat:@"set_property loop %d",((int)[[playingItem prefs] boolForKey:MPELoopMovie] - 1)]];
	
	} else if ([keyPath isEqualToString:MPEAudioItemRelativeVolume]) {
		[self applyVolume];
	
	} else if ([keyPath isEqualToString:MPESubtitleScale]) {
		float sub_scale = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		[self sendCommand:[NSString stringWithFormat:@"set_property sub_scale %f",sub_scale]];
	
	} else if ([keyPath isEqualToString:MPEPlaybackSpeed]) {
		float speed = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		[self sendCommand:[NSString stringWithFormat:@"speed_set %f",speed]
				  withOSD:MISurpressCommandOutputNever andPausing:MICommandPausingKeep];
	
	} else if ([keyPath isEqualToString:MPEAudioDelay]) {
		float delay = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		[self sendCommand:[NSString stringWithFormat:@"audio_delay %f 1",delay]
				  withOSD:MISurpressCommandOutputNever andPausing:MICommandPausingKeep];
		
	} else if ([keyPath isEqualToString:MPESubtitleDelay]) {
		float delay = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		[self sendCommand:[NSString stringWithFormat:@"sub_delay %f 1",delay]
				  withOSD:MISurpressCommandOutputNever andPausing:MICommandPausingKeep];
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
	[self sendCommand:@"get_property sub_file"];
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
	float volume = playerVolume;
	
	if ([[playingItem prefs] objectForKey:MPEAudioItemRelativeVolume])
		volume *= [[playingItem prefs] floatForKey:MPEAudioItemRelativeVolume];
	
	if (playerMute)
		[self sendCommand:[NSString stringWithFormat:@"set_property mute %d", playerMute]];
	else
		[self sendCommand:[NSString stringWithFormat:@"set_property volume %.2f", volume]];
	
	// Inform clients of change
	[self notifyClientsWithSelector:@selector(interface:volumeUpdate:isMuted:) 
						  andObject:[NSNumber numberWithFloat:volume]
						  andObject:[NSNumber numberWithBool:playerMute]];
}
/************************************************************************************/
- (void) setVolume:(float)volume isMuted:(BOOL)muted
{
	playerVolume = volume;
	playerMute = muted;
	
	[self applyVolume];
}
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
	if (state != newState) {
		unsigned int newStateMask = (1<<newState);
		MIState oldState = state;
		
		// Update isMovieOpen
		BOOL newIsMovieOpen = !!(newStateMask & MIStateRespondMask);
		if ([self isMovieOpen] != newIsMovieOpen)
			[self setMovieOpen:newIsMovieOpen];
		
		// Update isPlaying
		BOOL newIsPlaying = !!(newStateMask & MIStatePlayingMask);
		if ([self isPlaying] != newIsPlaying)
			[self setPlaying:newIsPlaying];
		
		state = newState;
		stateMask = newStateMask;
		
		// Notifiy clients of state change
		[self notifyClientsWithSelector:@selector(interface:hasChangedStateTo:fromState:) 
							  andObject:[NSNumber numberWithUnsignedInt:newState]
							  andObject:[NSNumber numberWithUnsignedInt:oldState]];
	}
}
/************************************************************************************/
- (float) seconds
{	
	return mySeconds;
}
/************************************************************************************/
- (BOOL) changesNeedRestart
{
	if (stateMask & MIStateStoppedMask)
		return NO;
	
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
	if (stateMask & MIStateStoppedMask)
		return NO;
	
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
	[self resetStatistics];
}

- (void) resetStatistics
{
	myCPUUsage			= -1;
	myAudioCPUUsage		= -1;
	myVideoCPUUsage		= -1;
	myCacheUsage		= -1;
	mySyncDifference	= NAN;
	myDroppedFrames		= -1;
	myPostProcLevel		= -1;
	if (playingItem)
		[playingItem setPlaybackStats:nil];
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
	
	BOOL quietCommand = (osdMode == MISurpressCommandOutputAlways || (osdMode == MISurpressCommandOutputConditionally && osdLevel == 1));
	
	if (quietCommand && !osdSilenced) {
		[self sendToMplayersInput:@"pausing_keep osd 0\n"];
		osdSilenced = YES;
		
	} else if (!quietCommand && osdSilenced) {
		[self sendToMplayersInput:[NSString stringWithFormat:@"pausing_keep osd %d\n", [self mplayerOSDLevel]]];
		osdSilenced = NO;
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
		
	if (osdSilenced)
		[self reactivateOsdAfterDelay];
}
/************************************************************************************/
- (void)sendCommands:(NSArray *)aCommands
{
	[self sendCommands:aCommands withOSD:MISurpressCommandOutputConditionally andPausing:MICommandPausingKeep];
}
/************************************************************************************/
- (int)mplayerOSDLevel
{
	return (osdLevel < 2 ? osdLevel : osdLevel - 1);
}

- (void)reactivateOsdAfterDelay {
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reactivateOsd) object:nil];
	[self performSelector:@selector(reactivateOsd) withObject:nil afterDelay:1.2];
}

- (void)reactivateOsd {
	
	[self sendToMplayersInput:[NSString stringWithFormat:@"pausing_keep osd %d\n", [self mplayerOSDLevel]]];
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
	
	// reset subtitle file id
	subtitleFileId = 0;
	
	// launch mplayer task
	[myMplayerTask launch];
	isRunning = YES;
	isReading = YES;
	[self setState:MIStateInitializing];
	
	[Debug log:ASL_LEVEL_INFO withMessage:@"Path to fontconfig: %@", [[myMplayerTask environment] objectForKey:@"FONTCONFIG_PATH"]];
}
/************************************************************************************/
- (void)sendToMplayersInput:(NSString *)aCommand
{
    if (myMplayerTask) {
		if ([myMplayerTask isRunning]) {
			@try {
				NSFileHandle *thePipe = [[myMplayerTask standardInput] fileHandleForWriting];
				[thePipe writeData:[aCommand dataUsingEncoding:NSUTF8StringEncoding]];
			}
			@catch (NSException * e) {
				[Debug log:ASL_LEVEL_WARNING withMessage:@"Pipe broke while trying to send command to MPlayer: %@",aCommand];
				if ([myMplayerTask isRunning])
					[myMplayerTask terminate];
			}
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
		
		if (!restartingPlayer && state > MIStateError)
			[self setState:MIStateStopped];
		
		mySeconds = 0;
		restartingPlayer = NO;
		isRunning = NO;
	}
	
	[self resetStatistics];
	
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
	
	} else
		// Check if we're ready again
		[self mplayerTermiantedAndFinishedReading];
}
/************************************************************************************/
- (void) mplayerTermiantedAndFinishedReading
{
	if (!isRunning && !isReading)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MIMPlayerExitedAndIsReady"
															object:self];
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
	if (data && [data length] > 0)
		[[[myMplayerTask standardOutput] fileHandleForReading]
			readInBackgroundAndNotifyForModes:parseRunLoopModes];
	// Nothing more to read
	else {
		isReading = NO;
		// Check we're ready again
		[self mplayerTermiantedAndFinishedReading];
	}
		
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
	
	// Use an intermediate state variable since state changes are
	// notified immediately and this can cause issues.
	// The new state is applied at the end of this function.
	int newState = state;
	
	BOOL streamsHaveChanged = NO;
	
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
		
		// Read next line of data
		line = [myLines objectAtIndex:lineIndex];
		
		//NSLog(@"%@",line);
		
		// skip empty lines
		if ([[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0)
			continue;
		
		if ([line hasPrefix:@"A:"] || [line hasPrefix:@"V:"]) {
			double timeDifference = ([NSDate timeIntervalSinceReferenceDate] - myLastUpdate);
				
			// parse the output according to the preset mode
			if ((newState == MIStateSeeking && timeDifference >= MI_SEEK_UPDATE_INTERVAL)
					|| timeDifference >= MI_STATS_UPDATE_INTERVAL) {
				int voCPUUsage = 0;
				myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
				
				NSArray *captures;
				if (myUpdateStatistics)
					captures = [line captureComponentsMatchedByRegex:MI_STATUS_REGEX];
				else
					captures = [line captureComponentsMatchedByRegex:MI_STATUS_SHORT_REGEX];
				
				if ((!myUpdateStatistics && [captures count] != 3)
					|| (myUpdateStatistics && [captures count] != 9)) {
					[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to read status line: %@",line];
					continue;
				}
				
				// Audio only
				if ([(NSString*)[captures objectAtIndex:MI_STATUS_VIDEO_TIME_INDEX] length] == 0) {
					
					mySeconds = [[captures objectAtIndex:MI_STATUS_AUDIO_TIME_INDEX] floatValue];
					
					if (myUpdateStatistics) {
						myAudioCPUUsage = [[captures objectAtIndex:MI_STATUS_FIRST_PERCENT_INDEX] floatValue];
						myCPUUsage = myAudioCPUUsage;
						if ([(NSString*)[captures objectAtIndex:MI_STATUS_SECOND_PERCENT_INDEX] length] > 0)
							myCacheUsage = [[captures objectAtIndex:MI_STATUS_SECOND_PERCENT_INDEX] intValue];
					}
					
				// Video
				} else {
					
					mySeconds = [[captures objectAtIndex:MI_STATUS_VIDEO_TIME_INDEX] floatValue];
					
					if (myUpdateStatistics) {
						if ([(NSString*)[captures objectAtIndex:MI_STATUS_AV_SYNC_INDEX] length] > 0)
							mySyncDifference = [[captures objectAtIndex:MI_STATUS_AV_SYNC_INDEX] floatValue];
						myVideoCPUUsage = [[captures objectAtIndex:MI_STATUS_FIRST_PERCENT_INDEX] intValue];
						voCPUUsage = [[captures objectAtIndex:MI_STATUS_SECOND_PERCENT_INDEX] intValue];
						myAudioCPUUsage = [[captures objectAtIndex:MI_STATUS_THIRD_PERCENT_INDEX] floatValue];
						myCPUUsage = myVideoCPUUsage + myAudioCPUUsage + voCPUUsage;
						myDroppedFrames = [[captures objectAtIndex:MI_STATUS_DROPPED_FRAMES_INDEX] intValue];
						if ([(NSString*)[captures objectAtIndex:MI_STATUS_FORUTH_PERCENT_INDEX] length] > 0)
							myCacheUsage = [[captures objectAtIndex:MI_STATUS_FORUTH_PERCENT_INDEX] intValue];
					}
					
				}
				
				// Update stats
				if (myUpdateStatistics) {
					NSMutableDictionary *stats = [NSMutableDictionary dictionary];
					[stats setObject:[statusNames objectAtIndex:newState] forKey:MIStatsStatusStringKey];
					if (myCPUUsage > -1)
						[stats setInteger:myCPUUsage forKey:MIStatsCPUUsageKey];
					if (myAudioCPUUsage > -1)
						[stats setFloat:myAudioCPUUsage forKey:MIStatsAudioCPUUsageKey];
					if (myVideoCPUUsage > -1)
						[stats setInteger:myVideoCPUUsage forKey:MIStatsVideoCPUUsageKey];
					if (myCacheUsage > -1)
						[stats setInteger:myCacheUsage forKey:MIStatsCacheUsageKey];
					if (!isnan(mySyncDifference))
						[stats setFloat:mySyncDifference forKey:MIStatsAVSyncKey];
					if (myDroppedFrames > -1)
						[stats setInteger:myDroppedFrames forKey:MIStatsDroppedFramesKey];
					
					[playingItem setPlaybackStats:stats];
				}
				
				[self notifyClientsWithSelector:@selector(interface:timeUpdate:) 
									  andObject:[NSNumber numberWithFloat:mySeconds]];
				
				// finish seek
				if (newState == MIStateSeeking && lastMissedSeek) {
					[self seek:[[lastMissedSeek objectForKey:@"seconds"] floatValue]
						  mode:[[lastMissedSeek objectForKey:@"mode"] intValue]
						 force:YES];
					[lastMissedSeek release];
					lastMissedSeek = nil;
					continue;
				}
				
				if (newState == MIStateSeeking) {
					newState = stateBeforeSeeking;
					if (stateBeforeSeeking == MIStatePaused)
						[self sendCommand:@"pause"];
					continue;
				}
				
				// if it was not playing before (launched or unpaused)
				if (newState != MIStatePlaying) {
					newState = MIStatePlaying;
					continue;
				}
			}
			
			continue;
		}
		
		//  =====  PAUSE  ===== test for paused state
		if ([line hasPrefix:MI_PAUSED_STRING]) {
			newState = MIStatePaused;
			continue;
		}
		
		// Exiting... test for player termination
		if ([line isMatchedByRegex:MI_EXIT_REGEX]) {
			
			NSString *exitType = [line stringByMatching:MI_EXIT_REGEX capture:1];
			
			// player reached end of file
			if ([exitType isEqualToString:@"EOF"])
				newState = MIStateFinished;
			// player was stopped
			else if ([exitType isEqualToString:@"QUIT"])
				newState = MIStateStopped;
			// an error occured (or unkown reason)
			else
				newState = MIStateError;
			
			// Parsing should now be finished
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MIFinishedParsing"
																object:self];
			
			mySeconds = 0;
			restartingPlayer = NO;
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithFormat:@"Exited with state %d and reason %@",newState,exitType]];
			continue;							// continue on next line
		}
		
		
		// parse command replies
		if ([line isMatchedByRegex:MI_REPLY_REGEX]) {
			
			// extract matches
			idName = [line stringByMatching:MI_REPLY_REGEX capture:1];
			idValue = [line stringByMatching:MI_REPLY_REGEX capture:2];
			
			BOOL isStreamSelection = NO;
			MPEStreamType streamType;
			
			// streams
			if ([idName isEqualToString:@"switch_video"]) {
				isStreamSelection = YES;
				streamType = MPEStreamTypeVideo;
			}
			
			if ([idName isEqualToString:@"switch_audio"]) {
				isStreamSelection = YES;
				streamType = MPEStreamTypeAudio;
			}
			
			if ([idName isEqualToString:@"sub_demux"]) {
				isStreamSelection = YES;
				streamType = MPEStreamTypeSubtitleDemux;
			}
			
			if ([idName isEqualToString:@"sub_file"]) {
				isStreamSelection = YES;
				streamType = MPEStreamTypeSubtitleFile;
			}
			
			if ([idName isEqualToString:@"sub_vob"]) {
				isStreamSelection = YES;
				streamType = MPEStreamTypeSubtitleVob;
			}
			
			if (isStreamSelection) {
				[self notifyClientsWithSelector:@selector(interface:hasSelectedStream:ofType:)
									  andObject:[NSNumber numberWithInt:[idValue intValue]]
									  andObject:[NSNumber numberWithUnsignedInt:streamType]];
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
			
			// subtitle vob streams
			if ([streamType isEqualToString:@"VSID"]) {
				
				if ([streamInfoName isEqualToString:@"LANG"]) {
					
					[playingItem setSubtitleStreamLanguage:streamInfoValue forId:streamId andType:SubtitleTypeVob];
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
				// ignore
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
			
			// subtitle vob streams
			if ([idName isEqualToString:@"VOBSUB_ID"]) {
				[playingItem newSubtitleStream:[idValue intValue] forType:SubtitleTypeVob];
				streamsHaveChanged = YES;
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
		
		// mplayer starts to open a file
		if ([line hasPrefix:MI_OPENING_STRING]) {
			newState = MIStateOpening;
			[Debug log:ASL_LEVEL_INFO withMessage:line];
			continue;	
		}
		
		// filling cache
		if ([line isMatchedByRegex:MI_CACHE_FILL_REGEX]) {
			newState = MIStateBuffering;
			myCacheUsage = [[line stringByMatching:MI_CACHE_FILL_REGEX capture:1] intValue];
			if (myUpdateStatistics) {
				NSMutableDictionary *stats = [playingItem playbackStats];
				if (!stats)
					stats = [NSMutableDictionary dictionary];
				[stats setInteger:myCacheUsage forKey:MIStatsCacheUsageKey];
				[playingItem setPlaybackStats:stats];
			}
			continue;
		}
		
		// get format of audio
		if ([line hasPrefix:MI_AUDIO_FILE_STRING]) {
			[playingItem setFileFormat:@"Audio"];
			continue;	
		}
		
		// get format of movie
		if ([line isMatchedByRegex:MI_FORMAT_REGEX]) {
			[playingItem setFileFormat:[line stringByMatching:MI_FORMAT_REGEX capture:1]];
			continue;
		}
		
		// rebuilding index
		if ([line isMatchedByRegex:MI_INDEXING_REGEX]) {
			newState = MIStateIndexing;
			// TODO: Read fill state
			continue;
		}
		
		// mplayer is starting playback -- ignore for preflight
		if ([line hasPrefix:MI_STARTING_STRING] && !isPreflight) {
			newState = MIStatePlaying;
			myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
			
			if (pausedOnRestart)
				[self sendCommand:@"pause"];
			
			[Debug log:ASL_LEVEL_INFO withMessage:line];
			continue;
		}
		
		// print unused output
		[Debug log:ASL_LEVEL_INFO withMessage:line];
		
	} // while
	
	if (newState != state)
		[self setState:newState];
	
	// post notification if there is anything in user info
	if (streamsHaveChanged) {
		[self notifyClientsWithSelector:@selector(interface:streamUpate:) andObject:playingItem];
	}
	
	[data release];
}

@end

/************************************************************************************/
