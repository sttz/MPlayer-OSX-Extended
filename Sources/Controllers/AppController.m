/*
 *  AppController.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "AppController.h"
#import <Sparkle/Sparkle.h>

// other controllers
#import "PlayerController.h"
#import "PlayListController.h"

@implementation AppController
- (void) awakeFromNib;
{
	// create preferences and register application factory presets
	[[NSUserDefaults standardUserDefaults] registerDefaults:
	[[[NSBundle mainBundle] infoDictionary] objectForKey:@"ApplicationDefaults"]];
	
	// register for urls
	[[NSAppleEventManager sharedAppleEventManager] 
		setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) 
		forEventClass:kInternetEventClass andEventID:kAEGetURL];
	
	// register for app launch finish
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appFinishedLaunching)
			name: NSApplicationDidFinishLaunchingNotification
			object:NSApp];
	
	[self updateAspectMenu];
}

/************************************************************************************
 INTERFACE
 ************************************************************************************/
- (NSUserDefaults *) preferences
{
	return [NSUserDefaults standardUserDefaults];
}
/************************************************************************************/
- (BOOL) savePrefs
{
	return [[self preferences] synchronize];
}
/************************************************************************************/
- (void)quitApp
{
	[theApp terminate:self];
}

/************************************************************************************
 ACTIONS
 ************************************************************************************/
