/*
 *  AppController.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "AppController.h"

#include <Carbon/Carbon.h>
#import <Sparkle/Sparkle.h>

// other controllers
#import "MenuController.h"
#import "PlayerController.h"
#import "PlayListController.h"
#import "PreferencesController2.h"
#import "EqualizerController.h"
#import "InspectorController.h"

#import "MovieInfo.h"
#import "Preferences.h"

#import "CocoaAdditions.h"

#import "AppleRemote.h"
#import "PFMoveApplication.h"
#import "RegexKitLite.h"

#import "MovieMethods.h"

NSString* const MPENewPlayerOpenedNotification           = @"MPENewPlayerOpenedNotification";
NSString* const MPEPlayerClosedNotification              = @"MPEPlayerClosedNotification";
NSString* const MPEPlayerNotificationPlayerControllerKey = @"MPEPlayerNotificationPlayerControllerKey";
NSString* const MPEPlayerStoppedNotification			 = @"MPEPlayerStoppedNotification";

@implementation AppController
@synthesize activePlayer, preferencesController, menuController, aspectMenu, movieInfoProvider, players;

static AppController *instance = nil;

/************************************************************************************/
#pragma mark - INITIALIZATION
/************************************************************************************/
- (id)init
{
	if ((self = [super init])) {
		
		players = [NSMutableArray new];
		
		// save instance for sharedController
		instance = self;
	}
	return self;
}

- (void)dealloc
{
	[preferencesSpecs release];
	[players dealloc];
	
	[super dealloc];
}

+ (AppController *) sharedController
{
	return instance;
}

+ (void)initialize
{
	[NSValueTransformer setValueTransformer:[[ENCACodeTransformer new] autorelease]
									forName:@"ENCACodeTransformer"];
}

- (void) awakeFromNib
{
	// make sure initialization is not repeated
	if (preferencesSpecs)
		return;
	
	// create preferences and register application factory presets
	NSString *specFilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"Preferences.plist"];
	preferencesSpecs = [[NSDictionary alloc] initWithContentsOfFile:specFilePath];
	
	if (preferencesSpecs) {
		NSMutableDictionary *defaultsAndConstants = [NSMutableDictionary dictionary];
		[defaultsAndConstants addEntriesFromDictionary:[preferencesSpecs objectForKey:@"Defaults"]];
		[defaultsAndConstants addEntriesFromDictionary:[preferencesSpecs objectForKey:@"Constants"]];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsAndConstants];
	} else
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to load preferences specs."];
	
	// register for urls
	[[NSAppleEventManager sharedAppleEventManager] 
		setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) 
		forEventClass:kInternetEventClass andEventID:kAEGetURL];
	
	// pre-load language codes
	[LanguageCodes sharedInstance];
	
	// register for sparkle feed changes
	[PREFS addObserver:self
			forKeyPath:MPECheckForUpdatesIncludesPrereleases
			   options:0
			   context:nil];
}

- (EqualizerController *)equalizerController
{
	if (!equalizerController)
		[NSBundle loadNibNamed:@"Equalizers" owner:self];
	return equalizerController;
}

- (InspectorController *)inspectorController
{
	if (!inspectorController)
		[NSBundle loadNibNamed:@"Inspector" owner:self];
	return inspectorController;
}

/************************************************************************************/
#pragma mark - INTERFACE
/************************************************************************************/
- (NSUserDefaults *) preferences
{
	return [NSUserDefaults standardUserDefaults];
}
- (NSArray *) preferencesRequiringRestart
{
	return [preferencesSpecs objectForKey:@"RequiresRestart"];
}
/************************************************************************************/
- (void) restart
{
	NSString *restartScript = @"while ps -p $1 > /dev/null; do sleep 0.1; done; open \"$2\"";
	
	NSArray *arguments = [NSArray arrayWithObjects:
						  @"-c", restartScript,
						  @"",
						  [NSString stringWithFormat:@"%d",[[NSProcessInfo processInfo] processIdentifier]],
						  [[NSBundle mainBundle] bundlePath],
						  nil];
	
	[NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:arguments];
	
	[NSApp terminate:self];
}
/************************************************************************************/
- (NSUInteger) registerPlayer:(PlayerController *)player
{
	[players addObject:player];
	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  player,MPEPlayerNotificationPlayerControllerKey,
						  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:MPENewPlayerOpenedNotification
														object:self
													  userInfo:info];
	
	return ([players count]-1);
}

