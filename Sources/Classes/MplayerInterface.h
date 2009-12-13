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

@class MplayerInterface;

@protocol MplayerInterfaceClientProtocol
- (void) interface:(MplayerInterface *)mi hasChangedStateTo:(int)state;
- (void) interface:(MplayerInterface *)mi timeUpdate:(float)newTime;
- (void) interface:(MplayerInterface *)mi streamUpate:(MovieInfo *)item;
- (void) interface:(MplayerInterface *)mi selectedSteamsUpdate:(NSArray *)streamIds;
- (void) interface:(MplayerInterface *)mi statsUpdate:(NSArray *)stats;
@end

enum {
	MIStateFinished = -1,
	MIStateStopped,
	MIStatePlaying,
	MIStatePaused,
	MIStateOpening,
	MIStateBuffering,
	MIStateIndexing,
	MIStateInitializing,
	MIStateSeeking
};
typedef NSInteger MIState;

enum {
	MISeekingModeRelative,
	MISeekingModePercent,
	MISeekingModeAbsolute
};
typedef NSUInteger MISeekingMode;

enum {
	MISurpressCommandOutputAlways,
	MISurpressCommandOutputConditionally,
	MISurpressCommandOutputNever
};
typedef NSUInteger MICommandOutputSurpression;

enum {
	MICommandPausingNone,
	MICommandPausingKeep,
	MICommandPausingToggle,
	MICommandPausingKeepForce
};
typedef NSUInteger MICommandPausingMode;

@interface MplayerInterface : NSObject
{	
	// Properties
	// file paths
	NSString *myPathToPlayer;
	NSMutableArray *mySubtitlesFiles;
	
	MovieInfo *playingItem;
	
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
	MIState	state;
	unsigned int myVolume;
	BOOL playing;
	BOOL movieOpen;
	
	//beta
	float mySeconds;
	BOOL isSeeking;
	
	// statistics
	BOOL myUpdateStatistics;
	float mySyncDifference;
	int myCPUUsage;
	int myCacheUsage;
	int	myDroppedFrames;
	int myPostProcLevel;
	
	// internal use
	NSTask *myMplayerTask;
	double myLastUpdate;
	BOOL restartingPlayer;
	BOOL pausedOnRestart;
	BOOL isRunning;
	int myOutputReadMode;
	NSMutableArray *myCommandsBuffer;
	NSString *lastUnparsedLine;
	NSString *lastUnparsedErrorLine;
	int subtitleFileId;
	NSDictionary *lastMissedSeek;
	BOOL is64bitHost;
	BOOL force32bitBinary;
}

@property (nonatomic,getter=isPlaying) BOOL playing;
@property (nonatomic,getter=isMovieOpen) BOOL movieOpen;

@property (nonatomic) MIState state;

- (void) setBufferName:(NSString *)name;

- (void) playItem:(MovieInfo *)item;
- (void) play;
- (void) registerPlayingItem:(MovieInfo *)item;
- (void) unregisterPlayingItem;

- (void) stop;
- (void) pause;
- (void) seek:(float)seconds mode:(int)aMode;
- (void) performCommand:(NSString *)aCommand;

- (void) setVolume:(unsigned int)percents;
- (void) takeScreenshot;

- (void) loadNewSubtitleFile:(NSNotification *)notification;
- (void) applyVideoEqualizer;

- (void) applySettingsWithRestart;

// info
- (void) loadInfo:(MovieInfo *)item;
- (MovieInfo *) info;

- (float) seconds;
- (BOOL) changesNeedRestart;
- (BOOL) localChangesNeedRestart;

- (void) setState:(MIState)newState;
- (BOOL) isRunning;

// statistics
- (void) setUpdateStatistics:(BOOL)aBool;
- (float) syncDifference;
- (int) cpuUsage;
- (int) cacheUsage;
- (int) droppedFrames;
- (int) postProcLevel;

// advanced
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
- (void) readError:(NSNotification *)notification;
- (void) readOutputC:(NSNotification *)notification;

@end