- (IBAction) openFile:(id)sender
{
	NSMutableArray *fileTypes;
	NSString *theFile;
	
	// take both audio and movie files in account
	fileTypes = [NSMutableArray arrayWithArray:[self typeExtensionsForName:@"Movie file"]];
	[fileTypes addObjectsFromArray:[self typeExtensionsForName:@"Audio file"]];
	
	// present open dialog
	theFile = [self openDialogForType:MP_DIALOG_MEDIA];
	
	if (theFile) {
		// if any file, create new item and play it
		NSMutableDictionary *theItem = [NSMutableDictionary
				dictionaryWithObject:theFile forKey:@"MovieFile"];
		[theItem setObject:[NSNumber numberWithInt:[openMultithreading state]] forKey:@"UseFFmpegMT"];
		[playerController playItem:theItem];
	}
}
//BETA//////////////////////////////////////////////////////////////////////////////////
- (IBAction) openVIDEO_TS:(id)sender
{
    NSOpenPanel *thePanel = [NSOpenPanel openPanel];
	NSString *theDir = nil;
	NSString *defDir;
	
	if (!(defDir = [[self preferences] objectForKey:@"DefaultDirectory"]))
		defDir = NSHomeDirectory();

    [thePanel setAllowsMultipleSelection:NO];
	[thePanel setCanChooseDirectories : YES ];
	[thePanel setCanChooseFiles : NO ];
	
    if ([thePanel runModalForDirectory:defDir file:nil types:[NSArray arrayWithObject:@"VOB"]] == NSOKButton) {
        theDir = [[thePanel filenames] objectAtIndex:0];
		[[NSUserDefaults standardUserDefaults]
				setObject:[theDir stringByDeletingLastPathComponent]
				forKey:@"DefaultDirectory"];
		if ([[theDir lastPathComponent] isEqualToString:@"VIDEO_TS"]) {
			NSMutableDictionary *theItem = [NSMutableDictionary
					dictionaryWithObject:theDir forKey:@"MovieFile"];
			[playerController playItem:theItem];
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
	if (!(defDir = [[self preferences] objectForKey:@"DefaultDirectory"]))
		defDir = NSHomeDirectory();
	
	// allow multiple selection
	[thePanel setAllowsMultipleSelection:YES];
	
    if ([thePanel runModalForDirectory:defDir file:nil types:fileTypes] == NSOKButton) {
        int i;
		//  take care of multiple selection
		for (i=0; i<[[thePanel filenames] count]; i++) {
			NSMutableDictionary *theItem = [NSMutableDictionary
					dictionaryWithObject:[[thePanel filenames] objectAtIndex:i]
					forKey:@"MovieFile"];
			[[self preferences]
					setObject:[[[thePanel filenames] objectAtIndex:i]
					stringByDeletingLastPathComponent]
					forKey:@"DefaultDirectory"];
			[playListController appendItem:theItem];
		}
    }
}
/************************************************************************************/
- (IBAction) openLocation:(id)sender
{
	if ([NSApp runModalForWindow:locationPanel] == 1) {
		NSMutableDictionary *theItem = [NSMutableDictionary
				dictionaryWithObject:[locationBox stringValue]
				forKey:@"MovieFile"];
		[playerController playItem:theItem];
	}
}

/******************************************************************************/
- (IBAction) openSubtitle:(id)sender
{
	// present open dialog
	NSString *theFile = [self openDialogForType:MP_DIALOG_SUBTITLES];
	if (theFile) {
		NSMutableDictionary *theItem = [NSMutableDictionary
				dictionaryWithObject:theFile forKey:@"SubtitlesFile"];
		// beta: [theItem setObject:[openSubtitleEncoding titleOfSelectedItem] forKey:@"SubtitlesEncoding"];
		[playerController playItem:theItem];
	}
}

/************************************************************************************/
//BETA
- (IBAction) openVIDEO_TSLocation:(id)sender
{
	if ([NSApp runModalForWindow:video_tsPanel] == 1) {
		NSMutableDictionary *theItem = [NSMutableDictionary
				dictionaryWithObject:[video_tsBox stringValue]
				forKey:@"MovieFile"];
		[playerController playItem:theItem];
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
	Display Playlist
*/
- (IBAction) displayPlayList:(id)sender
{
	[playListController displayWindow:sender];
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
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"http://mplayerosx.sttz.ch/"]];
}

- (IBAction) closeWindow:(id)sender {
	
	if ([NSApp keyWindow]) {
		if ([NSApp keyWindow] == playerWindow && [playerController isPlaying])
			[playerController stop:self];
		else
			[[NSApp keyWindow] performClose:self];
	}
}

/************************************************************************************
 BUNDLE ACCESS
 ************************************************************************************/
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

/************************************************************************************
 MISC METHODS
 ************************************************************************************/
// presents open dialog for certain types
- (NSString *) openDialogForType:(int)type
{
    NSArray *typeList = [self getExtensionsForType:type];
	NSOpenPanel *thePanel = [NSOpenPanel openPanel];
	NSString *theFile = nil;
	NSString *defDir;
	
	if (!(defDir = [[self preferences] objectForKey:@"DefaultDirectory"]))
		defDir = NSHomeDirectory();

    [thePanel setAllowsMultipleSelection:NO];
	
	// show additional options based on type
	if (type == MP_DIALOG_MEDIA || type == MP_DIALOG_VIDEO) { 
		// add multithreading box and load state from preferences
		[thePanel setAccessoryView:openFileSettings];
		[openMultithreading setState:[[self preferences] boolForKey:@"UseFFmpegMT"]];
	} else if (type == MP_DIALOG_SUBTITLES) {
		// beta: add encoding dropdown and load state from preferences
		/*[thePanel setAccessoryView:openSubtitleSettings];
		if ([[self preferences] objectForKey:@"SubtitlesEncoding"]) {
			[openSubtitleEncoding selectItemWithTitle:[[self preferences] objectForKey:@"SubtitlesEncoding"]];
			if ([openSubtitleEncoding indexOfSelectedItem] < 0)
				[openSubtitleEncoding selectItemAtIndex:0];
		}
		else
			[openSubtitleEncoding selectItemAtIndex:0];*/
	}
	
    if ([thePanel runModalForDirectory:defDir file:nil types:typeList] == NSOKButton) {
        theFile = [[thePanel filenames] objectAtIndex:0];
		[[NSUserDefaults standardUserDefaults]
				setObject:[theFile stringByDeletingLastPathComponent]
				forKey:@"DefaultDirectory"];
    }
	return theFile;
}
//openfor folders
- (NSString *) openDialogForFolders:(NSArray *)typeList
{
    NSOpenPanel *thePanel = [NSOpenPanel openPanel];
	NSString *theFile = nil;
	NSString *defDir;
	
	if (!(defDir = [[self preferences] objectForKey:@"DefaultDirectory"]))
		defDir = NSHomeDirectory();

    [thePanel setAllowsMultipleSelection:NO];
	[thePanel setCanChooseDirectories : YES ];
	[thePanel setCanChooseFiles : NO ];
	
    if ([thePanel runModalForDirectory:defDir file:nil types:typeList] == NSOKButton) {
        theFile = [[thePanel filenames] objectAtIndex:0];
		[[NSUserDefaults standardUserDefaults]
				setObject:[theFile stringByDeletingLastPathComponent]
				forKey:@"DefaultDirectory"];
    }
	return theFile;
}



//beta
/*
- (NSString *) saveDialogForTypes:(NSArray *)typeList
{
    NSSavePanel *thePanel = [NSSavePanel savePanel];
	NSString *theFile = nil;
	NSString *defDir;
	
	if (!(defDir = [[self preferences] objectForKey:@"DefaultDirectory"]))
		defDir = NSHomeDirectory();

 //   [thePanel setAllowsMultipleSelection:NO];

    if ([thePanel runModalForDirectory:defDir file:nil types:typeList] == NSOKButton) {
        theFile = [[thePanel filenames] objectAtIndex:0];
		[[NSUserDefaults standardUserDefaults]
				setObject:[theFile stringByDeletingLastPathComponent]
				forKey:@"DefaultDirectory"];
    }
	return theFile;
}
*/


// update custom aspect in aspect menu
- (void) updateAspectMenu
{
	float customAspect = [[self preferences] floatForKey:@"CustomVideoAspectValue"];
	if (customAspect == 0) {
		[customAspectMenuItem setEnabled:NO];
		[customAspectMenuItem setTitle:@"Custom"];
	} else {
		[customAspectMenuItem setEnabled:YES];
		[customAspectMenuItem setTitle:[[self preferences] stringForKey:@"CustomVideoAspect"]];
	}
}


// animate interface transitions
- (BOOL) animateInterface
{
	if ([[self preferences] objectForKey:@"AnimateInterfaceTransitions"])
		return [[self preferences] boolForKey:@"AnimateInterfaceTransitions"];
	else
		return YES;
}


/************************************************************************************
 DELEGATE METHODS
 ************************************************************************************/
// app delegate method
// executes when file is double clicked or dropped on apps icon
// immediatlely starts to play dropped file without adding it to the playlist
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	if (filename) {
		// create an item from it and play it
		if ([self isExtension:[filename pathExtension] ofType:MP_DIALOG_MEDIA]) {
			NSMutableDictionary *myItem = [NSMutableDictionary
										   dictionaryWithObject:filename forKey:@"MovieFile"];
			[playerController playItem:myItem];
		// load subtitles while playing
		} else if ([playerController isPlaying]
				   && [self isExtension:[filename pathExtension] ofType:MP_DIALOG_SUBTITLES]) {
			NSMutableDictionary *myItem = [NSMutableDictionary
										   dictionaryWithObject:filename forKey:@"SubtitlesFile"];
			[playerController playItem:myItem];
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
			[theApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		else
			[theApp replyToOpenOrPrint:NSApplicationDelegateReplyFailure];
		return;
	}
	
	NSEnumerator *e = [filenames objectEnumerator];
	NSString *filename;
	
	[playListController openWindow:YES];
	
	// add files to playlist
	while (filename = [e nextObject]) {
		// Only add movie files
		if ([self isExtension:[filename pathExtension] ofType:MP_DIALOG_MEDIA]) {
			NSMutableDictionary *myItem = [NSMutableDictionary
										   dictionaryWithObject:filename forKey:@"MovieFile"];
			[playListController appendItem:myItem];
		}
	}
	
	[sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}
/************************************************************************************/
- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	
	NSMutableDictionary *myItem = [NSMutableDictionary
								   dictionaryWithObject:url forKey:@"MovieFile"];
	[playerController playItem:myItem];
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
	
	// Release language code mappings
	[LanguageCodes releaseCodes];
	
	return NSTerminateNow;
}

/******************************************************************************/
// only enable openSubtitle menu item when mplayer is playing 
- (BOOL) validateMenuItem:(NSMenuItem *)aMenuItem
{
	if ([aMenuItem action] == @selector(openSubtitle:))
		return [playerController isPlaying];
	return YES;
}
/******************************************************************************/
- (void) appFinishedLaunching
{
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"Version"]) {
		[preferencesController reloadValues];
		[preferencesController applyPrefs:nil];
	}
	
	// set sparkle feed url for prereleases
	if ([[self preferences] boolForKey:@"CheckForPrereleases"]) {
		NSString *feed = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"SUPrereleaseFeedURL"];
		if (feed)
			[[SUUpdater sharedUpdater] setFeedURL:[NSURL URLWithString:feed]];
		else
			[Debug log:ASL_LEVEL_ERR withMessage:@"No feed URL found for prereleases."];
	}
}

@end