- (void) removePlayer:(PlayerController *)player
{
	[players removeObject:player];
	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  player,MPEPlayerNotificationPlayerControllerKey,
						  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:MPEPlayerClosedNotification
														object:self
													  userInfo:info];
}

- (PlayerController *) createNewPlayerController
{
	[NSBundle loadNibNamed:@"Player" owner:self];
	PlayerController *player = [players lastObject];
	return player;
}

- (PlayerController *) getPlayer
{
	PlayerController *player = nil;
	
	// Try to reuse an existing player
	if ([PREFS boolForKey:MPEOpenFilesReusePlayers]) {
		for (PlayerController *existingPlayer in players) {
			if (![existingPlayer isRunning]) {
				return existingPlayer;
			}
		}
	}
		
	// Open a new player
	if ([players count] == 0 || [PREFS integerForKey:MPEOpenFilesMode] == MPEOpenFilesInNewPlayer) {
		return [self createNewPlayerController];

	// Find frontmost window
	} else {
		NSArray *windows = [NSApp orderedWindows];
		NSUInteger windowIndex = NSUIntegerMax;
		for (PlayerController *existingPlayer in players) {
			NSUInteger index = [windows indexOfObject:[player playerWindow]];
			if (!player || (index != NSNotFound && index < windowIndex)) {
				player = existingPlayer;
				windowIndex = index;
			}
		}
		return player;
	}
}

- (void) openNewPlayerWindow:(id)sender
{
	[[self createNewPlayerController] displayWindow:self];
}

- (void) playerDidBecomeActivePlayer:(PlayerController *)player
{
	if (activePlayer) {
		[Debug log:ASL_LEVEL_WARNING withMessage:@"Overwriting active player controller."];
	}
	
	activePlayer = [player retain];
	
	[appleRemote setDelegate:player];
	
	[player playerDidBecomeActivePlayer];
}

- (void) playerResignedActivePlayer:(PlayerController *)player
{
	if (activePlayer != player) return;
	
	[player playerWillResignActivePlayer];
	
	activePlayer = nil;
	
	[appleRemote setDelegate:nil];
}

- (BOOL) changesRequireRestart
{
	for (PlayerController *player in players) {
		if ([player changesRequireRestart]) return YES;
	}
	return NO;
}

- (void) applyChangesWithRestart:(BOOL)restart
{
	for (PlayerController *player in players) {
		[player applyChangesWithRestart:restart];
	}
}

/************************************************************************************/
#pragma mark - ACTIONS
/************************************************************************************/
- (IBAction) openFile:(id)sender
{
	NSString *theFile;
	
	// present open dialog
	theFile = [self openDialogForType:MP_DIALOG_MEDIA];
	
	[self openFilePath:theFile];
}

- (void) openFilePath:(NSString*)filepath
{
	if (filepath) {
		// if any file, create new item and play it
		MovieInfo *item = [MovieInfo movieInfoWithPathToFile:filepath];
		// apply selection from binary selection popup
		NSString *binary = [preferencesController identifierFromSelectionInView];
		if (binary)
			[[item prefs] setObject:binary forKey:MPESelectedBinary];
		[[self getPlayer] playItem:item];
	}
}


