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
#define kSeeking					7

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

// pausing command modes
#define MI_CMD_PAUSING_NONE			0
#define MI_CMD_PAUSING_KEEP			1
#define MI_CMD_PAUSING_TOGGLE		2
#define MI_CMD_PAUSING_FORCE		3

@interface MplayerInterface : NSObject
{	
	// Properties
	// file paths
	NSString *myPathToPlayer;
	NSString *myMovieFile;
	NSMutableArray *mySubtitlesFiles;
	
	NSDictionary *playingItem;
	
	NSDictionary *localPrefs;
	NSDictionary *prefs;
	
	NSString *buffer_name;
	
	// playback
	BOOL osdSilenced;
	int numberOfThreads;
	
	BOOL disableAppleRemote;
	
	// display
	NSString *screenshotPath;
	
	// text
	int osdLevel;
	
	// properties
	BOOL isPreflight;
	
	// state variables
	int	myState;				// player state
	unsigned int myVolume;		// volume 0-100
	BOOL playing;
	BOOL movieOpen;
	
	//beta
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
	BOOL restartingPlayer;			// set when player is teminated to be restarted
	BOOL pausedOnRestart;			// set when paused during attemp to restart player
	BOOL isRunning;					// set off after recieving termination notification
	int myOutputReadMode;				// defines playback output form 
	NSMutableArray *myCommandsBuffer;	// store cmds that cannot be send immediatelly
	NSString *lastUnparsedLine;
	NSString *lastUnparsedErrorLine;
	//NSMutableDictionary *myInfo;	// dict filled by -identify command
	int subtitleFileId;				// since sub file identify output is not numberede, we need to cache the id
	NSDictionary *lastMissedSeek;	// last seek that couldn't be processed
	BOOL is64bitHost;
	BOOL force32bitBinary;
	
	MovieInfo *info;
}

@property (nonatomic,getter=isPlaying) BOOL playing;
@property (nonatomic,getter=isMovieOpen) BOOL movieOpen;

// interface
// init and uninit
- (void) setBufferName:(NSString *)name;

- (void) registerPlayingItem:(NSDictionary *)item;
- (void) unregisterPlayingItem;

// playback controls (take effect imediately)
- (void) playItem:(NSMutableDictionary *)item;				// play item from saved time
- (void) play;
- (void) stop;										// stops playback
- (void) pause;										// pause / unpause playback
- (void) seek:(float)seconds mode:(int)aMode;		// seek in movie
- (void) performCommand:(NSString *)aCommand;

// settings (take effect by using applySettingsWithRestart: message)
// setting files
- (void) setMovieFile:(NSString *)aFile;
- (void) setSubtitlesFile:(NSString *)aFile;

- (void) applyVideoEqualizer;

// misc settings (don't work during playback)
- (void) setVolume:(unsigned int)percents;			// set audio volume

// other methods
- (void) applySettingsWithRestart;	// applyes settings that require restart
- (void) takeScreenshot;

// info
- (void) loadInfo;						// gets info returned by -identify (don't work during playback)
- (MovieInfo *) info;							// returns the content of info dictionary 
- (int) status;
- (float) seconds;									// returns number of seconds, elapsed
- (BOOL) changesNeedRestart;						// retuns YES if changes needs restart
- (BOOL) localChangesNeedRestart;

- (void) setState:(int)newState;
- (BOOL) isRunning;

// statistics
- (void) setUpdateStatistics:(BOOL)aBool;			// sets whether to update stats
- (float) syncDifference;
- (int) cpuUsage;
- (int) cacheUsage;
- (int) droppedFrames;
- (int) postProcLevel;

// advenced
- (void)sendCommand:(NSString *)aCommand withOSD:(uint)osdMode andPausing:(uint)pausing;
- (void)sendCommand:(NSString *)aCommand;
- (void)sendCommands:(NSArray *)aCommands withOSD:(uint)osdMode andPausing:(uint)pausing;
- (void)sendCommands:(NSArray *)aCommands;
- (void)runMplayerWithParams:(NSMutableArray *)aParams;
- (void)sendToMplayersInput:(NSString *)aCommand;
- (void)terminateMplayer;

- (void)reactivateOsdAfterDelay;
- (void)reactivateOsd;

// notification handlers
- (void) mplayerTerminated;
- (void)readError:(NSNotification *)notification;
- (void) readOutputC:(NSNotification *)notification;

@end
