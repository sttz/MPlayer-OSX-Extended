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

// directly parsed mplayer output strings
// strings that are used to get certain data from output are not included
#define MI_PAUSED_STRING			"=====  PAUSE  ====="
#define MI_EXITING_STRING			"Exiting..."
#define MI_EXITING_QUIT_STRING		"Exiting... (Quit)"
#define MI_EXITING_EOF_STRING		"Exiting... (End of file)"
#define MI_OPENING_STRING			"Playing "
#define MI_AUDIO_FILE_STRING		"Audio file detected."
#define MI_STARTING_STRING			"Starting playback..."

#define MI_DEFINE_REGEX				@"^ID_(.*)=(.*)$"
#define MI_REPLY_REGEX				@"^ANS_(.*)=(.*)$"
#define MI_STREAM_REGEX				@"^ID_(.*)_(\\d+)_(.*)=(.*)$"
#define MI_MKVCHP_REGEX				@"^\\[mkv\\] Chapter (\\d+) from (\\d+):(\\d+):(\\d+\\.\\d+) to (\\d+):(\\d+):(\\d+\\.\\d+), (.+)$"
#define MI_EXIT_REGEX				@"^ID_EXIT=(.*)$"
#define MI_NEWLINE_REGEX			@"(?:\r\n|[\n\v\f\r\302\205\\p{Zl}\\p{Zp}])"

#define MI_STATS_UPDATE_INTERVAL	0.5f // Stats update interval when playing
#define MI_SEEK_UPDATE_INTERVAL		0.1f // Stats update interval while seeking

#define MI_LAVC_MAX_THREADS			8

// run loop modes in which we parse MPlayer's output
static NSArray* parseRunLoopModes;

@implementation MplayerInterface
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
	
	if (parseRunLoopModes==nil)
		parseRunLoopModes = [[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil] retain];
	
	myPathToPlayer = [aPath retain];
	buffer_name = @"mplayerosx";
	
	info = [[MovieInfo alloc] init];
	myCommandsBuffer = [[NSMutableArray array] retain];
	mySeconds = 0;
	myVolume = 100;
	
	mySubtitlesFiles = [[NSMutableArray alloc] init];
	
	// *** playback
	correctPTS = NO;
	cacheSize = 0;
	// addParams
	
	// *** display
	displayType = 0;
	flipVertical = NO;
	flipHorizontal = NO;
	movieSize = NSMakeSize(0,0);
	aspectRatio = 0;
	deviceId = 0;
	voModule = 0;
	screenshotPath = nil;
	
	// *** text
	osdLevel = 1;
	osdScale = 100;
	
	// *** video
	videoCodecs = @"";
	enableVideo = YES;
	framedrop = 0;
	fastLibavcodec = NO;
	deinterlace = NO;
	postprocessing = 0;
	assSubtitles = YES;
	embeddedFonts = YES;
	subScale = 100;
	assPreFilter = NO;
	
	// *** audio
	audioCodecs = @"";
	enableAudio = YES;
	hrtfFilter = NO;
	karaokeFilter = NO;
	
	// *** advanced
	equalizerEnabled = NO;
	videoEqualizerEnabled = NO;
	
	// properties
	myRebuildIndex = NO;
//	myadvolume = 30;

	myState = 0;
	myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
	settingsChanged = NO;
	restartingPlayer = NO;
	pausedOnRestart = NO;
	isRunning = NO;
	isPlaying = NO;
	takeEffectImediately = NO;
	useIdentifyForPlayback = NO;
	myOutputReadMode = 0;
	myUpdateStatistics = NO;
	isPreflight = NO;
	
	windowedVO = NO;
	isFullscreen = NO;
	
	// Disable MPlayer AppleRemote code unconditionally, as it causing problems 
	// when MPlayer runs in background only and we provide our own AR implementation.
	disableAppleRemote = YES;
	
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
	[subEncoding release];
	[addParams release];
	[myCommandsBuffer release];
	[info release];
	[audioLanguages release];
	[subtitleLanguages release];
	[videoCodecs release];
	[audioCodecs release];
	[equalizerValues release];
	[lastUnparsedLine release];
	[lastUnparsedErrorLine release];
	[buffer_name release];
	
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

/************************************************************************************
 PLAYBACK CONTROL
 ************************************************************************************/