//BETA//////////////////////////////////////////////////////////////////////////////////
- (IBAction) openVIDEO_TS:(id)sender
{
    NSOpenPanel *thePanel = [NSOpenPanel openPanel];
	NSString *theDir = nil;
	NSString *defDir;
	
	if (!(defDir = [[self preferences] objectForKey:MPEDefaultDirectory]))
		defDir = NSHomeDirectory();

    [thePanel setAllowsMultipleSelection:NO];
	[thePanel setCanChooseDirectories : YES ];
	[thePanel setCanChooseFiles : NO ];
	
    if ([thePanel runModalForDirectory:defDir file:nil types:[NSArray arrayWithObject:@"VOB"]] == NSOKButton) {
        theDir = [[thePanel filenames] objectAtIndex:0];
		[[NSUserDefaults standardUserDefaults]
				setObject:[theDir stringByDeletingLastPathComponent]
				forKey:MPEDefaultDirectory];
		if ([self isDVD:theDir]) {
			MovieInfo *item = [MovieInfo movieInfoWithPathToFile:theDir];
			[[self getPlayer] playItem:item];
		}
		else {
			NSRunAlertPanel(NSLocalizedString(@"Error",nil),
					NSLocalizedString(@"Selected folder is not valid VIDEO_TS folder.",nil),
					NSLocalizedString(@"OK",nil),nil,nil);
		}
    }
}

/************************************************************************************/
- (IBAction) addToPlaylist:(id)sender
{
	NSMutableArray *fileTypes;
	NSOpenPanel *thePanel = [NSOpenPanel openPanel];
	NSString *defDir;
	
	// take both audio and movie files in account
	fileTypes = [NSMutableArray arrayWithArray:[self typeExtensionsForName:@"Movie file"]];
	[fileTypes addObjectsFromArray:[self typeExtensionsForName:@"Audio file"]];
	
	// present open dialog
	if (!(defDir = [[self preferences] objectForKey:MPEDefaultDirectory]))
		defDir = NSHomeDirectory();
	
	// allow multiple selection
	[thePanel setAllowsMultipleSelection:YES];
	
    if ([thePanel runModalForDirectory:defDir file:nil types:fileTypes] == NSOKButton) {
        int i;
		//  take care of multiple selection
		for (i=0; i<[[thePanel filenames] count]; i++) {
			//MovieInfo *item = [MovieInfo movieInfoWithPathToFile:[[thePanel filenames] objectAtIndex:i]];
			[[self preferences]
					setObject:[[[thePanel filenames] objectAtIndex:i]
					stringByDeletingLastPathComponent]
					forKey:MPEDefaultDirectory];
			// TODO: Get correct playlist here
			//[[[self firstPlayerController] playListController] appendItem:item];
		}
    }
}
/************************************************************************************/
- (IBAction) openLocation:(id)sender
{
	if ([NSApp runModalForWindow:locationPanel] == 1) {
		MovieInfo *item = [MovieInfo movieInfoWithPathToFile:[locationBox stringValue]];
		[[self getPlayer] playItem:item];
	}
}

/******************************************************************************/
- (IBAction) openSubtitle:(id)sender
{
	// present open dialog
	NSString *theFile = [self openDialogForType:MP_DIALOG_SUBTITLES];
	if (theFile && activePlayer) {
		NSString *encoding = nil;
		if ([openSubtitleEncoding selectedTag] > -1)
			encoding = [openSubtitleEncoding titleOfSelectedItem];
		[activePlayer loadExternalSubtitleFile:theFile withEncoding:encoding];
	}
}

/************************************************************************************/
//BETA
- (IBAction) openVIDEO_TSLocation:(id)sender
{
	if ([NSApp runModalForWindow:video_tsPanel] == 1) {
		MovieInfo *item = [MovieInfo movieInfoWithPathToFile:[video_tsBox stringValue]];
		[[self getPlayer] playItem:item];
	}
}

