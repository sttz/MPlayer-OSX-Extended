/*
 *  MplayerInterface.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "MplayerInterface.h"

// directly parsed mplayer output strings
// strings that are used to get certain data from output are not included
#define MI_PAUSED_STRING			"=====  PAUSE  ====="
#define MI_EXITING_STRING			"Exiting..."
#define MI_EXITING_QUIT_STRING		"Exiting... (Quit)"
#define MI_EXITING_EOF_STRING		"Exiting... (End of file)"
#define MI_OPENING_STRING			"Playing "
#define MI_AUDIO_FILE_STRING		"Audio file detected."
#define MI_STARTING_STRING			"Starting playback..."

#define MI_REFRESH_LIMIT			10

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
	
	myPathToPlayer = [aPath retain];

	info = [[MovieInfo alloc] init];
	myCommandsBuffer = [[NSMutableArray array] retain];
	mySeconds = 0;
	myVolume = 100;
	
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
	monitorAspect = 0;
	deviceId = 0;
	voModule = 0;
	screenshotPath = 1;
	
	// *** video
	enableVideo = YES;
	framedrop = 0;
	fastLibavcodec = NO;
	deinterlace = NO;
	postprocessing = 0;
	assSubtitles = YES;
	embeddedFonts = YES;
	subScale = 4;
	assPreFilter = NO;
	
	// *** audio
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
	takeEffectImediately = NO;
	useIdentifyForPlayback = NO;
	myOutputReadMode = 0;
	myUpdateStatistics = NO;
	isPreflight = NO;
	
	windowedVO = NO;
	isFullscreen = NO;
	
	lastUnparsedLine = @"";
	
	return self;
}

/************************************************************************************/
// release any retained objects
- (void) dealloc
{
	if (myMplayerTask)
		[myMplayerTask release];
	if (myPathToPlayer)
		[myPathToPlayer release];
	if (myMovieFile)
		[myMovieFile release];
	if (mySubtitlesFile)
		[mySubtitlesFile release];
	if (myAudioExportFile)
		[myAudioExportFile release];
	if (myAudioFile)
		[myAudioFile release];
	if (myFontFile)
		[myFontFile release];
	if (subEncoding)
		[subEncoding release];
	if (addParams)
		[addParams release];
	if (myCommandsBuffer)
		[myCommandsBuffer release];
	if (info)
		[info release];
	if (audioLanguages)
		[audioLanguages release];
	if (subtitleLanguages)
		[subtitleLanguages release];
	if (videoCodecs)
		[videoCodecs release];
	if (audioCodecs)
		[audioCodecs release];
	if (equalizerValues)
		[equalizerValues release];
	if (lastUnparsedLine)
		[lastUnparsedLine release];
	
	[super dealloc];
}

/************************************************************************************
 PLAYBACK CONTROL
 ************************************************************************************/
