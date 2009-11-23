/*
 *  AppController.h
 *  MPlayer OS X
 *
 *	Description:
 *		AppController handles application specific events and notifications, it is
 *	NSApp delegate, it provides MainBundle access
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import <Cocoa/Cocoa.h>
#import <asl.h>

#define MP_DIALOG_MEDIA		0
#define MP_DIALOG_AUDIO		1
#define MP_DIALOG_VIDEO		2
#define MP_DIALOG_SUBTITLES 3

@class AppleRemote, PlayerController, PreferencesController2;

@interface AppController : NSObject
{
    // controller outlets
	IBOutlet PlayerController *playerController;
	IBOutlet id playListController;
		
	// GUI outlets
	IBOutlet id locationPanel;
	IBOutlet id locationBox;
	
	IBOutlet id video_tsPanel;
	IBOutlet id video_tsBox;
	IBOutlet id video_tsbutton;
	
	IBOutlet id closeMenuItem;
	IBOutlet id playerWindow;
	IBOutlet NSMenu *aspectMenu;
	IBOutlet NSMenuItem *customAspectMenuItem;
	
	IBOutlet NSView *openFileSettings;
	IBOutlet id openMultithreading;
	
	IBOutlet NSView *openSubtitleSettings;
	IBOutlet NSPopUpButton *openSubtitleEncoding;
	
	// other outlets
	IBOutlet id theApp;
	
	// open dialog
	NSOpenPanel *openPanel;
	
	// apple remote support
	AppleRemote *appleRemote;
	
	// Preferences
	IBOutlet PreferencesController2 *preferencesController;
	NSDictionary *preferencesSpecs;
}

@property (readonly) PlayerController *playerController;
@property (readonly) NSMenu *aspectMenu;

+ (AppController *) sharedController;

// app's interface
- (NSUserDefaults *) preferences;
- (NSArray *) preferencesRequiringRestart;
- (IBAction) openPreferences:(id)sender;
- (IBAction) openCustomAspectRatioChooser:(id)sender;
- (IBAction) chooseCustomAspectRatio:(NSButton *)sender;

- (void) quitApp;
	
// actions
- (IBAction) openFile:(id)sender;
- (IBAction) addToPlaylist:(id)sender;
- (IBAction) openLocation:(id)sender;
- (IBAction) openSubtitle:(id)sender;
- (IBAction) showFilesChanged:(NSPopUpButton*)sender;

- (IBAction) openVIDEO_TS:(id)sender;
- (IBAction) cancelVIDEO_TSLocation:(id)sender;
- (IBAction) applyVIDEO_TSLocation:(id)sender;
- (IBAction) displayPlayList:(id)sender;
- (IBAction) displayLogWindow:(id)sender;
- (IBAction) applyLocation:(id)sender;
- (IBAction) cancelLocation:(id)sender;
- (IBAction) openHomepage:(id)sender;
- (IBAction) openLicenseAndCredits:(id)sender;
- (IBAction) closeWindow:(id)sender;

// bundle access
- (NSArray *) getExtensionsForType:(int)type;
- (NSArray *) typeExtensionsForName:(NSString *)typeName;
- (BOOL) isExtension:(NSString *)theExt ofType:(int)type;

// misc methods
- (NSString *) openDialogForType:(int)type;
- (BOOL) animateInterface;
- (void) setSparkleFeed;

//beta
//- (NSString *) saveDialogForTypes:(NSArray *)typeList;
- (NSString *) openDialogForFolders:(NSArray *)typeList;


// delegate methods
- (void) applicationDidBecomeActive:(NSNotification *)aNotification;
- (void) applicationDidResignActive:(NSNotification *)aNotification;
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename;
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
- (BOOL) validateMenuItem:(NSMenuItem *)aMenuItem;
- (void) appFinishedLaunching;
- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;

@end