- (IBAction) cancelVIDEO_TSLocation:(id)sender
{
	[NSApp stopModalWithCode:0];
	[video_tsPanel orderOut:nil];
}
- (IBAction) applyVIDEO_TSLocation:(id)sender
{
	NSURL *theUrl = [NSURL URLWithString:[video_tsBox stringValue]];
	if ([[theUrl scheme] caseInsensitiveCompare:@"http"] == NSOrderedSame ||
			[[theUrl scheme] caseInsensitiveCompare:@"ftp"] == NSOrderedSame ||
			[[theUrl scheme] caseInsensitiveCompare:@"rtsp"] == NSOrderedSame ||
			[[theUrl scheme] caseInsensitiveCompare:@"dvd"] == NSOrderedSame ||
			[[theUrl scheme] caseInsensitiveCompare:@"mms"] == NSOrderedSame) {
		[video_tsBox setStringValue:[[theUrl standardizedURL] absoluteString]];
		[NSApp stopModalWithCode:1];
		[video_tsPanel orderOut:nil];
	}
	else
		NSBeginAlertSheet(NSLocalizedString(@"Error",nil),
				NSLocalizedString(@"OK",nil), nil, nil, video_tsPanel, nil, nil, nil, nil,
				NSLocalizedString(@"The URL is not in correct format or cannot be handled by this application.",nil));
}
/************************************************************************************/
- (IBAction) applyLocation:(id)sender
{
	NSURL *theUrl = [NSURL URLWithString:[locationBox stringValue]];
	if ([[theUrl scheme] caseInsensitiveCompare:@"http"] == NSOrderedSame ||
			[[theUrl scheme] caseInsensitiveCompare:@"ftp"] == NSOrderedSame ||
			[[theUrl scheme] caseInsensitiveCompare:@"rtsp"] == NSOrderedSame ||
			[[theUrl scheme] caseInsensitiveCompare:@"dvd"] == NSOrderedSame ||
			[[theUrl scheme] caseInsensitiveCompare:@"vcd"] == NSOrderedSame ||
			[[theUrl scheme] caseInsensitiveCompare:@"mms"] == NSOrderedSame) {
		[locationBox setStringValue:[[theUrl standardizedURL] absoluteString]];
		[NSApp stopModalWithCode:1];
		[locationPanel orderOut:nil];
	}
	else
		NSBeginAlertSheet(NSLocalizedString(@"Error",nil),
				NSLocalizedString(@"OK",nil), nil, nil, locationPanel, nil, nil, nil, nil,
				NSLocalizedString(@"The URL is not in correct format or cannot be handled by this application.",nil));
}
/************************************************************************************/
- (IBAction) cancelLocation:(id)sender
{
	[NSApp stopModalWithCode:0];
	[locationPanel orderOut:nil];
}

/*
	Display Log
*/
- (IBAction) displayLogWindow:(id)sender
{
	NSTask *finderOpenTask;
	NSArray *finderOpenArg;
	NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/MPlayerOSX.log"];

	finderOpenArg = [NSArray arrayWithObject:logPath];
	finderOpenTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:finderOpenArg];
	if (!finderOpenTask)
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to launch the console.app"];
}

- (IBAction) openHomepage:(id)sender
{
	NSURL *homepage = [NSURL URLWithString:[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHomepage"]];
	[[NSWorkspace sharedWorkspace] openURL:homepage];
}

- (IBAction) openLicenseAndCredits:(id)sender
{
	NSString *locBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	AHGotoPage((CFStringRef)locBookName, (CFStringRef)@"creditslicense.html", 0);
}

- (IBAction) closeWindow:(id)sender 
{	
	[[NSApp keyWindow] performClose:self];
}

/************************************************************************************/
#pragma mark - BUNDLE ACCESS
/************************************************************************************/
// return array of document extensions of specified document type name
- (NSArray *) typeExtensionsForName:(NSString *)typeName
{
	int i;
	NSArray *typeList = [[[NSBundle mainBundle] infoDictionary]
			objectForKey:@"CFBundleDocumentTypes"];
	for (i=0; i<[typeList count]; i++) {
		if ([[[typeList objectAtIndex:i] objectForKey:@"CFBundleTypeName"]
			isEqualToString:typeName])
			return [[typeList objectAtIndex:i] objectForKey:@"CFBundleTypeExtensions"];
	}
	return nil;
}
/************************************************************************************/
- (NSArray *) getExtensionsForType:(int)type {
	
	NSMutableArray *typeList = [NSMutableArray arrayWithCapacity:10];
	
	// Load file types
	if (type == MP_DIALOG_MEDIA || type == MP_DIALOG_VIDEO)
		[typeList addObjectsFromArray:[self typeExtensionsForName:@"Movie file"]];
	if (type == MP_DIALOG_MEDIA || type == MP_DIALOG_AUDIO)
		[typeList addObjectsFromArray:[self typeExtensionsForName:@"Audio file"]];
	if (type == MP_DIALOG_SUBTITLES)
		[typeList addObjectsFromArray:[self typeExtensionsForName:@"Subtitles file"]];
	
	return typeList;
}
/************************************************************************************/
// returns YES if the extension string is member of given type from main bundle
- (BOOL) isExtension:(NSString *)theExt ofType:(int)type
{
	int	i;
	NSArray *extList = [self getExtensionsForType:type];
	if (extList == nil)
		return NO;
	for (i = 0; i<[extList count]; i++) {
		if ([[extList objectAtIndex:i] caseInsensitiveCompare:theExt] == NSOrderedSame)
			return YES;
	}
	return NO;
}

// return YES if the path is a dvd-folder (either named "VIDEO_TS" or containing a "VIDEO_TS.IFO" file)
- (BOOL) isDVD:(NSString *)path
{
	BOOL isDirectory;
	if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory)
		return NO;
	
	if ([[path lastPathComponent] isMatchedByRegex:@"(?i)^VIDEO_TS$"])
		return YES;
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:@"VIDEO_TS.IFO"]])
		return YES;
	
	return NO;
}

