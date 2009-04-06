/*
 *  MplayerInterface.h
 *  MPlayer OS X
 *
 *	version 1.1
 *
 *	Description:
 *		Interface to MPlayer binary application that is supposed to simplify the access
 *	to the application controlls and state values while handling inconsistent states of
 *	player
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */


#import <Cocoa/Cocoa.h>
#import "MovieInfo.h"

#import "Debug.h"

// Notifications posted by MplayerInterface
	// 	@"MIPlayerTerminatedNotification"	mplayer has been terminated
	// 	@"MIInfoReadyNotification"			notification has been updated
	// 	@"MIStateUpdatedNotification"		status updated
	// 	@"MIFinishedParsing"				parsing of output has finished

// status update notification info keys
	//	@"PlayerStatus"				NSNumber - int (player status constants)
	//	@"MovieSeconds"				NSNumber - float
	//	@"SyncDifference"			NSNumber - float
	//	@"DroppedFrames"			NSNumber - int
	//	@"PostProcessingLevel"		NSNumber - int
	//	@"CPUUsage"					NSNumber - float percents
	//	@"CacheUsage"				NSNumber - float percents

// keys to mplayer info dictionary (all represents NSString objects)
	//	@"ID_FILENAME"				file path
	//	@"ID_FILE_FORMAT"			media format (AVI,MOV....)
	//	@"ID_VIDEO_FORMAT"			video codec
	//	@"ID_VIDEO_BITRATE"
	//	@"ID_VIDEO_WIDTH"
	//	@"ID_VIDEO_HEIGHT"
	//	@"ID_VIDEO_FPS"
	//	@"ID_VIDEO_ASPECT"
	//	@"ID_AUDIO_CODEC"
	//	@"ID_AUDIO_FORMAT"
	//	@"ID_AUDIO_BITRATE"			Bits per second
	//	@"ID_AUDIO_RATE"			kHz
	//	@"ID_AUDIO_NCH"				number of channels
	//	@"ID_LENGTH"				length in seconds

// player status constants
#define kFinished					-1	// terminated by reaching end-of-file
#define kStopped					0	// terminated by not reaching EOF
#define kPlaying					1
#define kPaused						2
#define kOpening					3
#define kBuffering					4
#define kIndexing					5
#define kInitializing				6	// task just started, no status yet

// seeking modes
#define	MIRelativeSeekingMode		0	// relative seeking in seconds 
#define	MIPercentSeekingMode		1	// absolute seeking in percents
#define	MIAbsoluteSeekingMode		2	// absolute seeking in seconds

// default constants
#define kDefaultMovieSize 			NSMakeSize(0,0)

// osd level modes
#define MI_CMD_SHOW_ALWAYS			1
#define MI_CMD_SHOW_COND			2
#define MI_CMD_SHOW_NEVER			0

@interface MplayerInterface : NSObject
{	
	// Properties
	// file paths
	NSString *myPathToPlayer;
	NSString *myMovieFile;
	NSString *mySubtitlesFile;
	NSString *myAudioFile;
	NSString *myAudioExportFile;
	NSString *myFontFile;
	
	NSString *buffer_name;
	
	// playback
	NSString *audioLanguages;
	NSString *subtitleLanguages;
	BOOL osdSilenced;
	BOOL correctPTS;
	int numberOfThreads;
	
	unsigned int cacheSize;
	
	// display
	unsigned int displayType;
	
	BOOL flipVertical;
	BOOL flipHorizontal;
	NSSize movieSize;
	double aspectRatio;
	double monitorAspect;
	
	unsigned int deviceId;
	unsigned int voModule;
	NSString *screenshotPath;
	
	// text
	NSString *subEncoding;
	NSString *guessEncodingLang;
	
	BOOL assSubtitles;
	unsigned int subScale;
	
	BOOL embeddedFonts;
	BOOL assPreFilter;
	NSColor *subColor;
	NSColor *subBorderColor;
	
	int osdLevel;
	unsigned int osdScale;
	
	// video
	BOOL enableVideo;
	NSString *videoCodecs;
	
	unsigned int framedrop;
	BOOL fastLibavcodec;
	unsigned int skipLoopfilter;
	
