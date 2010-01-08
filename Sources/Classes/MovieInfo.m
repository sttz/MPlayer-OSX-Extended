/*  
 *  MovieInfo.m
 *  MPlayerOSX Extended
 *  
 *  Created on 02.08.2008
 *  
 *  Description:
 *	Class used to store attributes of a video file.
 *  
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#import "MovieInfo.h"

#import "AppController.h"

#import "MplayerInterface.h"

#import "Preferences.h"
#import "CocoaAdditions.h"

// **************************************************** //

static NSMutableArray *preflightQueue;

static NSMutableArray *freePreflightInstances;
static NSMutableArray *busyPreflightInstances;

@interface MovieInfo (Preflight)
+ (void) queueForPreflight:(MovieInfo *)item;
+ (void) preflightNextItem;
+ (void) preflightFinished:(NSNotification *)notification;
+ (void) preflightFailed:(NSNotification *)notification;
+ (void) requeuePreflightInstance:(MplayerInterface*)inst;
@end


@implementation MovieInfo (Preflight)

+ (void) load {
	preflightQueue = [NSMutableArray new];
	freePreflightInstances = [NSMutableArray new];
	busyPreflightInstances = [NSMutableArray new];
}

+ (void) queueForPreflight:(MovieInfo *)item {
	
	[preflightQueue addObject:item];
	[self preflightNextItem];
}

+ (void) preflightNextItem {
	
	if ([preflightQueue count] == 0)
		return;
	
	// Wait for preferences controller to load
	if (![[AppController sharedController] preferencesController]) {
		[self performSelector:@selector(preflightNextItem) withObject:nil afterDelay:0];
		return;
	}
	
	if ([freePreflightInstances count] == 0) {
		// Create new instances on-demand
		if ([busyPreflightInstances count] < [PREFS integerForKey:MPEPreflightNumInstances]) {
			MplayerInterface *newInstance = [[MplayerInterface new] autorelease];
			[freePreflightInstances addObject:newInstance];
			// Listen for end of preflight
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(preflightFinished:)
														 name:@"MIFinishedParsing"
													   object:newInstance];
			// Listen for errors
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(preflightFailed:)
														 name:@"MIMplayerExitedAbnormally"
													   object:newInstance];
		// The number of allowed instances has been reached, wait for one to finish
		} else
			return;
	}
	
	// Dequeue next item
	MovieInfo *nextItem = [preflightQueue objectAtIndex:0];
	[preflightQueue removeObjectAtIndex:0];
	
	// Dequeue a free instance and add it to the busy queue
	MplayerInterface *inst = [freePreflightInstances objectAtIndex:0];
	[busyPreflightInstances addObject:inst];
	[freePreflightInstances removeObjectAtIndex:0];
	
	// Start preflight
	[inst loadInfo:nextItem];
}

+ (void) preflightFinished:(NSNotification *)notification {
	
	[self requeuePreflightInstance:[notification object]];
	[self preflightNextItem];
}

+ (void) preflightFailed:(NSNotification *)notification {
	
	MplayerInterface *inst = (MplayerInterface *)[notification object];
	[Debug log:ASL_LEVEL_ERR withMessage:@"Preflight failed for '%@'",[[inst info] filename]];
	
	[self requeuePreflightInstance:inst];
	[self preflightNextItem];
}

+ (void) requeuePreflightInstance:(MplayerInterface*)inst {
	
	[freePreflightInstances addObject:inst];
	[busyPreflightInstances removeObject:inst];
}

@end

// **************************************************** //

@implementation MovieInfo
@synthesize filename, prefs, fileFormat, seekable, length, filesize, fileModificationDate, fileCreationDate,
videoFormat, videoCodec, videoBitrate, videoWidth, videoHeight, videoFPS, videoAspect,
audioFormat, audioCodec, audioBitrate, audioSampleRate, audioChannels,
externalSubtitles, captureStats, playbackStats, player;

// **************************************************** //

+( MovieInfo *)movieInfoWithPathToFile:(NSString*)path {
	
	return [[[MovieInfo alloc] initWithPathToFile:path] autorelease];
}

+ (MovieInfo *)movieInfoFromDictionaryRepresentation:(NSDictionary *)dict {
	
	return [[[MovieInfo alloc] initWithDictionaryRepresentation:dict] autorelease];
}

// **************************************************** //

- (id) init {
	
	if (!(self = [super init]))
		return nil;
	
	[self initializeInstance];
	
	return self;
}

- (void) initializeInstance {
	
	if (!info)
		info     = [NSMutableDictionary new];
	
	if (!video)
		video    = [NSMutableDictionary new];
	if (!audio)
		audio    = [NSMutableDictionary new];
	if (!subtitle)
		subtitle = [NSMutableDictionary new];
	if (!subfile)
		subfile  = [NSMutableDictionary new];
	if (!chapter)
		chapter  = [NSMutableDictionary new];
	
	if (!externalSubtitles)
		externalSubtitles = [NSMutableArray new];
	
	if (!prefs)
		prefs    = [NSMutableDictionary new];
	
	[self addObserver:self
		   forKeyPath:@"filename" 
			  options:NSKeyValueObservingOptionNew 
			  context:nil];
	
	[self addObserver:self
		   forKeyPath:@"player"
			  options:(NSKeyValueObservingOptionNew|
					   NSKeyValueObservingOptionOld)
			  context:nil];
}

- (id) initWithPathToFile:(NSString *)path {
	
	if (!(self = [super init]))
		return nil;
	
	[self initializeInstance];
	[self setFilename:path];
	
	return self;
}

- (void) dealloc
{
	[self removeObserver:self forKeyPath:@"filename"];
	[self removeObserver:self forKeyPath:@"player"];
	
	[info release];
	[video release];
	[audio release];
	[subtitle release];
	[subfile release];
	[chapter release];
	
	[externalSubtitles release];
	
	[prefs release];
	
	[title release];
	[filename release];
	[fileModificationDate release];
	[fileCreationDate release];
	[fileFormat release];
	
	[videoFormat release];
	[videoCodec release];
	[audioFormat release];
	[audioCodec release];
	
	[super dealloc];
}

-(BOOL)containsInfo {
	
	return ([self videoStreamCount] > 0 || [self audioStreamCount] > 0);
}

-(BOOL)isVideo {
	
	return ([self videoStreamCount] > 0);
}

-(BOOL)fileIsValid {
	
	return ([[NSFileManager defaultManager] fileExistsAtPath:filename]
			|| [NSURL URLWithString:filename]);
}

- (void) preflight {
	
	[MovieInfo queueForPreflight:self];
}

// **************************************************** //

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"filename"]) {
		NSString *newFile = [change objectForKey:NSKeyValueChangeNewKey];
		// update filesystem attributes
		NSDictionary *attr = [[NSFileManager defaultManager] fileAttributesAtPath:newFile traverseLink:YES];
		if (attr != nil) {
			[self setFilesize:[[attr objectForKey:NSFileSize] unsignedLongLongValue]];
			[self setFileModificationDate:[attr objectForKey:NSFileModificationDate]];
			[self setFileCreationDate:[attr objectForKey:NSFileCreationDate]];
		}
	
	} else if ([keyPath isEqualToString:@"player"]) {
		PlayerController *old = [change objectForKey:NSKeyValueChangeOldKey];
		PlayerController *new = [change objectForKey:NSKeyValueChangeNewKey];
		if (old && ![old isKindOfClass:[NSNull class]])
			[[old player] setUpdateStatistics:NO];
		if (new && ![new isKindOfClass:[NSNull class]] && captureStats)
			[[new player] setUpdateStatistics:YES];
	}
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	NSSet *affectingKeys = nil;
	
	if ([key isEqualToString:@"displayName"])
		affectingKeys = [NSSet setWithObjects:@"filename",nil];
	else if ([key isEqualToString:@"displayLength"])
		affectingKeys = [NSSet setWithObjects:@"length",nil];
	else if ([key isEqualToString:@"displayFilesize"])
		affectingKeys = [NSSet setWithObjects:@"filesize",nil];
	else if ([key isEqualToString:@"title"])
		affectingKeys = [NSSet setWithObjects:@"filesize",nil];
	
	if (affectingKeys)
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	
	return keyPaths;
}

// **************************************************** //

- (NSString *) displayName {
	
	return [filename lastPathComponent];
}

- (NSString *) displayLength {
	
	if (length > 0)
		return [NSString stringWithFormat:@"%01d:%02d:%02d",length/3600,(length%3600)/60,length%60];
	else
		return @"--:--:--";
}

- (NSString *) displayFilesize {
	
	return [[NSNumber numberWithUnsignedLongLong:filesize] humanReadableSizeStringValue];
}

- (NSString *) title {
	
	if (title)
		return title;
	else
		return [self displayName];
}

- (void) setTitle:(NSString *)aTitle {
	
	[self willChangeValueForKey:@"title"];
	[title autorelease];
	
	if ([aTitle length] == 0)
		title = nil;
	else
		title = [aTitle retain];
	
	[self didChangeValueForKey:@"title"];
}

// **************************************************** //

- (void) setCaptureStats:(BOOL)aBool {
	
	captureStats = aBool;
	
	if (captureStats)
		[[player player] setUpdateStatistics:YES];
	else
		[[player player] setUpdateStatistics:NO];
}

// **************************************************** //

- (void)addExternalSubtitle:(NSString *)path {
	
	if (![externalSubtitles containsObject:path]) {
		[externalSubtitles addObject:path];
		
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:path 
															 forKey:MPEMovieInfoAddedExternalSubtitlePathKey];
		[[NSNotificationCenter defaultCenter] postNotificationName:MPEMovieInfoAddedExternalSubtitleNotification
															object:self
														  userInfo:userInfo];
	}
}

- (unsigned int)externalSubtitleCount {
	
	return [externalSubtitles count];
}

// **************************************************** //

-(void)setInfo:(NSString *)value forKey:(NSString *)key {
	
	[info setObject:value forKey:key];
}

-(NSString *)getInfoForKey:(NSString *)key {
	
	return [info objectForKey:key];
}

// **************************************************** //

-(void)newVideoStream:(unsigned int)streamId {
	
	[video setObject:@"" forKey:[NSString stringWithFormat:@"%u",streamId]];
}

-(void)setVideoStreamName:(NSString *)streamName forId:(unsigned int)streamId {
	
	[video setObject:streamName forKey:[NSString stringWithFormat:@"%u",streamId]];
}

-(NSString *)videoNameForStream:(unsigned int)streamId {
	
	return [video objectForKey:[NSString stringWithFormat:@"%u",streamId]];
}

-(unsigned int)videoStreamCount {
	
	return [video count];
}

-(NSEnumerator *)getVideoStreamsEnumerator {
	
	//return [video keyEnumerator];
	return [[[video allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectEnumerator];
}

-(NSString *)descriptionForVideoStream:(unsigned int)streamId {
	
	if ([[self videoNameForStream:streamId] length] > 0)
		return [NSString stringWithFormat:@"%u: %@",streamId,[self videoNameForStream:streamId]];
	else
		return [NSString stringWithFormat:@"%u: %@",streamId,@"Undefined"];
}

// **************************************************** //

-(void)newAudioStream:(unsigned int)streamId {
	
	[audio setObject:[NSMutableArray arrayWithObjects:@"", @"", @"", nil] forKey:[NSString stringWithFormat:@"%u",streamId]];
}

-(void)setAudioStreamName:(NSString *)streamName forId:(unsigned int)streamId {
	
	[[audio objectForKey:[NSString stringWithFormat:@"%u",streamId]] replaceObjectAtIndex:0 withObject:streamName];
}

-(void)setAudioStreamLanguage:(NSString *)streamLanguage forId:(unsigned int)streamId {
	
	[[audio objectForKey:[NSString stringWithFormat:@"%u",streamId]] replaceObjectAtIndex:1 withObject:streamLanguage];
	[[audio		objectForKey:[NSString stringWithFormat:@"%u",streamId]] 
		replaceObjectAtIndex:2 
				  withObject:[[LanguageCodes sharedInstance] resolveCode:streamLanguage]];
}

-(void)addAudioStream:(unsigned int)streamId withName:(NSString *)streamName andLanguage:(NSString *)lang {
	
	[audio setObject:[NSMutableArray arrayWithObjects:streamName, lang, [[LanguageCodes sharedInstance] resolveCode:lang], nil] 
			  forKey:[NSString stringWithFormat:@"%u",streamId]];
}

-(NSString *)audioNameForStream:(unsigned int)streamId {
	
	return [[audio objectForKey:[NSString stringWithFormat:@"%u",streamId]] objectAtIndex:0];
}

-(NSString *)audioLanguageForStream:(unsigned int)streamId {
	
	return [[audio objectForKey:[NSString stringWithFormat:@"%u",streamId]] objectAtIndex:2];
}

-(unsigned int)audioStreamCount {
	
	return [audio count];
}

-(NSEnumerator *)getAudioStreamsEnumerator {
	
	return [[[audio allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
	//return [audio keyEnumerator];
}

-(NSString *)descriptionForAudioStream:(unsigned int)streamId {
	
	NSString *language = [self audioLanguageForStream:streamId];
	if ([language length] == 0)
		language = @"Undefined";
	
	if ([[self audioNameForStream:streamId] length] > 0)
		return [NSString stringWithFormat:@"%u: %@ (%@)",streamId,language,[self audioNameForStream:streamId]];
	else
		return [NSString stringWithFormat:@"%u: %@",streamId,language];
}

// **************************************************** //

-(void)newSubtitleStream:(unsigned int)streamId forType:(SubtitleType)type {
	
	[[self subDictForType: type] setObject:[NSMutableArray arrayWithObjects:@"", @"", @"", nil] forKey:[NSString stringWithFormat:@"%u",streamId]];
}

-(void)setSubtitleStreamName:(NSString *)streamName forId:(unsigned int)streamId andType:(SubtitleType)type {
	
	[[[self subDictForType: type] objectForKey:[NSString stringWithFormat:@"%u",streamId]] replaceObjectAtIndex:0 withObject:streamName];
}

-(void)setSubtitleStreamLanguage:(NSString *)streamLanguage forId:(unsigned int)streamId andType:(SubtitleType)type {
	
	[[[self subDictForType: type] objectForKey:[NSString stringWithFormat:@"%u",streamId]] replaceObjectAtIndex:1 withObject:streamLanguage];
	[[[self subDictForType: type] objectForKey:[NSString stringWithFormat:@"%u",streamId]] 
			 replaceObjectAtIndex:2 withObject:[[LanguageCodes sharedInstance] resolveCode:streamLanguage]];
}

-(NSString *)subtitleNameForStream:(unsigned int)streamId andType:(SubtitleType)type {
	
	return [[[self subDictForType: type] objectForKey:[NSString stringWithFormat:@"%u",streamId]] objectAtIndex:0];
}

-(NSString *)subtitleLanguageForStream:(unsigned int)streamId andType:(SubtitleType)type {
	
	return [[[self subDictForType: type] objectForKey:[NSString stringWithFormat:@"%u",streamId]] objectAtIndex:2];
}



-(unsigned int)subtitleCountForType:(SubtitleType)type {
	
	if (type == SubtitleTypeAll)
		return ([subtitle count] + [subfile count]);
	else
		return [[self subDictForType:type] count];
}

-(NSEnumerator *)getSubtitleStreamsEnumeratorForType:(SubtitleType)type {
	
	return [[[[self subDictForType: type] allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
	//return [[self subDictForType: type] keyEnumerator];
}

-(NSString *)descriptionForSubtitleStream:(unsigned int)streamId andType:(SubtitleType)type {
	
	NSString *language = [self subtitleLanguageForStream:streamId andType:type];
	if ([language length] == 0)
		language = @"Undefined";
	
	if ([[self subtitleNameForStream:streamId andType:type] length] > 0)
		return [NSString stringWithFormat:@"%u: %@ (%@)",streamId,language,[self subtitleNameForStream:streamId andType:type]];
	else
		return [NSString stringWithFormat:@"%u: %@",streamId,language];
}

-(NSMutableDictionary *)subDictForType:(SubtitleType)type {
	
	if (type == SubtitleTypeDemux)
		return subtitle;
	else if (type == SubtitleTypeFile)
		return subfile;
	else
		return nil;
}

// **************************************************** //

-(void)newChapter:(unsigned int)chapterId {
	
	[chapter setObject:[NSMutableArray arrayWithObjects:[NSNumber numberWithFloat:0.0], @"", nil] forKey:[NSString stringWithFormat:@"%u",chapterId]];
}

-(void)setChapterStartTime:(NSNumber *)startTime forId:(unsigned int)chapterId {
	
	[[chapter objectForKey:[NSString stringWithFormat:@"%u",chapterId]] replaceObjectAtIndex:0 withObject:startTime];
}

-(void)setChapterName:(NSString *)chapterName forId:(unsigned int)chapterId {
	
	[[chapter objectForKey:[NSString stringWithFormat:@"%u",chapterId]] replaceObjectAtIndex:1 withObject:chapterName];
}

-(NSString *)nameForChapter:(unsigned int)chapterId {
	
	return [[chapter objectForKey:[NSString stringWithFormat:@"%u",chapterId]] objectAtIndex:1];
}

-(float)startOfChapter:(unsigned int)chapterId {
	
	return [[[chapter objectForKey:[NSString stringWithFormat:@"%u",chapterId]] objectAtIndex:0] floatValue];
}


-(unsigned int)chapterCount {

	return [chapter count];
}

-(NSEnumerator *)getChaptersEnumerator {
	
	return [[[chapter allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
}

// **************************************************** //

static NSString* const MPEMovieInfoGeneralInformationKey   = @"MPEMovieInfoGeneralInformation";
static NSString* const MPEMovieInfoVideoStreamsKey         = @"MPEMovieInfoVideoStreams";
static NSString* const MPEMovieInfoAudioStreamsKey         = @"MPEMovieInfoAudioStreams";
static NSString* const MPEMovieInfoSubtitleDemuxStreamsKey = @"MPEMovieInfoSubtitleDemuxStreams";
static NSString* const MPEMovieInfoSubtitleFileStreamsKey  = @"MPEMovieInfoSubtitleFileStreams";
static NSString* const MPEMovieInfoChapterStreamsKey       = @"MPEMovieInfoChapterStreams";
static NSString* const MPEMovieInfoExternalSubtitlesKey    = @"MPEMovieInfoExternalSubtitles";
static NSString* const MPEMovieInfoLocalSettingsKey        = @"MPEMovieInfoLocalSettings";
static NSString* const MPEMovieInfoTitleKey                = @"MPEMovieInfoTitle";
static NSString* const MPEMovieInfoFilenameKey             = @"MPEMovieInfoFilename";
static NSString* const MPEMovieInfoFileModificationDateKey = @"MPEMovieInfoFileModificationDate";
static NSString* const MPEMovieInfoFileFormatKey           = @"MPEMovieInfoFileFormat";
static NSString* const MPEMovieInfoMovieIsSeekableKey      = @"MPEMovieInfoMovieIsSeekable";
static NSString* const MPEMovieInfoVideoFormatKey          = @"MPEMovieInfoVideoFormat";
static NSString* const MPEMovieInfoVideoCodecKey           = @"MPEMovieInfoVideoCodec";
static NSString* const MPEMovieInfoVideoBitrateKey         = @"MPEMovieInfoVideoBitrate";
static NSString* const MPEMovieInfoVideoWidthKey           = @"MPEMovieInfoVideoWidth";
static NSString* const MPEMovieInfoVideoHeightKey          = @"MPEMovieInfoVideoHeight";
static NSString* const MPEMovieInfoVideoFPSKey             = @"MPEMovieInfoVideoFPS";
static NSString* const MPEMovieInfoVideoAspectKey          = @"MPEMovieInfoVideoAspect";
static NSString* const MPEMovieInfoAudioFormatKey          = @"MPEMovieInfoAudioFormat";
static NSString* const MPEMovieInfoAudioCodecKey           = @"MPEMovieInfoAudioCodec";
static NSString* const MPEMovieInfoAudioBitrateKey         = @"MPEMovieInfoAudioBitrate";
static NSString* const MPEMovieInfoAudioSampleRateKey      = @"MPEMovieInfoAudioSampleRate";
static NSString* const MPEMovieInfoAudioChannelsKey        = @"MPEMovieInfoAudioChannels";
static NSString* const MPEMovieInfoMovieLengthKey          = @"MPEMovieInfoMovieLength";

// **************************************************** //

- (NSDictionary *)dictionaryRepresentation {
	
	if (!filename || [filename length] == 0)
		return nil;
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	
	// General dictionaries
	if ([info count] > 0)
		[dict setObject:info forKey:MPEMovieInfoGeneralInformationKey];
	if ([prefs count] > 0)
		[dict setObject:prefs forKey:MPEMovieInfoLocalSettingsKey];
	
	// Stream dictionaries
	if ([video count] > 0)
		[dict setObject:video forKey:MPEMovieInfoVideoStreamsKey];
	if ([audio count] > 0)
		[dict setObject:audio forKey:MPEMovieInfoAudioStreamsKey];
	if ([subtitle count] > 0)
		[dict setObject:subtitle forKey:MPEMovieInfoSubtitleDemuxStreamsKey];
	if ([subfile count] > 0)
		[dict setObject:subfile forKey:MPEMovieInfoSubtitleFileStreamsKey];
	if ([chapter count] > 0)
		[dict setObject:chapter forKey:MPEMovieInfoChapterStreamsKey];
	
	if ([externalSubtitles count] > 0)
		[dict setObject:externalSubtitles forKey:MPEMovieInfoExternalSubtitlesKey];
	
	// Movie attributes
	[dict setObject:filename forKey:MPEMovieInfoFilenameKey];
	[dict setObject:fileModificationDate forKey:MPEMovieInfoFileModificationDateKey];
	[dict setBool:seekable forKey:MPEMovieInfoMovieIsSeekableKey];
	
	if (title)
		[dict setObject:title forKey:MPEMovieInfoTitleKey];
	if (fileFormat)
		[dict setObject:fileFormat forKey:MPEMovieInfoFileFormatKey];
	if (length > 0)
		[dict setInteger:length forKey:MPEMovieInfoMovieLengthKey];
	
	// Video attributes
	if (videoFormat)
		[dict setObject:videoFormat forKey:MPEMovieInfoVideoFormatKey];
	if (videoCodec)
		[dict setObject:videoCodec forKey:MPEMovieInfoVideoCodecKey];
	if (videoBitrate > 0)
		[dict setInteger:videoBitrate forKey:MPEMovieInfoVideoBitrateKey];
	if (videoWidth > 0)
		[dict setInteger:videoWidth forKey:MPEMovieInfoVideoWidthKey];
	if (videoHeight > 0)
		[dict setInteger:videoHeight forKey:MPEMovieInfoVideoHeightKey];
	if (videoFPS > 0)
		[dict setFloat:videoFPS forKey:MPEMovieInfoVideoFPSKey];
	if (videoAspect > 0)
		[dict setFloat:videoAspect forKey:MPEMovieInfoVideoAspectKey];
	
	// Audio attributes
	if (audioFormat)
		[dict setObject:audioFormat forKey:MPEMovieInfoAudioFormatKey];
	if (audioCodec)
		[dict setObject:audioCodec forKey:MPEMovieInfoAudioCodecKey];
	if (audioBitrate > 0)
		[dict setInteger:audioBitrate forKey:MPEMovieInfoAudioBitrateKey];
	if (audioSampleRate > 0)
		[dict setFloat:audioSampleRate forKey:MPEMovieInfoAudioSampleRateKey];
	if (audioChannels > 0)
		[dict setInteger:audioChannels forKey:MPEMovieInfoAudioChannelsKey];
	
	return dict;
}

- (id) initWithDictionaryRepresentation:(NSDictionary *)dict {
	
	if (!(self = [super init]))
		return nil;
	
	// General dictionaries
	info     = [[dict mutableDictionaryForKey:MPEMovieInfoGeneralInformationKey] retain];
	prefs    = [[dict mutableDictionaryForKey:MPEMovieInfoLocalSettingsKey] retain];
	
	// Stream dictionaries
	video    = [[dict mutableDictionaryForKey:MPEMovieInfoVideoStreamsKey] retain];
	audio    = [[dict mutableDictionaryForKey:MPEMovieInfoAudioStreamsKey] retain];
	subtitle = [[dict mutableDictionaryForKey:MPEMovieInfoSubtitleDemuxStreamsKey] retain];
	subfile  = [[dict mutableDictionaryForKey:MPEMovieInfoSubtitleFileStreamsKey] retain];
	chapter  = [[dict mutableDictionaryForKey:MPEMovieInfoChapterStreamsKey] retain];
	
	externalSubtitles = [[dict mutableArrayForKey:MPEMovieInfoExternalSubtitlesKey] retain];
	
	// Movie attributes
	filename     = [[dict stringForKey:MPEMovieInfoFilenameKey] retain];
	fileModificationDate = [[dict dateForKey:MPEMovieInfoFileModificationDateKey] retain];
	seekable     = [dict boolForKey:MPEMovieInfoMovieIsSeekableKey];
	
	title        = [[dict stringForKey:MPEMovieInfoTitleKey] retain];
	fileFormat   = [[dict stringForKey:MPEMovieInfoFileFormatKey] retain];
	length       = [dict integerForKey:MPEMovieInfoMovieLengthKey];
	
	// Video attributes
	videoFormat  = [[dict stringForKey:MPEMovieInfoVideoFormatKey] retain];
	videoCodec   = [[dict stringForKey:MPEMovieInfoVideoCodecKey] retain];
	videoBitrate = [dict integerForKey:MPEMovieInfoVideoBitrateKey];
	videoWidth   = [dict integerForKey:MPEMovieInfoVideoWidthKey];
	videoHeight  = [dict integerForKey:MPEMovieInfoVideoHeightKey];
	videoFPS     = [dict floatForKey:MPEMovieInfoVideoFPSKey];
	videoAspect  = [dict floatForKey:MPEMovieInfoVideoAspectKey];
	
	// Audio attributes
	audioFormat  = [[dict stringForKey:MPEMovieInfoAudioFormatKey] retain];
	audioCodec   = [[dict stringForKey:MPEMovieInfoAudioCodecKey] retain];
	audioBitrate = [dict integerForKey:MPEMovieInfoAudioBitrateKey];
	audioSampleRate = [dict floatForKey:MPEMovieInfoAudioSampleRateKey];
	audioChannels = [dict integerForKey:MPEMovieInfoAudioChannelsKey];
	
	// Make sure dictionaries and arrays are initialized
	[self initializeInstance];
	
	// Check if we should update the info
	NSDate *oldDate = [[fileModificationDate retain] autorelease];
	// Update modification date by resetting the filename
	[self setFilename:filename];
	
	if ([oldDate compare:fileModificationDate] != NSOrderedSame)
		[MovieInfo queueForPreflight:self];
	
	return self;
}

// **************************************************** //

@end