/************************************************************************************/
#pragma mark -  MISC METHODS
/************************************************************************************/
// presents open dialog for certain types
- (NSString *) openDialogForType:(int)type
{
    NSArray *typeList = [self getExtensionsForType:type];
	openPanel = [NSOpenPanel openPanel];
	NSString *theFile = nil;
	NSString *defDir;
	
	if (!(defDir = [[self preferences] objectForKey:MPEDefaultDirectory]))
		defDir = NSHomeDirectory();

    [openPanel setAllowsMultipleSelection:NO];
	[openPanel setDelegate:self];
	[openPanel setAllowedFileTypes:typeList];
	
	// show additional options based on type
	if (type == MP_DIALOG_MEDIA || type == MP_DIALOG_VIDEO) { 
		NSView *options = [[[NSView alloc] initWithFrame:NSZeroRect] autorelease];
		[options addSubview:openFileSettings];
		[options addSubview:[preferencesController binarySelectionView]];
		[options resizeAndArrangeSubviewsVerticallyWithPadding:5];
		[openPanel setAccessoryView:options];
		[self showFilesChanged:openFileTypeMenu];
	} else if (type == MP_DIALOG_SUBTITLES) {
		// beta: add encoding dropdown and load state from preferences
		[openPanel setAccessoryView:openSubtitleSettings];
		if ([[self preferences] objectForKey:MPETextEncoding]) {
			[openSubtitleEncoding selectItemWithTitle:[[self preferences] objectForKey:MPETextEncoding]];
			if ([openSubtitleEncoding indexOfSelectedItem] < 0)
				[openSubtitleEncoding selectItemAtIndex:0];
		}
		else
			[openSubtitleEncoding selectItemAtIndex:0];
	}
	
    if ([openPanel runModalForDirectory:defDir file:nil types:nil] == NSOKButton) {
        theFile = [[openPanel filenames] objectAtIndex:0];
		[[NSUserDefaults standardUserDefaults]
				setObject:[theFile stringByDeletingLastPathComponent]
				forKey:MPEDefaultDirectory];
    }
	return theFile;
}
//openfor folders
- (NSString *) openDialogForFolders:(NSArray *)typeList
{
    NSOpenPanel *thePanel = [NSOpenPanel openPanel];
	NSString *theFile = nil;
	NSString *defDir;
	
	if (!(defDir = [[self preferences] objectForKey:MPEDefaultDirectory]))
		defDir = NSHomeDirectory();

    [thePanel setAllowsMultipleSelection:NO];
	[thePanel setCanChooseDirectories : YES ];
	[thePanel setCanChooseFiles : NO ];
	
    if ([thePanel runModalForDirectory:defDir file:nil types:typeList] == NSOKButton) {
        theFile = [[thePanel filenames] objectAtIndex:0];
		[[NSUserDefaults standardUserDefaults]
				setObject:[theFile stringByDeletingLastPathComponent]
				forKey:MPEDefaultDirectory];
    }
	return theFile;
}