- (void) playWithInfo:(MovieInfo *)mf
{
	NSMutableArray *params = [NSMutableArray array];
	NSMutableArray *videoFilters = [NSMutableArray array];
	NSMutableArray *audioFilters = [NSMutableArray array];
	
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
	if (mySubtitlesFile) {
		[params addObject:@"-sub"];
		[params addObject:mySubtitlesFile];
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
	if (monitorAspect > 0) {
		[params addObject:@"-monitoraspect"];
		[params addObject:[NSString stringWithFormat:@"%1.6f", monitorAspect]];
	}
	// video output
	// force corevideo for rootwin if mplayerosx is selected
	if (displayType == 4 && voModule == 2)
		voModule = 1;
	//core video
	if(voModule == 1) 
	{
		[params addObject:@"-vo"];
		[params addObject:[@"macosx:device_id=" stringByAppendingString: [[NSNumber numberWithUnsignedInt: deviceId] stringValue]]];
		windowedVO = YES;
	}
	//mplayer osx
	else if(voModule == 2) 
	{
		[params addObject:@"-vo"];
		[params addObject:[@"macosx:shared_buffer:device_id=" stringByAppendingString: [[NSNumber numberWithUnsignedInt: deviceId] stringValue]]];
		windowedVO = NO;
	}
	//quartz/quicktime
	else 
	{
		[params addObject:@"-vo"];
		[params addObject:[@"quartz:device_id=" stringByAppendingString: [[NSNumber numberWithUnsignedInt: deviceId] stringValue]]];
		windowedVO = YES;
	}
	// ass pre filter
	if (assPreFilter) {
		[videoFilters insertObject:@"ass" atIndex:0];
	 } 
	
	
	
	// *** VIDEO
	// enable video
	if (!enableVideo) {
		[params addObject:@"-vc"];
		[params addObject:@"null"];
	// video codecs
	}
	else if (videoCodecs) {
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
		case 1: // ffmpeg
			[videoFilters addObject:@"pp=fd"];
			break;
		case 2: // blend
			[videoFilters addObject:@"pp=lb"];
			break;
		case 3: // blend sharp
			[videoFilters addObject:@"pp=l5"];
			break;
		case 4: // median
			[videoFilters addObject:@"pp=md"];
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
	// ass subtitles
	if (assSubtitles) {
		[params addObject:@"-ass"];
	}
	// embedded fonts
	if (embeddedFonts) {
		[params addObject:@"-embeddedfonts"];
	}
	// add font file
	if (myFontFile) {
		[params addObject:@"-font"];
		[params addObject:myFontFile];
	}
	// subtitles encoding
	if (subEncoding) {
		[params addObject:@"-subcp"];
		[params addObject:subEncoding];
	}
	// subtitles scale
	if (subScale != 0) {
		[params addObject:@"-subfont-text-scale"];
		[params addObject:[NSString stringWithFormat:@"%d",subScale]];
	}
	// always enable fontconfig
	[params addObject:@"-fontconfig"];
	
	
	
	// *** AUDIO
	// enable audio
	if (!enableAudio)
		[params addObject:@"-nosound"];
	// audio codecs
	if (audioCodecs) {
		[params addObject:@"-ac"];
		[params addObject:audioCodecs];
	}
	// hrtf filter
	if (hrtfFilter) {
		[audioFilters addObject:@"hrtf"];
	}
	// karaoke filter
	if (karaokeFilter) {
		[audioFilters addObject:@"karaoke"];
	}
	
	
	
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
	if (screenshotPath > 0) {
		[videoFilters addObject:@"screenshot"];
	}
	// add filter chain
	if ([videoFilters count] > 0) {
		[params addObject:@"-vf"];
		[params addObject:[videoFilters componentsJoinedByString:@","]];
	}
	
	// *** Audio Filters
	if ([audioFilters count] > 0) {
		[params addObject:@"-af"];
		[params addObject:[audioFilters componentsJoinedByString:@","]];
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
	
	if (useIdentifyForPlayback) {
		// -identify and demux=6 for matroska chapters
		[params addObject:@"-msglevel"];
		[params addObject:@"identify=4:demux=6"];
	}
	
	// MovieInfo
	if (mf == nil && (info == nil || ![myMovieFile isEqualToString:[info filename]])) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Create new MovieInfo"];
		[info release];
		info = [[MovieInfo alloc] init];		// prepare it for getting new values
	} else if (mf != nil)
		info = mf;
	
	[myCommandsBuffer removeAllObjects];	// empty buffer before launch
	settingsChanged = NO;					// every startup settings has been made
	
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
			if(!isFullscreen) [self sendCommand:@"osd 0"];
			[self sendCommand:[NSString stringWithFormat:@"seek %1.1f %d",seconds, aMode]];
			[self sendCommand:@"osd 1"];
			break;
		case kPaused:
				[self sendCommand:@"pause"];
				if(!isFullscreen) [self sendCommand:@"osd 0"];
				[self sendCommand: [NSString stringWithFormat:@"seek %1.1f %d",seconds, aMode]];
				[self sendCommand:@"osd 1"];
				[self sendCommand:@"pause"];
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
		if (![aFile isEqualToString:mySubtitlesFile]) {
			[mySubtitlesFile autorelease];
			mySubtitlesFile = [aFile retain];
			settingsChanged = YES;
			if (isRunning)
				[self performCommand: [NSString stringWithFormat:@"sub_load '%@'", aFile]];
		}
	}
	else {
		if (mySubtitlesFile) {
			[mySubtitlesFile release];
			settingsChanged = YES;
		}
		mySubtitlesFile = nil;
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
- (void) setFontFile:(NSString *)aFile
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
		videoCodecs = codecString;
		settingsChanged = YES;
	}
}
/************************************************************************************/
- (void) setFramedrop:(unsigned int)mode
{
	if (framedrop != mode) {
		framedrop = mode;
		if (myState == kPlaying || myState == kPaused)
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
	if (audioCodecs != codecString) {
		audioCodecs = codecString;
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
- (void) setMonitorAspectRatio:(double)ratio
{
	if (monitorAspect != ratio) {
		monitorAspect = ratio;
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
- (void) setVideoOutModule:(int)module
{
	if (voModule != module)
	{
		voModule = module;
		settingsChanged = YES;
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
- (void) setScreenshotPath:(int)mode
{
	if (screenshotPath != mode) {
		screenshotPath = mode;
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
		if (myState == kPlaying || myState == kPaused) {
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
- (void) setVolume:(unsigned int)percents
{
	if (myVolume != percents) {
		myVolume = percents;
		if (myState == kPlaying || myState == kPaused)
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
				NSMutableArray *commands = [NSMutableArray array];
				if (myState == kPaused) {
					if (takeEffectImediately) {
						[commands addObject:@"pause"];
						
						if(!isFullscreen) [commands addObject:@"osd 0"];
						[commands addObjectsFromArray:myCommandsBuffer];
						[commands addObject:@"osd 1"];
						[commands addObject:@"pause"];
						[self sendCommands:commands];
						[myCommandsBuffer removeAllObjects];
						takeEffectImediately = NO;
					}
					// else the commands will be sent on unpausing
				}
				else {
					if(!isFullscreen) [commands addObject:@"osd 0"];
					[commands addObjectsFromArray:myCommandsBuffer];
					[commands addObject:@"osd 1"];
					[self sendCommands:commands];
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
- (BOOL)isRunning
{	
	return isRunning;
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
 ADVENCED
 ************************************************************************************/
- (void)sendCommand:(NSString *)aCommand
{
	[self sendToMplayersInput:[aCommand stringByAppendingString:@"\n"]];
}
/************************************************************************************/
- (void)sendCommands:(NSArray *)aCommands
{
	int i;
	for (i=0; i < [aCommands count]; i++) {
		[self sendCommand:[aCommands objectAtIndex:i]];
	}
}
/************************************************************************************/
- (void) takeScreenshot
{
	[self sendToMplayersInput:@"screenshot 0\n"];
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
	}
	
	// if no path or movie file specified the return
	if (!myPathToPlayer || !myMovieFile)
		return;
	
	// initialize  mplayer task object
	myMplayerTask=[[NSTask alloc] init];
	
	// create standard input and output for application
	[myMplayerTask setStandardInput: [NSPipe pipe]];
	[myMplayerTask setStandardOutput: [NSPipe pipe]];
	
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
	
	// set working directory for screenshots
	switch (screenshotPath) {
		case 0: // disabled
			break;
		case 1: // desktop
			[myMplayerTask setCurrentDirectoryPath:
				[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
			break;
		case 2: // documents
			[myMplayerTask setCurrentDirectoryPath:
				[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
			break;
		case 3: // home
			[myMplayerTask setCurrentDirectoryPath:NSHomeDirectory()];
			break;
	}
	
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

	// activate notification for available data at output
	[[[myMplayerTask standardOutput] fileHandleForReading]
			readInBackgroundAndNotify];
	
	// reset output read mode
	myOutputReadMode = 0;
	// launch mplayer task
	[myMplayerTask launch];
	isRunning = YES;
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
	
	//abnormal mplayer task termination
	if (returnCode != 0)
	{
		[Debug log:ASL_LEVEL_ERR withMessage:@"Abnormal playback error. mplayer returned error code: %d", returnCode];
		bReadLog = NSRunAlertPanel(@"Playback Error", @"Abnormal playback termination. Check log file for more information.", @"Open Log", @"Continue", nil);
		
		//Open Log file
		if(bReadLog)
		{
			NSTask *finderOpenTask;
			NSArray *finderOpenArg;
			NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/MPlayerOSX.log"];

			finderOpenArg = [NSArray arrayWithObject:logPath];
			finderOpenTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:finderOpenArg];
			
			if (!finderOpenTask)
				[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to launch the console.app"];
		}
	}
}
/************************************************************************************/
- (void)readOutputC:(NSNotification *)notification
{
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	
	/*unsigned dataLength = [(NSData *)[[notification userInfo]
			objectForKey:@"NSFileHandleNotificationDataItem"] length] / sizeof(char);
	char *stringPtr = NULL, *dataPtr = malloc([(NSData *)[[notification userInfo]
			objectForKey:@"NSFileHandleNotificationDataItem"] length] + sizeof(char));
	
	// load data and terminate it with null character
	[[[notification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"]
				getBytes:(void *)dataPtr];
	*(dataPtr+dataLength) = '\0';*/
	
	// register for another read
	[[[myMplayerTask standardOutput] fileHandleForReading]
			readInBackgroundAndNotify];	
	
	NSString *data = [[NSString alloc] 
						initWithData:[[notification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"] 
						encoding:NSUTF8StringEncoding];
	
	const char *stringPtr;
	NSString *line;
	NSString *result;
	int subtitleFileId = -1;
	
	// Create newline character set
	NSMutableCharacterSet *newlineCharacterSet = (id)[NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    [newlineCharacterSet formIntersectionWithCharacterSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]];
	
	// Split data by newline characters
	NSArray *myLines = [self splitString:data byCharactersInSet:newlineCharacterSet];
	
	int lineIndex = -1;
	
	while (1) {
		char *tempPtr;
		
		// get the one line of data
		/*if (stringPtr == NULL)
			stringPtr = strtok((char *)dataPtr,"\n\r");
		else
			stringPtr = strtok(NULL,"\n\r");
		
		if  (stringPtr == NULL)
			break;*/
		
		// make an NSString for this line
		//line = [NSString stringWithCString:stringPtr];
		
		// Read next line of data
		lineIndex++;
		// check if end reached (save last unfinished line)
		if (lineIndex >= [myLines count] - 1) {
			[lastUnparsedLine release];
			if (lineIndex < [myLines count])
				lastUnparsedLine = [[myLines objectAtIndex:lineIndex] retain];
			break;
		}
		// load line
		line = [myLines objectAtIndex:lineIndex];
		// prepend unfinished line
		if (lastUnparsedLine != @"") {
			line = [lastUnparsedLine stringByAppendingString:line];
			lastUnparsedLine = @"";
		}
		
		//[Debug log:ASL_LEVEL_ERR withMessage:@"readOutputC: %@",line];
		
		// create cstring for legacy code
		stringPtr = [line lossyCString];
		
		if (strstr(stringPtr, "A:") == stringPtr ||
				strstr(stringPtr, "V:") == stringPtr) {
			double timeDifference = ([NSDate timeIntervalSinceReferenceDate] - myLastUpdate);
				
			// parse the output according to the preset mode
			if (timeDifference >= 1.0f) {
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
						if (sscanf(stringPtr, "V: %f %*d/%d*% %d%% %*f%% %d %d %d%%",
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
					
					// if it was not playing before (launched or unpaused)
					if (myState != kPlaying) {
						myState = kPlaying;
						[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
						
						// perform commands buffer
						if(!isFullscreen) [self sendCommand:@"osd 0"];
						[self sendCommands:myCommandsBuffer];
						[self sendCommand:@"osd 1"];
						[myCommandsBuffer removeAllObjects];	// clear command buffer
			
						continue; 							// continue on next line
					}
			
					// post notification
					[[NSNotificationCenter defaultCenter]
							postNotificationName:@"MIStateUpdatedNotification"
							object:self
							userInfo:nil];
					[userInfo removeAllObjects];
					continue;
				}
				else
					myOutputReadMode = 0;
			}
			else
				continue;
		}
		
		// parse current streams
		result = [self parseDefine:@"ANS_switch_video=" inLine:line];
		if (result != nil) {
			[userInfo setObject:[NSNumber numberWithInt:[result intValue]] forKey:@"VideoStreamId"];
			continue;
		}
		
		result = [self parseDefine:@"ANS_switch_audio=" inLine:line];
		if (result != nil) {
			[userInfo setObject:[NSNumber numberWithInt:[result intValue]] forKey:@"AudioStreamId"];
			continue;
		}
		
		result = [self parseDefine:@"ANS_sub_demux=" inLine:line];
		if (result != nil) {
			[userInfo setObject:[NSNumber numberWithInt:[result intValue]] forKey:@"SubDemuxStreamId"];
			continue;
		}
		
		result = [self parseDefine:@"ANS_sub_file=" inLine:line];
		if (result != nil) {
			[userInfo setObject:[NSNumber numberWithInt:[result intValue]] forKey:@"SubFileStreamId"];
			continue;
		}
		
		// current volume
		result = [self parseDefine:@"ANS_volume=" inLine:line];
		if (result != nil) {
			[userInfo setObject:[NSNumber numberWithDouble:[result doubleValue]] forKey:@"Volume"];
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
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithCString:stringPtr]];
			
			continue; 							// continue on next line
		}

		// Exiting... test for player termination
		if ((tempPtr = strstr(stringPtr, MI_EXITING_STRING)) != NULL) {
			// if user quits player
			if (strncmp(tempPtr, MI_EXITING_QUIT_STRING, 17) == 0)
				myState = kStopped;
			// if player reaches end of file
			if (strncmp(tempPtr, MI_EXITING_EOF_STRING, 24) == 0)
				myState = kFinished;
			// remove observer for output
				// it's here because the NSTask sometimes do not terminate
				// as it is supposed to do
			[[NSNotificationCenter defaultCenter] removeObserver:self
					name: NSFileHandleReadCompletionNotification
					object:[[myMplayerTask standardOutput] fileHandleForReading]];
			
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
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithCString:stringPtr]];
			continue;							// continue on next line
		}
		
		// if player is playing then do not bother with parse anything else
		if (myOutputReadMode > 0) {
			// print unused line
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithCString:stringPtr]];
			continue;
		}
		
		
		// mplayer starts to open a file
		if (strncmp(stringPtr, MI_OPENING_STRING, 8) == 0) {
			myState = kOpening;
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithCString:stringPtr]];
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
			/*[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithCString:stringPtr]];
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
			[info setFileFormat:[NSString stringWithCString:stringPtr]];
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
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithCString:stringPtr]];
			continue; 							// continue on next line	
		}
		
		// getting length
		result = [self parseDefine:@"ID_LENGTH=" inLine:line];
		if (result != nil) {
			[info setLength:[result intValue]];
			continue;
		}
		
		// movie width and height
		result = [self parseDefine:@"ID_VIDEO_WIDTH=" inLine:line];
		if (result != nil) {
			[info setVideoWidth:[result intValue]];
			continue;
		}
		result = [self parseDefine:@"ID_VIDEO_HEIGHT=" inLine:line];
		if (result != nil) {
			[info setVideoHeight:[result intValue]];
			continue;
		}
		
		// filename
		result = [self parseDefine:@"ID_FILENAME=" inLine:line];
		if (result != nil) {
			[info setFilename:result];
			continue;
		}
		
		// video format
		result = [self parseDefine:@"ID_VIDEO_FORMAT=" inLine:line];
		if (result != nil) {
			[info setVideoFormat:result];
			continue;
		}
		
		// video codec
		result = [self parseDefine:@"ID_VIDEO_CODEC=" inLine:line];
		if (result != nil) {
			[info setVideoCodec:result];
			continue;
		}
		
		// video bitrate
		result = [self parseDefine:@"ID_VIDEO_BITRATE=" inLine:line];
		if (result != nil) {
			[info setVideoBitrate:[result intValue]];
			continue;
		}
		
		// video fps
		result = [self parseDefine:@"ID_VIDEO_FPS=" inLine:line];
		if (result != nil) {
			[info setVideoFps:[result floatValue]];
			continue;
		}
		
		// video aspect
		result = [self parseDefine:@"ID_VIDEO_ASPECT=" inLine:line];
		if (result != nil) {
			[info setVideoAspect:[result floatValue]];
			continue;
		}
		
		// audio format
		result = [self parseDefine:@"ID_AUDIO_FORMAT=" inLine:line];
		if (result != nil) {
			[info setAudioFormat:result];
			continue;
		}
		
		// audio codec
		result = [self parseDefine:@"ID_AUDIO_CODEC=" inLine:line];
		if (result != nil) {
			[info setAudioCodec:result];
			continue;
		}
		
		// audio bitrate
		result = [self parseDefine:@"ID_AUDIO_BITRATE=" inLine:line];
		if (result != nil) {
			[info setAudioBitrate:[result intValue]];
			continue;
		}
		
		// audio sample rate
		result = [self parseDefine:@"ID_AUDIO_RATE=" inLine:line];
		if (result != nil) {
			[info setAudioSampleRate:[result floatValue]];
			continue;
		}
		
		// audio channels
		result = [self parseDefine:@"ID_AUDIO_NCH=" inLine:line];
		if (result != nil) {
			[info setAudioChannels:[result intValue]];
			continue;
		}
		
		// video streams
		result = [self parseDefine:@"ID_VIDEO_ID=" inLine:line];
		if (result != nil) {
			[info newVideoStream:[result intValue]];
			continue;
		}
		
		result = [self parseDefine:@"ID_VID_" inLine:line];
		if (result != nil) {
			
			unsigned int videoStreamId = [result intValue];
			
			if (videoStreamId < 10)
				result = [result substringFromIndex:1];
			else
				result = [result substringFromIndex:2];
			
			if ([result hasPrefix:@"_NAME"]) {
				
				[info setVideoStreamName:[result substringFromIndex:6] forId:videoStreamId];
				continue;
			}
			
		}
		
		// audio streams
		result = [self parseDefine:@"ID_AUDIO_ID=" inLine:line];
		if (result != nil) {
			[info newAudioStream:[result intValue]];
			continue;
		}
		
		result = [self parseDefine:@"ID_AID_" inLine:line];
		if (result != nil) {
			
			unsigned int audioStreamId = [result intValue];
			
			if (audioStreamId < 10)
				result = [result substringFromIndex:1];
			else
				result = [result substringFromIndex:2];
			
			if ([result hasPrefix:@"_NAME"]) {
				
				[info setAudioStreamName:[result substringFromIndex:6] forId:audioStreamId];
				continue;
			} else if ([result hasPrefix:@"_LANG"]) {
				
				[info setAudioStreamLanguage:[result substringFromIndex:6] forId:audioStreamId];
				continue;
			}
			
		}
		
		// subtitle demux streams
		result = [self parseDefine:@"ID_SUBTITLE_ID=" inLine:line];
		if (result != nil) {
			[info newSubtitleStream:[result intValue] forType:SubtitleTypeDemux];
			continue;
		}
		
		result = [self parseDefine:@"ID_SID_" inLine:line];
		if (result != nil) {
			
			unsigned int subtitleStreamId = [result intValue];
			
			if (subtitleStreamId < 10)
				result = [result substringFromIndex:1];
			else
				result = [result substringFromIndex:2];
			
			if ([result hasPrefix:@"_NAME"]) {
				
				[info setSubtitleStreamName:[result substringFromIndex:6] forId:subtitleStreamId andType:SubtitleTypeDemux];
				continue;
			} else if ([result hasPrefix:@"_LANG"]) {
				
				[info setSubtitleStreamLanguage:[result substringFromIndex:6] forId:subtitleStreamId andType:SubtitleTypeDemux];
				continue;
			}
			
		}
		
		// subtitle file streams
		result = [self parseDefine:@"ID_FILE_SUB_ID=" inLine:line];
		if (result != nil) {
			[info newSubtitleStream:[result intValue] forType:SubtitleTypeFile];
			subtitleFileId = [result intValue];
			continue;
		}
		
		result = [self parseDefine:@"ID_FILE_SUB_FILENAME=" inLine:line];
		if (result != nil) {
			
			[info setSubtitleStreamName:[result lastPathComponent] forId:subtitleFileId andType:SubtitleTypeFile];
			continue;
		}
		
		// getting other unparsed -identify parameters
		if ([line length] > 3 && [[line substringToIndex: 3] isEqualToString:@"ID_"])
		{
			NSArray *parts = [line componentsSeparatedByString:@"="];
			
			if ([parts count] == 2)
			{
				[Debug log:ASL_LEVEL_INFO withMessage:@"IDENTIFY: %@ = %@", [[parts objectAtIndex:0] substringFromIndex:3], [parts objectAtIndex:1]];
				[info setInfo:[parts objectAtIndex:1] forKey:[[parts objectAtIndex:0] substringFromIndex:3]];
			}
			continue; 							// continue on next line	
		}
		
		// mkv chapters
		
		
		// mplayer is starting playback -- ignore for preflight
		if (strstr(stringPtr, MI_STARTING_STRING) != NULL && !isPreflight) {
			myState = kPlaying;
			myLastUpdate = [NSDate timeIntervalSinceReferenceDate];
			[userInfo setObject:[NSNumber numberWithInt:myState] forKey:@"PlayerStatus"];
	
			// perform commands buffer
			if(!isFullscreen) [self sendCommand:@"osd 0"];
			[self sendCommand:[NSString stringWithFormat:@"volume %d 1",myVolume]];
			[self sendCommands:myCommandsBuffer];
			[self sendCommand:@"osd 1"];
			if (pausedOnRestart)
				[self sendCommand:@"pause"];
			[myCommandsBuffer removeAllObjects];
	
			// post status playback start
			[[NSNotificationCenter defaultCenter]
					postNotificationName:@"MIInfoReadyNotification"
					object:self
					userInfo:nil];
			[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithCString:stringPtr]];
			continue;
		}
		
		// print unused output
		[Debug log:ASL_LEVEL_INFO withMessage:[NSString stringWithCString:stringPtr]];
		
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
	[pool release];
}

-(NSString *)parseDefine:(NSString *)searchFor inLine:(NSString *)line {
	
	if ([line length] > [searchFor length] && [[line substringToIndex: [searchFor length]] isEqualToString:searchFor]) {
		return [line substringFromIndex:[searchFor length]];
	} else
		return nil;
}

-(NSArray *)splitString:(NSString *)string byCharactersInSet:(NSCharacterSet *)set {
	
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	NSMutableArray * result = [NSMutableArray array];
	NSScanner * scanner = [NSScanner scannerWithString:string];
	NSString * chunk = nil;
	BOOL endsWithMatch;
	
	// Don't ignore whitespace and newlines
	[scanner setCharactersToBeSkipped: nil];
	
	// Check beginning of string for match
	if ([scanner scanCharactersFromSet:set intoString:NULL]) {
		
		[result addObject:@""];
	}
	
	// Loop over string and split
	while([scanner scanUpToCharactersFromSet:set intoString:&chunk]) {
		
		[result addObject:chunk];
		// Scan to the end of character occurences
		endsWithMatch = [scanner scanCharactersFromSet:set intoString:NULL];
	}
	
	// Check end of string for match
	if (endsWithMatch) {
		
		[result addObject: @""];
	}
	
	result = [result copy];
	[pool release];
	result = [result autorelease];
	return result; 
	
}

@end

/************************************************************************************/
