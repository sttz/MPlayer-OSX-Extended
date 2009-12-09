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

#import "MplayerInterface.h"

#define MPEPreflightNumInstances	4

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
	
	if ([freePreflightInstances count] == 0) {
		// Create new instances on-demand
		if ([busyPreflightInstances count] < MPEPreflightNumInstances) {
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
	
	NSLog(@"start preflight for %@",[nextItem filename]);
	// Start preflight
	[inst loadInfo:nextItem];
}

+ (void) preflightFinished:(NSNotification *)notification {
	
	NSLog(@"preflightFinished");
	[self preflightNextItem];
	[self requeuePreflightInstance:[notification object]];
}

+ (void) preflightFailed:(NSNotification *)notification {
	
	MplayerInterface *inst = (MplayerInterface *)[notification object];
	[Debug log:ASL_LEVEL_ERR withMessage:@"Preflight failed for '%@'",[[inst info] filename]];
	[self preflightNextItem];
	[self requeuePreflightInstance:inst];
}

+ (void) requeuePreflightInstance:(MplayerInterface*)inst {
	
	[freePreflightInstances addObject:inst];
	[busyPreflightInstances removeObject:inst];
}

@end



@implementation MovieInfo
@synthesize filename, prefs, fileFormat, seekable, length, filesize, fileModificationDate, fileCreationDate,
videoFormat, videoCodec, videoBitrate, videoWidth, videoHeight, videoFPS, videoAspect,
audioFormat, audioCodec, audioBitrate, audioSampleRate, audioChannels,
externalSubtitles;

// **************************************************** //

+(MovieInfo *)movieInfoWithPathToFile:(NSString*)path {
	
	return [[[MovieInfo alloc] initWithPathToFile:path] autorelease];
}

// **************************************************** //

- (id)init {
	
	if (!(self = [super init]))
		return nil;
	
	info = [[NSMutableDictionary alloc] initWithCapacity:10];
	
	video = [[NSMutableDictionary alloc] initWithCapacity:1];
	audio = [[NSMutableDictionary alloc] initWithCapacity:2];
	subtitle = [[NSMutableDictionary alloc] initWithCapacity:2];
	subfile = [[NSMutableDictionary alloc] initWithCapacity:1];
	chapter = [[NSMutableDictionary alloc] initWithCapacity:5];
	
	externalSubtitles = [NSMutableArray new];
	
	prefs = [NSMutableDictionary new];
	
	videoHeight = 0;
	videoWidth = 0;
	
	length = 0;
	
	[self addObserver:self
		   forKeyPath:@"filename" 
			  options:NSKeyValueObservingOptionNew 
			  context:nil];
	
	return self;
}

- (id)initWithPathToFile:(NSString *)path {
	
	if (![self init])
		return nil;
	
	[self setFilename:path];
	
	return self;
}

- (void) dealloc
{
	[info release];
	[video release];
	[audio release];
	[subtitle release];
	[subfile release];
	[chapter release];
	
	[externalSubtitles release];
	
	[prefs release];
	
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
	}
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
	
	[video setObject:@"" forKey:[NSNumber numberWithUnsignedInt:streamId]];
}

-(void)setVideoStreamName:(NSString *)streamName forId:(unsigned int)streamId {
	
	[video setObject:streamName forKey:[NSNumber numberWithUnsignedInt:streamId]];
}

-(NSString *)videoNameForStream:(unsigned int)streamId {
	
	return [video objectForKey:[NSNumber numberWithUnsignedInt:streamId]];
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
		return [NSString stringWithFormat:@"%@: %@",[NSNumber numberWithInt:streamId],[self videoNameForStream:streamId]];
	else
		return [NSString stringWithFormat:@"%@: %@",[NSNumber numberWithInt:streamId],@"Undefined"];
}

// **************************************************** //

-(void)newAudioStream:(unsigned int)streamId {
	
	[audio setObject:[NSMutableArray arrayWithObjects:@"", @"", @"", nil] forKey:[NSNumber numberWithUnsignedInt:streamId]];
}

-(void)setAudioStreamName:(NSString *)streamName forId:(unsigned int)streamId {
	
	[[audio objectForKey:[NSNumber numberWithUnsignedInt:streamId]] replaceObjectAtIndex:0 withObject:streamName];
}

-(void)setAudioStreamLanguage:(NSString *)streamLanguage forId:(unsigned int)streamId {
	
	[[audio objectForKey:[NSNumber numberWithUnsignedInt:streamId]] replaceObjectAtIndex:1 withObject:streamLanguage];
	[[audio		objectForKey:[NSNumber numberWithUnsignedInt:streamId]] 
		replaceObjectAtIndex:2 
				  withObject:[[LanguageCodes sharedInstance] resolveCode:streamLanguage]];
}