// enable the allowedFileTypes array to influence seleced file types in 
// open dialogs - even after the dialog has opened.
- (BOOL) panel:(id)sender shouldShowFilename:(NSString *)filename
{
	if (![sender allowedFileTypes])
		return YES;
	
	NSString* ext = [filename pathExtension];
	NSEnumerator* tagEnumerator = [[sender allowedFileTypes] objectEnumerator];
	NSString* allowedExt;
	BOOL isDirectory;
	
	while ((allowedExt = [tagEnumerator nextObject])) {
		if ([ext caseInsensitiveCompare:allowedExt] == NSOrderedSame)
			return YES;
		if ([[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory)
			return YES;
	}
	
	return NO;
}

// the show file popup in the open dialog has changed
- (IBAction) showFilesChanged:(NSPopUpButton*)sender
{
	// Show all known media types
	if ([sender indexOfSelectedItem] == 0)
		[openPanel setAllowedFileTypes:[self getExtensionsForType:MP_DIALOG_MEDIA]];
		
	// Only show video files
	else if ([sender indexOfSelectedItem] == 1)
		[openPanel setAllowedFileTypes:[self getExtensionsForType:MP_DIALOG_VIDEO]];
		
	// Only show audio files
	else if ([sender indexOfSelectedItem] == 2)
		[openPanel setAllowedFileTypes:[self getExtensionsForType:MP_DIALOG_AUDIO]];
		
	// Show all fiels
	else
		[openPanel setAllowedFileTypes:nil];
	
}

//beta
/*
- (NSString *) saveDialogForTypes:(NSArray *)typeList
{
    NSSavePanel *thePanel = [NSSavePanel savePanel];
	NSString *theFile = nil;
	NSString *defDir;
	
	if (!(defDir = [[self preferences] objectForKey:MPEDefaultDirectory]))
		defDir = NSHomeDirectory();

 //   [thePanel setAllowsMultipleSelection:NO];

    if ([thePanel runModalForDirectory:defDir file:nil types:typeList] == NSOKButton) {
        theFile = [[thePanel filenames] objectAtIndex:0];
		[[NSUserDefaults standardUserDefaults]
				setObject:[theFile stringByDeletingLastPathComponent]
				forKey:MPEDefaultDirectory];
    }
	return theFile;
}
*/


// animate interface transitions
- (BOOL) animateInterface
{
	if ([[self preferences] objectForKey:MPEAnimateInterfaceTransitions])
		return [[self preferences] boolForKey:MPEAnimateInterfaceTransitions];
	else
		return YES;
}

// Play the next episode based on the current file's filepath
- (IBAction) playNextEpisode:(id)sender
{
	NSString *filename = [[self.movieInfoProvider currentMovieInfo] filename];
	NSString *result = [MovieMethods findNextEpisodePathFrom:filename];
	[Debug log:ASL_LEVEL_INFO withMessage:@"currentFile=%@ nextFile=%@",filename, result ];
	if (result) [self openFilePath:result];
}

/************************************************************************************/
#pragma mark - DELEGATE METHODS
/*************************************************************************************/
// app delegate method
// executes when file is double clicked or dropped on apps icon
// immediatlely starts to play dropped file without adding it to the playlist
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	if (filename) {
		// load a binary bundle
		if ([[filename pathExtension] isEqualToString:@"mpBinaries"]) {
			[preferencesController installBinary:filename];
		// load subtitles while playing
		} else if (activePlayer && [self isExtension:[filename pathExtension] ofType:MP_DIALOG_SUBTITLES]) {
			[activePlayer loadExternalSubtitleFile:filename withEncoding:nil];
		// try playing the file otherwise
		} else {
			MovieInfo *item = [MovieInfo movieInfoWithPathToFile:filename];
			[[self getPlayer] playItem:item];
		}
		return YES;
	}
	return NO;
}
/************************************************************************************/
- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	// Handle single file
	if ([filenames count] == 1) {
		if ([self application:sender openFile:[filenames objectAtIndex:0]])
			[[NSApplication sharedApplication] replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		else
			[[NSApplication sharedApplication] replyToOpenOrPrint:NSApplicationDelegateReplyFailure];
		return;
	}
	
	NSEnumerator *e = [filenames objectEnumerator];
	NSString *filename;
	
	// TODO: Create new playlist here
	//[[[self firstPlayerController] playListController] displayWindow:self];
	
	// add files to playlist
	while ((filename = [e nextObject])) {
		// Only add movie files
		if ([self isExtension:[filename pathExtension] ofType:MP_DIALOG_MEDIA]) {
			//MovieInfo *item = [MovieInfo movieInfoWithPathToFile:filename];
			//[[[self firstPlayerController] playListController] appendItem:item];
		}
	}
	
	[sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}
/************************************************************************************/
- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	
	MovieInfo *item = [MovieInfo movieInfoWithPathToFile:url];
	[[self getPlayer] playItem:item];
}
/************************************************************************************/
- (void) applicationDidBecomeActive:(NSNotification *)aNotification
{
    [appleRemote startListening: self];
}

- (void) applicationDidResignActive:(NSNotification *)aNotification
{
    [appleRemote stopListening: self];
}
/************************************************************************************/
// posted when application wants to terminate
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	// post notification first
	[[NSNotificationCenter defaultCenter]
			postNotificationName:@"ApplicationShouldTerminateNotification"
			object:NSApp
			userInfo:nil];

	// try to save preferences
	if (![[self preferences] synchronize]) {
		// if prefs could not be saved present alert box
		if (NSRunAlertPanel(NSLocalizedString(@"Error",nil),
				NSLocalizedString(@"Preferences could not be saved.\nQuit anyway?",nil),
				NSLocalizedString(@"OK",nil),
				NSLocalizedString(@"Cancel",nil),nil) == NSAlertAlternateReturn)
			return NSTerminateCancel;
	}
	
	[Debug log:ASL_LEVEL_INFO withMessage:@"===================== MPlayer OSX Terminated ====================="];
	
	// Uninit Debug class
	[[Debug sharedDebugger] uninit];
	
	return NSTerminateNow;
}