	BOOL deinterlace;
	unsigned int postprocessing;
	
	// audio
	BOOL enableAudio;
	NSString *audioCodecs;
	
	BOOL passthroughAC3;
	BOOL passthroughDTS;
	
	BOOL hrtfFilter;
	BOOL karaokeFilter;
	
	// advanced
	BOOL equalizerEnabled;
	NSArray *equalizerValues;
	BOOL videoEqualizerEnabled;
	NSArray *videoEqualizerValues;
	NSArray *addParams;
	
	// properties
	BOOL myRebuildIndex;
	BOOL isPreflight;
	
	// state variables
	int	myState;				// player state
	unsigned int myVolume;		// volume 0-100
	
	//beta
	unsigned int myadvolume;
	float mySeconds;			// actual/saved seconds
	BOOL isSeeking;
	
	// statistics
	BOOL myUpdateStatistics;		// if set the following properties are periodicaly updated
	float mySyncDifference;		// difference in secconds between audion and video
	int myCPUUsage;			// overal player CPU usage
	int myCacheUsage;			// cache usage
	int	myDroppedFrames;		// number of dropped frames since last key frame
	int myPostProcLevel;		// actual level of postprocessing
	
	// internal use
	NSTask *myMplayerTask;
	double myLastUpdate;			// date when last update notificationa was sent
	BOOL settingsChanged;			// changed settings that requires player restart
	BOOL videoOutChanged;
	BOOL takeEffectImediately;		// changes have to take effect even in paused mode
	BOOL restartingPlayer;			// set when player is teminated to be restarted
	BOOL pausedOnRestart;			// set when paused during attemp to restart player
	BOOL isRunning;					// set off after recieving termination notification
	BOOL isPlaying;					// set off after reading "Exiting" from output
	BOOL useIdentifyForPlayback;	// sets whether -identify is sent on starting playback
	BOOL windowedVO;
	int myOutputReadMode;				// defines playback output form 
	NSMutableArray *myCommandsBuffer;	// store cmds that cannot be send immediatelly
	NSString *lastUnparsedLine;
	NSString *lastUnparsedErrorLine;
	NSMutableCharacterSet *newlineCharacterSet;
	//NSMutableDictionary *myInfo;	// dict filled by -identify command
	BOOL isFullscreen;				// currently playing fullscreen
	int subtitleFileId;				// since sub file identify output is not numberede, we need to cache the id
	
	MovieInfo *info;
}
// interface
// init and uninit
- (id) init;										// init
- (id) initWithPathToPlayer:(NSString *)aPath;		// init with movie file path
- (void) setBufferName:(NSString *)name;
- (void) setPlayerPath:(NSString *)path;

// playback controls (take effect imediately)
- (void) playWithInfo:(MovieInfo *)mf;				// play item from saved time
- (void) play;
- (void) stop;										// stops playback
- (void) pause;										// pause / unpause playback
- (void) seek:(float)seconds mode:(int)aMode;		// seek in movie
- (void) performCommand:(NSString *)aCommand;

// settings (take effect by using applySettingsWithRestart: message)
// setting files
- (void) setMovieFile:(NSString *)aFile;
- (void) setSubtitlesFile:(NSString *)aFile;
- (void) setAudioFile:(NSString *)aFile;
//beta
- (void) setAudioExportFile:(NSString *)aFile;

// playback
- (void) setAudioLanguages:(NSString *)langString;
- (void) setSubtitleLanguages:(NSString *)langString;
- (void) setCorrectPTS:(BOOL)aBool;
- (void) setCacheSize:(unsigned int)kilobytes;

// text
- (void) setFont:(NSString *)aFile;
- (void) setGuessEncodingLang:(NSString *)aLang;
- (void) setAssSubtitles:(BOOL)aBool;
- (void) setEmbeddedFonts:(BOOL)aBool;
- (void) setSubtitlesEncoding:(NSString *)aEncoding;// sets subtitles file encoding
- (void) setSubtitlesScale:(unsigned int)aScale;	// sets subtitle scale in % (see man mplayer)
- (void) setAssPreFilter:(BOOL)aBool;
- (void) setSubtitlesColor:(NSColor *)color;
- (void) setSubtitlesBorderColor:(NSColor *)color;
- (void) setOsdLevel:(int)anInt;
- (void) setOsdScale:(unsigned int)anInt;