-(void)addAudioStream:(unsigned int)streamId withName:(NSString *)streamName andLanguage:(NSString *)lang {
	
	[audio setObject:[NSMutableArray arrayWithObjects:streamName, lang, [[LanguageCodes sharedInstance] resolveCode:lang], nil] 
			  forKey:[NSNumber numberWithUnsignedInt:streamId]];
}

-(NSString *)audioNameForStream:(unsigned int)streamId {
	
	return [[audio objectForKey:[NSNumber numberWithUnsignedInt:streamId]] objectAtIndex:0];
}

-(NSString *)audioLanguageForStream:(unsigned int)streamId {
	
	return [[audio objectForKey:[NSNumber numberWithUnsignedInt:streamId]] objectAtIndex:2];
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
		return [NSString stringWithFormat:@"%@: %@ (%@)",[NSNumber numberWithInt:streamId],language,[self audioNameForStream:streamId]];
	else
		return [NSString stringWithFormat:@"%@: %@",[NSNumber numberWithInt:streamId],language];
}

// **************************************************** //

-(void)newSubtitleStream:(unsigned int)streamId forType:(SubtitleType)type {
	
	[[self subDictForType: type] setObject:[NSMutableArray arrayWithObjects:@"", @"", @"", nil] forKey:[NSNumber numberWithUnsignedInt:streamId]];
}

-(void)setSubtitleStreamName:(NSString *)streamName forId:(unsigned int)streamId andType:(SubtitleType)type {
	
	[[[self subDictForType: type] objectForKey:[NSNumber numberWithUnsignedInt:streamId]] replaceObjectAtIndex:0 withObject:streamName];
}

-(void)setSubtitleStreamLanguage:(NSString *)streamLanguage forId:(unsigned int)streamId andType:(SubtitleType)type {
	
	[[[self subDictForType: type] objectForKey:[NSNumber numberWithUnsignedInt:streamId]] replaceObjectAtIndex:1 withObject:streamLanguage];
	[[[self subDictForType: type] objectForKey:[NSNumber numberWithUnsignedInt:streamId]] 
			 replaceObjectAtIndex:2 withObject:[[LanguageCodes sharedInstance] resolveCode:streamLanguage]];
}

-(NSString *)subtitleNameForStream:(unsigned int)streamId andType:(SubtitleType)type {
	
	return [[[self subDictForType: type] objectForKey:[NSNumber numberWithUnsignedInt:streamId]] objectAtIndex:0];
}

-(NSString *)subtitleLanguageForStream:(unsigned int)streamId andType:(SubtitleType)type {
	
	return [[[self subDictForType: type] objectForKey:[NSNumber numberWithUnsignedInt:streamId]] objectAtIndex:2];
}



-(unsigned int)subtitleCountForType:(SubtitleType)type {
	
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
		return [NSString stringWithFormat:@"%@: %@ (%@)",[NSNumber numberWithInt:streamId],language,[self subtitleNameForStream:streamId andType:type]];
	else
		return [NSString stringWithFormat:@"%@: %@",[NSNumber numberWithInt:streamId],language];
}

-(NSMutableDictionary *)subDictForType:(SubtitleType)type {
	
	if (type == SubtitleTypeDemux)
		return subtitle;
	else
		return subfile;
}

// **************************************************** //

-(void)newChapter:(unsigned int)chapterId {
	
	[chapter setObject:[NSMutableArray arrayWithObjects:[NSNumber numberWithFloat:0.0], @"", nil] forKey:[NSNumber numberWithUnsignedInt:chapterId]];
}

-(void)setChapterStartTime:(NSNumber *)startTime forId:(unsigned int)chapterId {
	
	[[chapter objectForKey:[NSNumber numberWithUnsignedInt:chapterId]] replaceObjectAtIndex:0 withObject:startTime];
}

-(void)setChapterName:(NSString *)chapterName forId:(unsigned int)chapterId {
	
	[[chapter objectForKey:[NSNumber numberWithUnsignedInt:chapterId]] replaceObjectAtIndex:1 withObject:chapterName];
}

-(NSString *)nameForChapter:(unsigned int)chapterId {
	
	return [[chapter objectForKey:[NSNumber numberWithUnsignedInt:chapterId]] objectAtIndex:1];
}

-(float)startOfChapter:(unsigned int)chapterId {
	
	return [[[chapter objectForKey:[NSNumber numberWithUnsignedInt:chapterId]] objectAtIndex:0] floatValue];
}


-(unsigned int)chapterCount {

	return [chapter count];
}

-(NSEnumerator *)getChaptersEnumerator {
	
	return [[[chapter allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
}

// **************************************************** //

@end