/******************************************************************************/
// only enable openSubtitle menu item when mplayer is playing 
- (BOOL) validateMenuItem:(NSMenuItem *)aMenuItem
{
	if ([aMenuItem action] == @selector(openSubtitle:))
		return (activePlayer && [activePlayer isRunning]);
	return YES;
}
/******************************************************************************/
- (void) applicationWillFinishLaunching:(NSNotification *)aNotification
{
	// Load player and preferences
	[NSBundle loadNibNamed:@"Player" owner:self];
	[NSBundle loadNibNamed:@"Preferences" owner:self];
	
	if ([PREFS boolForKey:MPEInspectorOpen])
		[[[self inspectorController] window] makeKeyAndOrderFront:self];
	
	// enable apple remote support
	appleRemote = [[AppleRemote alloc] init];
	[appleRemote setClickCountEnabledButtons: kRemoteButtonPlay];
	
	// set sparkle feed url for prereleases
	[self setSparkleFeed];
	
	// offer to move application
	if (PFMoveToApplicationsFolderIfNecessary())
		return;
	
	// show main window if we won't be moved
	[[players lastObject] displayWindow:self];
	
	// only initialize fontconfig if not moving and player window is loaded
	[preferencesController loadFonts];
}
/******************************************************************************/
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:MPECheckForUpdatesIncludesPrereleases])
		[self setSparkleFeed];
}
/******************************************************************************/
- (void) setSparkleFeed
{
	NSString *feed;
	
	if ([[self preferences] boolForKey:MPECheckForUpdatesIncludesPrereleases])
		feed = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"SUPrereleaseFeedURL"];
	else
		feed = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"SUFeedURL"];
	
	if (feed)
		[[SUUpdater sharedUpdater] setFeedURL:[NSURL URLWithString:feed]];
	else
		[Debug log:ASL_LEVEL_ERR withMessage:@"No feed URL found for automatic updates."];
}
/******************************************************************************/
+ (NSString *) userApplicationSupportDirectoryPath
{
	NSArray *results = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
														   NSUserDomainMask, YES);
	if ([results count] > 0)
		return [results objectAtIndex:0];
	else
		return nil;
}
/******************************************************************************/
@end