// display
- (void) setDisplayType:(unsigned int)mode;
- (void) setFlipVertical:(BOOL)aBool;
- (void) setFlipHorizontal:(BOOL)aBool;
- (void) setMovieSize:(NSSize)aSize;				// set height to 0 to keep aspect ratio)
- (NSSize) movieSize;
- (void) setAspectRatio:(double)ratio;
- (void) setMonitorAspectRatio:(double)ratio;
- (void) setDeviceId:(unsigned int)dId;
- (unsigned int)getDeviceId;
- (void) setVideoOutModule:(int)module;
- (void) setScreenshotPath:(NSString*)path;

// video
- (void) setVideoEnabled:(BOOL)aBool;
- (void) setVideoCodecs:(NSString *)codecString;
- (void) setFramedrop:(unsigned int)mode;
- (void) setFastLibavcodec:(BOOL)aBool;
- (void) setDeinterlace:(unsigned int)mode;
- (void) setPostprocessing:(unsigned int)mode;
- (void) setSkipLoopfilter:(unsigned int)mode;

// audio
- (void) setAudioEnabled:(BOOL)aBool;
- (void) setAudioCodecs:(NSString *)codecString;
- (void) setAC3Passthrough:(BOOL)aBool;
- (void) setDTSPassthrough:(BOOL)aBool;
- (void) setHRTFFilter:(BOOL)aBool;
- (void) setKaraokeFilter:(BOOL)aBool;

// advanced
- (void) setEqualizerEnabled:(BOOL)aBool;
- (void) setEqualizer:(NSArray *)freqs;
- (void) setVideoEqualizerEnabled:(BOOL)aBool;
- (void) setVideoEqualizer:(NSArray *)values;
- (void) setAdditionalParams:(NSArray *)params;

//- (void) setVIDEO_TS:(BOOL)aBool;					// dvd folder

- (void) setRebuildIndex:(BOOL)aBool;				// take effect after restarting playback
- (void) setFullscreen:(BOOL)aBool;
- (BOOL) fullscreen;

// misc settings (don't work during playback)
- (void) setVolume:(unsigned int)percents;			// set audio volume

// other methods
- (void) applySettingsWithRestart:(BOOL)restartIt;	// applyes settings that require restart
- (void) waitUntilExit;
- (void) takeScreenshot;

// info
- (void) loadInfoBeforePlayback:(BOOL)aBool;		// enables using of -identify param for playback
- (void) loadInfo;						// gets info returned by -identify (don't work during playback)
- (MovieInfo *) info;							// returns the content of info dictionary 
- (int) status;
- (float) seconds;									// returns number of seconds, elapsed
- (BOOL) changesNeedsRestart;						// retuns YES if changes needs restart
- (BOOL) videoOutHasChanged;
- (BOOL) isRunning;
- (BOOL) isPlaying;
- (BOOL) isWindowed;

// statistics
- (void) setUpdateStatistics:(BOOL)aBool;			// sets whether to update stats
- (float) syncDifference;
- (int) cpuUsage;
- (int) cacheUsage;
- (int) droppedFrames;
- (int) postProcLevel;

// advenced
- (void)sendCommand:(NSString *)aCommand withType:(uint)type;
- (void)sendCommand:(NSString *)aCommand;
- (void)sendCommands:(NSArray *)aCommands withType:(uint)type;
- (void)sendCommands:(NSArray *)aCommands;
- (void)runMplayerWithParams:(NSArray *)aParams;
- (void)sendToMplayersInput:(NSString *)aCommand;
- (void)terminateMplayer;

- (void)reactivateOsdAfterDelay;
- (void)reactivateOsd;

// notification handlers
- (void) mplayerTerminated;
- (void)readError:(NSNotification *)notification;
- (void) readOutputC:(NSNotification *)notification;

// helper
-(NSArray *)splitString:(NSString *)string byCharactersInSet:(NSCharacterSet *)set;

@end
