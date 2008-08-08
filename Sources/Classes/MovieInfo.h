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
	
@public
	
	// name
	NSString *filename;
	NSString *name;
	
	// formats
	NSString *fileFormat;
	
	// video
	NSString *videoForamt;
	NSString *videoCodec;
	unsigned int videoBitrate;
	unsigned int width;
	unsigned int height;
	float videoFPS;
	float videoAspect;
	
	// audio
	NSString *audioFormat;
	NSString *audioCodec;
	unsigned int audioBitrate;
	unsigned int audioSampleRate;
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

-(NSMutableDictionary *)subDictForType:(SubtitleType)type;

@end
