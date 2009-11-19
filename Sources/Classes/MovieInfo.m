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


@implementation MovieInfo

// **************************************************** //

+(MovieInfo *)fromDictionary:(NSDictionary *)dict {
	return [[[dict objectForKey:@"MovieInfo"] retain] autorelease];
}

// **************************************************** //

- (id)init {
	
	info = [[NSMutableDictionary alloc] initWithCapacity:10];
	
	video = [[NSMutableDictionary alloc] initWithCapacity:1];
	audio = [[NSMutableDictionary alloc] initWithCapacity:2];
	subtitle = [[NSMutableDictionary alloc] initWithCapacity:2];
	subfile = [[NSMutableDictionary alloc] initWithCapacity:1];
	chapter = [[NSMutableDictionary alloc] initWithCapacity:5];
	
	videoHeight = 0;
	videoWidth = 0;
	
	length = 0;
	
	return [super init];
}

- (void) dealloc
{
	[info release];
	[video release];
	[audio release];
	[subtitle release];
	[subfile release];
	[chapter release];
	
	[super dealloc];
}

-(BOOL)containsInfo {
	
	return (fileFormat != nil && filename != nil);
}

-(BOOL)isVideo {
	
	return (videoForamt != nil && videoForamt != @"");
}

// **************************************************** //

-(void)setFilename:(NSString *)aString {
	[filename release];
	filename = [aString retain];
	
	// filesystem attributes
	NSDictionary *attr = [[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
	if (attr != nil) {
		filesize = [attr objectForKey:NSFileSize];
		fileModificationDate = [attr objectForKey:NSFileModificationDate];
		fileCreationDate = [attr objectForKey:NSFileCreationDate];
	}
}
-(NSString *)filename {
	return filename;
}

-(void)setFileFormat:(NSString *)aString {
	[fileFormat release];
	fileFormat = [aString retain];
}
-(NSString *)fileFormat {
	return fileFormat;
}

-(void)setIsSeekable:(BOOL)seek {
	isSeekable = seek;
}
-(BOOL)isSeekable {
	return isSeekable;
}

-(void)setVideoFormat:(NSString *)aString {
	[videoForamt release];
	videoForamt = [aString retain];
}
-(NSString *)videoForamt {
	return videoForamt;
}

-(void)setVideoCodec:(NSString *)aString {
	[videoCodec release];
	videoCodec = [aString retain];
}
-(NSString *)videoCodec {
	return videoCodec;
}

-(void)setVideoBitrate:(unsigned int)aUint {
	videoBitrate = aUint;
}
-(unsigned int)videoBitrate {
	return videoBitrate;
}

-(void)setVideoWidth:(unsigned int)aUint {
	videoWidth = aUint;
}
-(unsigned int)videoWidth {
	return videoWidth;
}

-(void)setVideoHeight:(unsigned int)aUint {
	videoHeight = aUint;
}
-(unsigned int)videoHeight {
	return videoHeight;
}

-(void)setVideoFps:(float)aFloat {
	videoFPS = aFloat;
}
-(float)videoFps {
	return videoFPS;
}

-(void)setVideoAspect:(float)aFloat {
	videoAspect = aFloat;
}
-(float)videoAspect {
	return videoAspect;
}

-(void)setAudioFormat:(NSString *)aString {
	[audioFormat release];
	audioFormat = [aString retain];
}
-(NSString *)audioForamt {
	return audioFormat;
}

-(void)setAudioCodec:(NSString *)aString {
	[audioCodec release];
	audioCodec = [aString retain];
}
-(NSString *)audioCodec {
	return audioCodec;
}

-(void)setAudioBitrate:(unsigned int)aUint {
	audioBitrate = aUint;
}
-(unsigned int)audioBitrate {
	return audioBitrate;
}

-(void)setAudioSampleRate:(float)aFloat {
	audioSampleRate = aFloat;
}
-(float)audioSampleRate {
	return audioSampleRate;
}

-(void)setAudioChannels:(unsigned int)aUint {
	audioChannels = aUint;
}
-(unsigned int)audioChannels {
	return audioChannels;
}

-(void)setLength:(unsigned int)aUint {
	length = aUint;
}
-(unsigned int)length {
	return length;
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
