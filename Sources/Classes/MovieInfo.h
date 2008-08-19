//
//  MovieInfo.h
//  MPlayer OSX
//
//  Created by Adrian on 02.08.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LanguageCodes.h"

typedef enum _SubtitleType {
	SubtitleTypeDemux = 0,
	SubtitleTypeFile  = 1
} SubtitleType;

@interface MovieInfo : NSObject {
	
@protected
	
	// General Information
	NSMutableDictionary *info;
	
	// Video streams
	NSMutableDictionary *video;
	// Audio Streams
	NSMutableDictionary *audio;
	// Subtitle Streams
	NSMutableDictionary *subtitle;
	// Subtitle files
	NSMutableDictionary *subfile;
	// Chapter Streams
	NSMutableDictionary *chapter;
	
	// name
	NSString *filename;
	NSString *name;
	NSString *filesize;
	NSString *fileModificationDate;
	NSString *fileCreationDate;
	
	// formats
	NSString *fileFormat;
	
	// video
	NSString *videoForamt;
	NSString *videoCodec;
	unsigned int videoBitrate;
	unsigned int videoWidth;
	unsigned int videoHeight;
	float videoFPS;
	float videoAspect;
	
	// audio
	NSString *audioFormat;
	NSString *audioCodec;
	unsigned int audioBitrate;
	float audioSampleRate;
	unsigned int audioChannels;
	
	// length
	unsigned int length;
	
}

// extract MovieInfo from dictionary
+(MovieInfo *)fromDictionary:(NSDictionary *)dict;

// General methods
-(id)init;
-(BOOL)containsInfo;

// format methods
-(BOOL)isVideo;

// basic info
-(void)setFilename:(NSString *)aString;
-(NSString *)filename;
-(void)setFileFormat:(NSString *)aString;
-(NSString *)fileFormat;

-(void)setVideoFormat:(NSString *)aString;
-(NSString *)videoForamt;
-(void)setVideoCodec:(NSString *)aString;
-(NSString *)videoCodec;
-(void)setVideoBitrate:(unsigned int)aUint;
-(unsigned int)videoBitrate;
-(void)setVideoWidth:(unsigned int)aUint;
-(unsigned int)videoWidth;
-(void)setVideoHeight:(unsigned int)aUint;
-(unsigned int)videoHeight;
-(void)setVideoFps:(float)aFloat;
-(float)videoFps;
-(void)setVideoAspect:(float)aFloat;
-(float)videoAspect;

-(void)setAudioFormat:(NSString *)aString;
-(NSString *)audioForamt;
-(void)setAudioCodec:(NSString *)aString;
-(NSString *)audioCodec;
-(void)setAudioBitrate:(unsigned int)aUint;
-(unsigned int)audioBitrate;
-(void)setAudioSampleRate:(float)aFloat;
-(float)audioSampleRate;
-(void)setAudioChannels:(unsigned int)aUint;
-(unsigned int)audioChannels;

-(void)setLength:(unsigned int)aUint;
-(unsigned int)length;
  
// Set and get info
-(void)setInfo:(NSString *)value forKey:(NSString *)key;
-(NSString *)getInfoForKey:(NSString *)key;

// Set and get video streams
-(void)newVideoStream:(unsigned int)streamId;
-(void)setVideoStreamName:(NSString *)streamName forId:(unsigned int)streamId;
-(NSString *)videoNameForStream:(unsigned int)streamId;
-(unsigned int)videoStreamCount;
-(NSEnumerator *)getVideoStreamsEnumerator;
-(NSString *)descriptionForVideoStream:(unsigned int)streamId;

// Set and get audio streams
-(void)newAudioStream:(unsigned int)streamId;
-(void)setAudioStreamName:(NSString *)streamName forId:(unsigned int)streamId;
-(void)setAudioStreamLanguage:(NSString *)streamLanguage forId:(unsigned int)streamId;
-(NSString *)audioNameForStream:(unsigned int)streamId;
-(NSString *)audioLanguageForStream:(unsigned int)streamId;
-(unsigned int)audioStreamCount;
-(NSEnumerator *)getAudioStreamsEnumerator;
-(NSString *)descriptionForAudioStream:(unsigned int)streamId;

// Set and get subtitle streams
-(void)newSubtitleStream:(unsigned int)streamId forType:(SubtitleType)type;
-(void)setSubtitleStreamName:(NSString *)streamName forId:(unsigned int)streamId andType:(SubtitleType)type;
-(void)setSubtitleStreamLanguage:(NSString *)streamLanguage forId:(unsigned int)streamId andType:(SubtitleType)type;
-(NSString *)subtitleNameForStream:(unsigned int)streamId andType:(SubtitleType)type;
-(NSString *)subtitleLanguageForStream:(unsigned int)streamId andType:(SubtitleType)type;
-(unsigned int)subtitleCountForType:(SubtitleType)type;
-(NSEnumerator *)getSubtitleStreamsEnumeratorForType:(SubtitleType)type;
-(NSString *)descriptionForSubtitleStream:(unsigned int)streamId andType:(SubtitleType)type;

// Set and get chapters
-(void)newChapter:(unsigned int)chapterId from:(float)fromSec to:(float)toSec withName:(NSString *)chapterName;
-(NSString *)nameForChapter:(unsigned int)chapterId;
-(float)startOfChapter:(unsigned int)chapterId;
-(float)endOfChapter:(unsigned int)chapterId;
-(unsigned int)chapterCount;
-(NSEnumerator *)getChaptersEnumerator;

-(NSMutableDictionary *)subDictForType:(SubtitleType)type;

@end
