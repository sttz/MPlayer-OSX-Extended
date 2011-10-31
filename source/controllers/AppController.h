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

extern NSString* const MPENewPlayerOpenedNotification;
extern NSString* const MPEPlayerClosedNotification;
extern NSString* const MPEPlayerNotificationPlayerControllerKey;
extern NSString* const MPEPlayerStoppedNotification;

@class AppleRemote, PlayerController, PreferencesController2, EqualizerController,
PlayListController, MenuController, InspectorController, MovieInfo, SPMediaKeyTap;

@protocol MovieInfoProvider;

@interface AppController : NSObject <NSOpenSavePanelDelegate>
{
    // controller outlets
	IBOutlet MenuController *menuController;
	IBOutlet EqualizerController *equalizerController;
	IBOutlet InspectorController *inspectorController;
	
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
    IBOutlet NSPopUpButton *openFileTypeMenu;
	
	IBOutlet NSView *openSubtitleSettings;
	IBOutlet NSPopUpButton *openSubtitleEncoding;
	
	// open dialog
	NSOpenPanel *openPanel;
	
	// apple remote support
	AppleRemote *appleRemote;
	
	// Preferences
	IBOutlet PreferencesController2 *preferencesController;
	NSDictionary *preferencesSpecs;
	
	// Player controllers
	NSMutableArray *players;
	PlayerController *activePlayer;
	
	id<MovieInfoProvider> movieInfoProvider;
	SPMediaKeyTap *keyTap; // For media keys;
}

@property (nonatomic,readonly) MenuController *menuController;
@property (nonatomic,readonly) PreferencesController2 *preferencesController;
@property (nonatomic,readonly) InspectorController *inspectorController;
- (EqualizerController *)equalizerController;

@property (nonatomic,readonly) NSArray *players;

@property (readonly) NSMenu *aspectMenu;

@property (nonatomic,retain) id<MovieInfoProvider> movieInfoProvider;

+ (AppController *) sharedController;
+ (NSString *) userApplicationSupportDirectoryPath;

// app's interface
- (NSUserDefaults *) preferences;
- (NSArray *) preferencesRequiringRestart;

- (NSUInteger) registerPlayer:(PlayerController *)player;
- (void) removePlayer:(PlayerController *)player;
- (PlayerController *) getPlayer;
- (void) openNewPlayerWindow:(id)sender;
- (void) playerDidBecomeActivePlayer:(PlayerController *)player;
- (void) playerResignedActivePlayer:(PlayerController *)player;

@property (nonatomic,readonly) PlayerController *activePlayer;

- (BOOL) changesRequireRestart;
- (void) applyChangesWithRestart:(BOOL)restart;

- (void) restart;

- (void) openFilePath:(NSString*)filepath;
// actions
- (IBAction) openFile:(id)sender;
- (IBAction) addToPlaylist:(id)sender;
- (IBAction) openLocation:(id)sender;
- (IBAction) openSubtitle:(id)sender;
- (IBAction) showFilesChanged:(NSPopUpButton*)sender;

- (IBAction) openVIDEO_TS:(id)sender;
- (IBAction) cancelVIDEO_TSLocation:(id)sender;
- (IBAction) applyVIDEO_TSLocation:(id)sender;
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
- (BOOL) isDVD:(NSString *)path;

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
- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;

@end