- (void) playWithInfo:(MovieInfo *)mf
{
	NSMutableArray *params = [NSMutableArray array];
	NSMutableArray *videoFilters = [NSMutableArray array];
	NSMutableArray *audioFilters = [NSMutableArray array];
	NSMutableArray *audioCodecsArr = [NSMutableArray array];
	
	// Detect number of cores/cpus
	size_t len = sizeof(numberOfThreads);
	if (sysctlbyname("hw.ncpu",&numberOfThreads,&len,NULL,0))
		numberOfThreads = 1;
	if (numberOfThreads > MI_LAVC_MAX_THREADS)
		numberOfThreads = MI_LAVC_MAX_THREADS;
	
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
	if (audioLanguages) {
		[params addObject:@"-alang"];
		[params addObject:audioLanguages];
	}
	// subtitle languages
	if (subtitleLanguages) {
		[params addObject:@"-slang"];
		[params addObject:subtitleLanguages];
	}
	// correct pts
	if (correctPTS)
		[params addObject:@"-correct-pts"];
	// cache settings
	if (cacheSize > 0) {
		[params addObject:@"-cache"];
		[params addObject:[NSString stringWithFormat:@"%d",cacheSize]];
	}
	// number of threads
	if (numberOfThreads > 0) {
		[params addObject:@"-lavdopts"];
		[params addObject:[NSString stringWithFormat:@"threads=%d",numberOfThreads]];
	}
	
	
	// *** DISPLAY
	// display type
	switch (displayType) {
		case 1: // windowed
			break;
		case 2: // ontop
			[params addObject:@"-ontop"];
			break;
		case 3: // fullscreen
			[params addObject:@"-fs"];
			isFullscreen = YES;
			break;
		case 4: // rootwin
			[params addObject:@"-rootwin"];
			[params addObject:@"-fs"];
			break;
		default:
			break;
	}
	// flip vertical
	if (flipVertical) {
		[videoFilters addObject:@"flip"];
	}
	// flip horizontal
	if (flipHorizontal) {
		[videoFilters addObject:@"mirror"];
	}
	// movie size
	if (movieSize.width != 0) {
		if (movieSize.height != 0) {
			[params addObject:@"-x"];
			[params addObject:[NSString stringWithFormat:@"%1.1f",movieSize.width]];
			[params addObject:@"-y"];
			[params addObject:[NSString stringWithFormat:@"%1.1f",movieSize.height]];
		}
		else {
			[params addObject:@"-xy"];
			[params addObject:[NSString stringWithFormat:@"%1.1f",movieSize.width]];
		}
	}
	// aspect ratio
	if (aspectRatio > 0) {
		[params addObject:@"-aspect"];
		[params addObject:[NSString stringWithFormat:@"%1.6f", aspectRatio]];
	}
	// video output
	// force corevideo for rootwin if mplayerosx is selected
	if (displayType == 4 && voModule == 2)
		voModule = 1;
	//core video
	if(voModule == 1) 
	{
		[params addObject:@"-vo"];
		[params addObject:[@"corevideo:device_id=" stringByAppendingString: [[NSNumber numberWithUnsignedInt: deviceId] stringValue]]];
		windowedVO = YES;
	}
	//mplayer osx
	else if(voModule == 2) 
	{
		[params addObject:@"-vo"];
		[params addObject:[NSString stringWithFormat:@"corevideo:buffer_name=%@:device_id=%i",buffer_name, deviceId]];
		windowedVO = NO;
	}
	//quartz/quicktime
	else 
	{
		[params addObject:@"-vo"];
		[params addObject:[@"quartz:device_id=" stringByAppendingString: [[NSNumber numberWithUnsignedInt: deviceId] stringValue]]];
		windowedVO = YES;
	}
	
	
	
	// *** TEXT
	
	// add font
	if (myFontFile) {
		[params addObject:@"-font"];
		[params addObject:myFontFile];
	}
	// guess encoding with enca
	if (guessEncodingLang) {
		if (!subEncoding)
			subEncoding = @"none";
		[params addObject:@"-subcp"];
		[params addObject:[NSString stringWithFormat:@"enca:%@:%@", guessEncodingLang, subEncoding]];
	// fix encoding
	} else if (subEncoding) {
		[params addObject:@"-subcp"];
		[params addObject:subEncoding];
	}
	// ass subtitles
	if (assSubtitles) {
		[params addObject:@"-ass"];
	}
	// subtitles scale
	if (subScale > 0) {
		if (assSubtitles) {
			[params addObject:@"-ass-font-scale"];
			[params addObject:[NSString stringWithFormat:@"%.3f",(subScale/100.0)]];
		} else {
			[params addObject:@"-subfont-text-scale"];
			[params addObject:[NSString stringWithFormat:@"%.3f",(5.0*(subScale/100.0))]];
		}
	}
	if (assSubtitles) {
		// embedded fonts
		if (embeddedFonts) {
			[params addObject:@"-embeddedfonts"];
		}
		// ass pre filter
		if (assPreFilter) {
			[videoFilters insertObject:@"ass" atIndex:0];
		}
		// subtitles color
		if (subColor) {
			CGFloat red, green, blue, alpha;
			[subColor getRed:&red green:&green blue:&blue alpha:&alpha];
			[params addObject:@"-ass-color"];
			[params addObject:[NSString stringWithFormat:@"%02X%02X%02X%02X",(unsigned)(red*255),(unsigned)(green*255),(unsigned)(blue*255),(unsigned)((1-alpha)*255)]];
		}
		// subtitles color
		if (subBorderColor) {
			CGFloat red, green, blue, alpha;
			[subBorderColor getRed:&red green:&green blue:&blue alpha:&alpha];
			[params addObject:@"-ass-border-color"];
			[params addObject:[NSString stringWithFormat:@"%02X%02X%02X%02X",(unsigned)(red*255),(unsigned)(green*255),(unsigned)(blue*255),(unsigned)((1-alpha)*255)]];
		}
	}
	if (osdLevel != 1 && osdLevel != 2) {
		[params addObject:@"-osdlevel"];
		[params addObject:[NSString stringWithFormat:@"%i",(osdLevel == 0 ? 0 : osdLevel - 1)]];
	}
	// osd scale
	if (osdScale > 0) {
		[params addObject:@"-subfont-osd-scale"];
		[params addObject:[NSString stringWithFormat:@"%.3f",(6.0*(osdScale/100.0))]];
	}
	// always enable fontconfig
	[params addObject:@"-fontconfig"];
	
	
	
	
	// *** VIDEO
	// enable video
	if (!enableVideo) {
		[params addObject:@"-vc"];
		[params addObject:@"null"];
	// video codecs
	}
	else if ([videoCodecs length] > 0) {
		[params addObject:@"-vc"];
		[params addObject:videoCodecs];
	}
	// framedrop
	switch (framedrop) {
		case 0: // disabled
			break;
		case 1: // soft
			[params addObject:@"-framedrop"];
			break;
		case 2: // hard
			[params addObject:@"-hardframedrop"];
			break;
	}
	// fast libavcodec
	if (fastLibavcodec) {
		[params addObject:@"-lavdopts"];
		[params addObject:@"fast"];
	}
	// deinterlace
	switch (deinterlace) {
		case 0: // disabled
			break;
		case 1: // yadif
			[videoFilters addObject:@"yadif=1"];
			break;
		case 2: // kernel
			[videoFilters addObject:@"kerndeint"];
			break;
		case 3: // ffmpeg
			[videoFilters addObject:@"pp=fd"];
			break;
		case 4: // film
			[videoFilters addObject:@"filmdint"];
			break;
		case 5: // blend
			[videoFilters addObject:@"pp=lb"];
			break;
	}
	// postprocessing
	switch (postprocessing) {
		case 0: // disabled
			break;
		case 1: // default
			[videoFilters addObject:@"pp=default"];
			break;
		case 2: // fast
			[videoFilters addObject:@"pp=fast"];
			break;
		case 3: // high quality
			[videoFilters addObject:@"pp=ac"];
			break;
	}
	// skip loopfilters
	if (skipLoopfilter > 0) {
		[params addObject:@"-lavdopts"];
		switch (skipLoopfilter) {
			case 1: // NoRef
				[params addObject:@"skiploopfilter=noref"];
				break;
			case 2: // DiDir
				[params addObject:@"skiploopfilter=bidir"];
				break;
			case 3: // NoKey
				[params addObject:@"skiploopfilter=nokey"];
				break;
			case 4: // All
				[params addObject:@"skiploopfilter=all"];
				break;
		}
	}
	
	
	// *** AUDIO
	// enable audio
	if (!enableAudio)
		[params addObject:@"-nosound"];
	// audio codecs
	if ([audioCodecs length] > 0) {
		[audioCodecsArr addObject:audioCodecs];
	}
	// ac3/dts passthrough
	if (passthroughAC3) {
		[audioCodecsArr insertObject:@"hwac3" atIndex:0];
	}
	if (passthroughDTS) {
		[audioCodecsArr insertObject:@"hwdts" atIndex:0];
	}
	// hrtf filter
	if (hrtfFilter) {
		[audioFilters addObject:@"resample=48000"];
		[audioFilters addObject:@"hrtf"];
	}
	// bs2b filter
	if (bs2bFilter) {
		[audioFilters addObject:@"bs2b"];
	}
	// karaoke filter
	if (karaokeFilter) {
		[audioFilters addObject:@"karaoke"];
	}
	// set initial volume
	[params addObject:@"-volume"];
	[params addObject:[NSString stringWithFormat:@"%u", myVolume]];
	
	
	
	// *** ADVANCED
	// aduio equalizer filter
	if (equalizerEnabled && equalizerValues && [equalizerValues count] == 10) {
		[audioFilters addObject:[@"equalizer=" stringByAppendingString: [equalizerValues componentsJoinedByString:@":"]]];
	}
	// video equalizer
	if (videoEqualizerEnabled && videoEqualizerValues && [videoEqualizerValues count] == 8) {
		[videoFilters addObject:[@"eq2=" stringByAppendingString: [videoEqualizerValues componentsJoinedByString:@":"]]];
	}
	
	
	
	// *** Video filters
	// add screenshot filter
	if (screenshotPath) {
		[videoFilters addObject:@"screenshot"];
	}
	// add filter chain
	if ([videoFilters count] > 0) {
		[params addObject:@"-vf-add"];
		[params addObject:[videoFilters componentsJoinedByString:@","]];
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
		if ([audioCodecs length] == 0)
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
	// set volume
/*	[params addObject:@"-aop"];
	[params addObject:[NSString stringWithFormat:@"list=volume:volume=%d", myVolume]];
*/	// append additional params
	
	// additional parameters
	if (addParams) {
		if ([addParams count] > 0)
			[params addObjectsFromArray:addParams];
	}
	
	
	
	[params addObject:@"-slave"];
	
	if (useIdentifyForPlayback)
		[params addObject:@"-identify"];
	
	// Disable Apple Remote
	if (disableAppleRemote)
		[params addObject:@"-noar"];
	
	// MovieInfo
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
	
	[self runMplayerWithParams:params];
}
/************************************************************************************/
- (void) play
{
	[self playWithInfo:nil];
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
//			myState = kPaused;
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
				[self sendCommand:[NSString stringWithFormat:@"seek %1.1f %d",seconds, aMode] withType:MI_CMD_SHOW_COND];
				myState = kSeeking;
			break;
		case kPaused:
				//[self sendCommand:@"pause"];
				[self sendCommand: [NSString stringWithFormat:@"seek %1.1f %d",seconds, aMode] withType:MI_CMD_SHOW_COND];
				myState = kSeeking;
				//[self sendCommand:@"pause"];
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
- (void) setFont:(NSString *)aFile
{
	if (aFile) {
		if (![aFile isEqualToString:myFontFile]) {
			[myFontFile autorelease];
			myFontFile = [aFile retain];
			settingsChanged = YES;
		}
	}
	else {
		if (myFontFile) {
			[myFontFile release];
			settingsChanged = YES;
		}
		myFontFile = nil;
	}
}
/************************************************************************************
 PLAYBACK
 ************************************************************************************/
- (void) setAudioLanguages:(NSString *)langString
{
	if (audioLanguages != langString) {
		audioLanguages = langString;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setSubtitleLanguages:(NSString *)langString
{
	if (subtitleLanguages != langString) {
		subtitleLanguages = langString;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setCorrectPTS:(BOOL)aBool
{
	if (correctPTS != aBool) {
		correctPTS = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setCacheSize:(unsigned int)kilobytes
{
	if (cacheSize != kilobytes) {
		cacheSize = kilobytes;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setAdditionalParams:(NSArray *)params
{
	if (addParams && params) {
		if (![addParams isEqualTo:params]) {
			if (addParams)
				[addParams release];
			
			if (params)
				addParams = [[NSArray arrayWithArray:params] retain];
			else
				addParams = nil;
			
			settingsChanged = YES;
		}
		return;
	}
	if (addParams == nil && params) {
		addParams = [[NSArray arrayWithArray:params] retain];
		settingsChanged = YES;
		return;
	}
	if (addParams && params == nil) {
		[addParams release];
		addParams = nil;
		settingsChanged = YES;
		return;
	}
}
/************************************************************************************
 VIDEO
 ************************************************************************************/
- (void) setVideoEnabled:(BOOL)aBool
{
	if (enableVideo != aBool) {
		enableVideo = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setVideoCodecs:(NSString *)codecString
{
	if (videoCodecs != codecString) {
		[videoCodecs release];
		videoCodecs = [codecString retain];;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setFramedrop:(unsigned int)mode
{
	if (framedrop != mode) {
		framedrop = mode;
		if (myState == kPlaying || myState == kPaused || myState == kSeeking)
			[myCommandsBuffer addObject:[@"frame_drop=" stringByAppendingString: [[NSNumber numberWithInt: mode] stringValue]]];
	}
}
/************************************************************************************/
- (void) setFastLibavcodec:(BOOL)aBool
{
	if (fastLibavcodec != aBool) {
		fastLibavcodec = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setSkipLoopfilter:(unsigned int)mode
{
	if (skipLoopfilter != mode) {
		skipLoopfilter = mode;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setDeinterlace:(unsigned int)mode
{
	if (deinterlace != mode) {
		deinterlace = mode;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setVideoEqualizer:(NSArray *)values;
{
	if (videoEqualizerValues && values && ![videoEqualizerValues isEqualTo:values]) {
		[videoEqualizerValues release];
		videoEqualizerValues = [[NSArray arrayWithArray:values] retain];
		settingsChanged = YES;
		return;
	}
	if (videoEqualizerValues == nil && values) {
		videoEqualizerValues = [[NSArray arrayWithArray:values] retain];
		settingsChanged = YES;
		return;
	}
	if (videoEqualizerValues && values == nil) {
		[videoEqualizerValues release];
		videoEqualizerValues = nil;
		settingsChanged = YES;
		return;
	}
}
/************************************************************************************/
- (void) setPostprocessing:(unsigned int)mode
{
	if (postprocessing != mode) {
		postprocessing = mode;
		settingsChanged = YES;
	}
}
/************************************************************************************
 AUDIO
 ************************************************************************************/
- (void) setAudioEnabled:(BOOL)aBool
{
	if (enableAudio != aBool) {
		enableAudio = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setAudioCodecs:(NSString *)codecString
{
	if ([audioCodecs isEqualToString:codecString]) {
		[audioCodecs release];
		audioCodecs = [codecString retain];
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setHRTFFilter:(BOOL)aBool
{
	if (hrtfFilter != aBool) {
		hrtfFilter = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setBS2BFilter:(BOOL)aBool
{
	if (bs2bFilter != aBool) {
		bs2bFilter = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setAC3Passthrough:(BOOL)aBool
{
	if (passthroughAC3 != aBool) {
		passthroughAC3 = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setDTSPassthrough:(BOOL)aBool
{
	if (passthroughDTS != aBool) {
		passthroughDTS = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setKaraokeFilter:(BOOL)aBool
{
	if (karaokeFilter != aBool) {
		karaokeFilter = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setEqualizer:(NSArray *)freqs
{
	int i;
	for (i=0; i < [freqs count]; i++) {
		if (![[freqs objectAtIndex:i] isKindOfClass: [NSNumber class]] 
				|| [[freqs objectAtIndex:i] floatValue] < -12.0 || [[freqs objectAtIndex:i] floatValue] > 12)
			[freqs setValue:[NSNumber numberWithFloat:0] forKey: [[NSNumber numberWithInt:i] stringValue]];
	}
	
	if (equalizerValues && freqs && ![equalizerValues isEqualTo:freqs]) {
		[equalizerValues release];
		equalizerValues = [[NSArray arrayWithArray:freqs] retain];
		settingsChanged = YES;
		return;
	}
	if (equalizerValues == nil && freqs) {
		equalizerValues = [[NSArray arrayWithArray:freqs] retain];
		settingsChanged = YES;
		return;
	}
	if (equalizerValues && freqs == nil) {
		[equalizerValues release];
		equalizerValues = nil;
		settingsChanged = YES;
		return;
	}
}
/************************************************************************************
 DISPLAY
 ************************************************************************************/
- (void) setDisplayType:(unsigned int)mode
{
	if (displayType != mode) {
		displayType = mode;
		settingsChanged = YES;
		
		isOntop = (displayType == 2);
	}
}
/************************************************************************************/
- (void) setFlipVertical:(BOOL)aBool
{
	if (flipVertical != aBool) {
		flipVertical = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setFlipHorizontal:(BOOL)aBool
{
	if (flipHorizontal != aBool) {
		flipHorizontal = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setMovieSize:(NSSize)aSize
{
	if (aSize.width != movieSize.width ||  aSize.height != movieSize.height) {
		movieSize = aSize;
		settingsChanged = YES;
	}
}
- (NSSize) movieSize
{	
	return movieSize;
}
/************************************************************************************/
- (void) setAspectRatio:(double)ratio;
{
	if (aspectRatio != ratio) {
		aspectRatio = ratio;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setDeviceId:(unsigned int)dId
{
	if (deviceId != dId) {
		deviceId = dId;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (unsigned int)getDeviceId
{
	return deviceId;
}
/************************************************************************************/
- (void) setVideoOutModule:(int)module
{
	if (voModule != module)
	{
		voModule = module;
		settingsChanged = YES;
		videoOutChanged = YES;
	}
}
/************************************************************************************/
// ass subtitles
- (void) setAssSubtitles:(BOOL)aBool
{
	if (assSubtitles != aBool) {
		assSubtitles = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
// ass subtitles
- (void) setEmbeddedFonts:(BOOL)aBool
{
	if (embeddedFonts != aBool) {
		embeddedFonts = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setSubtitlesEncoding:(NSString *)aEncoding
{
	if (aEncoding) {
		if (![aEncoding isEqualToString:subEncoding]) {
			[subEncoding release];
			subEncoding = [aEncoding retain];
			settingsChanged = YES;
		}
	} else {
		if (subEncoding) {
			[subEncoding release];
			subEncoding = nil;
			settingsChanged = YES;
		}
	}
}
/************************************************************************************/
- (void) setGuessEncodingLang:(NSString *)aLang
{
	if (aLang) {
		if (![aLang isEqualToString:guessEncodingLang]) {
			[guessEncodingLang release];
			guessEncodingLang = [aLang retain];
			settingsChanged = YES;
		}
	} else {
		[guessEncodingLang release];
		guessEncodingLang = nil;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setSubtitlesScale:(unsigned int)aScale
{
	if (subScale != aScale) {
		subScale = aScale;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setSubtitlesColor:(NSColor *)color
{
	if (color != nil) {
		if (subColor == nil || 
				[color redComponent] != [subColor redComponent] ||
				[color greenComponent] != [subColor greenComponent] ||
				[color blueComponent] != [subColor blueComponent] ||
				[color alphaComponent] != [subColor alphaComponent]) {
			[subColor release];
			subColor = [color retain];
			settingsChanged = YES;
		}
	} else {
		[subColor release];
		subColor = nil;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setSubtitlesBorderColor:(NSColor *)color
{
	if (color != nil) {
		if (subBorderColor == nil || 
			[color redComponent] != [subBorderColor redComponent] ||
			[color greenComponent] != [subBorderColor greenComponent] ||
			[color blueComponent] != [subBorderColor blueComponent] ||
			[color alphaComponent] != [subBorderColor alphaComponent]) {
			[subBorderColor release];
			subBorderColor = [color retain];
			settingsChanged = YES;
		}
	} else {
		[subBorderColor release];
		subBorderColor = nil;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setOsdLevel:(int)anInt
{
	if (osdLevel != anInt) {
		osdLevel = anInt;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setOsdScale:(unsigned int)anInt {
	
	if (osdScale != anInt) {
		osdScale = anInt;
		settingsChanged = YES;
	}
}
/************************************************************************************/
// audio equalizer enabled
- (void) setEqualizerEnabled:(BOOL)aBool
{
	if (equalizerEnabled != aBool) {
		equalizerEnabled = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
// video equalizer enabled
- (void) setVideoEqualizerEnabled:(BOOL)aBool
{
	if (videoEqualizerEnabled != aBool) {
		videoEqualizerEnabled = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
// ass pre filter
- (void) setAssPreFilter:(BOOL)aBool
{
	if (assPreFilter != aBool) {
		assPreFilter = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setScreenshotPath:(NSString*)path
{
	if (screenshotPath != path) {
		[screenshotPath release];
		screenshotPath = [path retain];
		settingsChanged = YES;
	}
}
/************************************************************************************/

/************************************************************************************/
- (void) setRebuildIndex:(BOOL)aBool
{
	if (myRebuildIndex != aBool) {
		myRebuildIndex = aBool;
		settingsChanged = YES;
	}
}
/************************************************************************************/
////NEW BETA CODE
////VIDEO_TS
/*
- (void) setVIDEO_TS:(BOOL)aBool
{
	if (myVIDEO_TS != aBool) {
		myVIDEO_TS = aBool;
		settingsChanged = YES;
	}
}
*/

/************************************************************************************/
- (void) setFullscreen:(BOOL)aBool
{
	if (isFullscreen != aBool) {
		isFullscreen = aBool;
		if (myState == kPlaying || myState == kPaused || myState == kSeeking) {
			[myCommandsBuffer addObject:@"vo_fullscreen"];
			takeEffectImediately = YES;
		}
	}
}
- (BOOL) fullscreen
{
	return isFullscreen;
}
/************************************************************************************/
- (void) setOntop:(BOOL)ontop
{
	if (isOntop != ontop) {
		isOntop = ontop;
		if (myState > kStopped)
			[self sendCommand:[NSString stringWithFormat:@"pausing_keep_force set_property ontop %d",ontop]];
	}
}
/************************************************************************************/
- (void) setVolume:(unsigned int)percents
{
	if (myVolume != percents) {
		myVolume = percents;
		if (myState == kPlaying || myState == kPaused || myState == kSeeking)
			[myCommandsBuffer addObject:[NSString stringWithFormat:
					@"volume %d 1",myVolume]];
	}
}
/************************************************************************************/

/************************************************************************************/
- (void) applySettingsWithRestart:(BOOL)restartIt
{
	if ([self isRunning]) {
		if (settingsChanged && restartIt) {
			// all settings will be applied by restarting player
			restartingPlayer = YES;		// set it not to send termination notification
			[self play];				// restart playback if player is running
			takeEffectImediately = NO;
		}
		else {
			// only settings that don't need restart will be applied
			if ([myCommandsBuffer count] > 0) {
				if (myState == kPaused) {
					if (takeEffectImediately) {
						
						[self sendCommands:myCommandsBuffer withType:MI_CMD_SHOW_COND];
						[myCommandsBuffer removeAllObjects];
						takeEffectImediately = NO;
					}
				// else the commands will be sent on unpausing
				}
				else {
					
					[self sendCommands:myCommandsBuffer withType:MI_CMD_SHOW_COND];
					[myCommandsBuffer removeAllObjects];
				}
			}
		}
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
- (void) loadInfoBeforePlayback:(BOOL)aBool
{
	useIdentifyForPlayback = aBool;
}
/************************************************************************************/
- (void) loadInfo
{
	// clear the class
	[info release];
	info = [[MovieInfo alloc] init];
	
	// Set preflight mode
	isPreflight = YES;
	
	// run mplayer for identify
	if (myMovieFile)
		[self runMplayerWithParams:[NSArray arrayWithObjects:myMovieFile, @"-msglevel", @"identify=4:demux=6", @"-frames",@"0", @"-ao", @"null", @"-vo", @"null", nil]];
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
/************************************************************************************/
- (float) seconds
{	
	return mySeconds;
}
/************************************************************************************/
- (BOOL) changesNeedsRestart
{
	if (myState > 0)
		return settingsChanged;
	return NO;
}
/************************************************************************************/
- (BOOL) videoOutHasChanged
{
	return videoOutChanged;
}
/************************************************************************************/
- (BOOL)isRunning
{	
	return isRunning;
}

- (BOOL)isPlaying
{
	return isPlaying;
}

- (BOOL)isWindowed
{	
	return windowedVO;
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
- (void)sendCommand:(NSString *)aCommand withType:(uint)type
{
	[self sendCommands:[NSArray arrayWithObject:aCommand] withType:type];
}
/************************************************************************************/
- (void)sendCommand:(NSString *)aCommand
{
	[self sendCommand:aCommand withType:MI_CMD_SHOW_ALWAYS];
}
/************************************************************************************/
- (void)sendCommands:(NSArray *)aCommands withType:(uint)type
{	
	if ([aCommands count] == 0)
		return;
	
	BOOL quietCommand = (type == MI_CMD_SHOW_NEVER || (type == MI_CMD_SHOW_COND && osdLevel == 1));
	
	if (quietCommand && !osdSilenced) {
		//[Debug log:ASL_LEVEL_DEBUG withMessage:@"osd 0 (%@, %i, %i)\n",[aCommands objectAtIndex:0], type, osdLevel];
		[self sendToMplayersInput:@"pausing_keep osd 0\n"];
		osdSilenced = YES;
	}
	
	int i;
	for (i=0; i < [aCommands count]; i++) {
		[Debug log:ASL_LEVEL_DEBUG withMessage:@"Send Command: %@",[aCommands objectAtIndex:i]];
		[self sendToMplayersInput:[NSString stringWithFormat:@"%@\n", [aCommands objectAtIndex:i]]];
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
	[self sendCommands:aCommands withType:MI_CMD_SHOW_ALWAYS];
}
/************************************************************************************/
- (void)reactivateOsdAfterDelay {
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reactivateOsd) object:nil];
	[self performSelector:@selector(reactivateOsd) withObject:nil afterDelay:1.2];
}

- (void)reactivateOsd {
	//[Debug log:ASL_LEVEL_DEBUG withMessage:@"osd %d\n", (osdLevel < 2 ? osdLevel : osdLevel - 1)];
	
	if (myState == kPlaying) {
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
- (void)runMplayerWithParams:(NSArray *)aParams
{
	NSMutableDictionary *env;

	// terminate mplayer if it is running
	if (myMplayerTask) {
		if (myState == kPaused && restartingPlayer)
			pausedOnRestart = YES;
		else
			pausedOnRestart = NO;
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
	int count = 0;
	
	for(count = 0; count < [aParams count]; count++ )
		[Debug log:ASL_LEVEL_INFO withMessage:@"Arg: %@", [aParams objectAtIndex:count]];
	
	[Debug log:ASL_LEVEL_INFO withMessage:@"Command: mplayer %@", [aParams componentsJoinedByString:@" "]];
	
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
	isPlaying = YES;
	myState = kInitializing;
	
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
	int returnCode, bReadLog;
	
	// remove observers
	if (isRunning) {
		[[NSNotificationCenter defaultCenter] removeObserver:self
				name: NSTaskDidTerminateNotification object:myMplayerTask];
		
		if (!restartingPlayer && myState > 0) {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			
			myState = kStopped;
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
		// option to disable ffmpeg-mt
		NSString *otherButton = nil;
		if ([myPathToPlayer rangeOfString:@"mplayer-mt"].location != NSNotFound)
			otherButton = @"Restart without FFmpeg-MT";
		
		[Debug log:ASL_LEVEL_ERR withMessage:@"Abnormal playback error. mplayer returned error code: %d", returnCode];
		bReadLog = NSRunAlertPanel(@"Playback Error", @"Abnormal playback termination. Check log file for more information.", @"Continue", @"Open Log", otherButton);
		
		//Open Log file
		if(bReadLog == NSAlertAlternateReturn)
		{
			NSTask *finderOpenTask;
			NSArray *finderOpenArg;
			NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/MPlayerOSX.log"];

			finderOpenArg = [NSArray arrayWithObject:logPath];
			finderOpenTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:finderOpenArg];
			
			if (!finderOpenTask)
				[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to launch the console.app"];
		} 
		else if (bReadLog == NSAlertOtherReturn)
		{
			// post notification
			[[NSNotificationCenter defaultCenter]
					postNotificationName:@"MIRestartWithoutFFmpegMT"
					object:self];
		}
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
	
	while (1) {
		char *tempPtr;
		
		// Read next line of data
		lineIndex++;
		// check if end reached (save last unfinished line)
		if (lineIndex >= [myLines count] - 1) {
			[lastUnparsedLine release];
			if (lineIndex < [myLines count])
				lastUnparsedLine = [[myLines objectAtIndex:lineIndex] retain];
			else
				lastUnparsedLine = nil;
			break;
		}
		// load line
		line = [myLines objectAtIndex:lineIndex];
		
		// prepend unfinished line
		if (lastUnparsedLine) {
			line = [lastUnparsedLine stringByAppendingString:line];
			[lastUnparsedLine release];
			lastUnparsedLine = nil;
		}
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
							mySeconds =+ (3600 * hours + 60 * mins);
						}
						else if (sscanf(stringPtr, "A: %2d:%f %f%% %d%%", &mins,
								&mySeconds, &audioCPUUsage, &myCacheUsage) >= 3) {
							myCPUUsage = (int)audioCPUUsage;
							mySeconds =+ 60 * mins;
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
						myState = kPlaying;
						[self seek:[[lastMissedSeek objectForKey:@"seconds"] floatValue]
							  mode:[[lastMissedSeek objectForKey:@"mode"] intValue]];
						[lastMissedSeek release];
						lastMissedSeek = nil;
						continue;
					}
					
					// if it was not playing before (launched or unpaused)
					if (myState != kPlaying) {
						myState = kPlaying;
						[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
						
						// perform commands buffer
						[self sendCommands:myCommandsBuffer withType:MI_CMD_SHOW_COND];
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
			myState = kPaused;		
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			
			continue; 							// continue on next line
		}
		
		// Exiting... test for player termination
		if ([line isMatchedByRegex:MI_EXIT_REGEX]) {
			NSString *exitType = [line stringByMatching:MI_EXIT_REGEX capture:1];
			
			// player reached end of file
			if ([exitType isEqualToString:@"EOF"])
				myState = kFinished;
			// player was stopped (by user or with an error)
			else
				myState = kStopped;
			
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
			
			isPlaying = NO;
			
			restartingPlayer = NO;
			[Debug log:ASL_LEVEL_INFO withMessage:line];
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
					[Debug log:ASL_LEVEL_DEBUG withMessage:@"Chapter name: %d %@", streamId, streamInfoValue];
					[info setChapterName:streamInfoValue forId:streamId];
					continue;
				}
				
				if ([streamInfoName isEqualToString:@"START"]) {
					[Debug log:ASL_LEVEL_DEBUG withMessage:@"Chapter start: %d %@", streamId, streamInfoValue];
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
				[Debug log:ASL_LEVEL_DEBUG withMessage:@"New Chapter: %@", idValue];
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
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			continue;
		}
		
		
		// mplayer starts to open a file
		if (strncmp(stringPtr, MI_OPENING_STRING, 8) == 0) {
			myState = kOpening;
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
			continue; 							// continue on next line	
		}
		
		// filling cache
		if (strncmp(stringPtr, "Cache fill:", 11) == 0) {
			float cacheUsage;
			myState = kBuffering;
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
			myState = kIndexing;
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
			myState = kPlaying;
			myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
	
			// perform commands buffer
			[self sendCommand:[NSString stringWithFormat:@"volume %d 1",myVolume] withType:MI_CMD_SHOW_COND];
			[self sendCommands:myCommandsBuffer withType:MI_CMD_SHOW_COND];
			if (pausedOnRestart)
				[self sendCommand:@"pause"];
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
		[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithUTF8String:stringPtr]];
		
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
