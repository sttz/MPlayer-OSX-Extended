/*
 *  PlayListController.h
 *  MPlayer OS X
 *
 *	Description:
 *		It's controller for playlist table, it's playlist table delegate and data source,
 *	it also takes care for loading files in to playlist and it's progress dialog. 
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import <Cocoa/Cocoa.h>

#define kDefaultTextSize		13
#define kSmallerTextSize		11

@class MovieInfo;

@interface PlayListController : NSObject
{
    // controllers outlets
	IBOutlet id playerController;
	IBOutlet id settingsController;

	// UI outlets
	IBOutlet id playListWindow;
	IBOutlet NSButton* playListButton;
	IBOutlet id playListTable;
	IBOutlet id settingsButton;
	IBOutlet id playModeButton;
	IBOutlet id playListCount;
	IBOutlet id preflightBusy;
	
	// preflight panel
	IBOutlet id preflightPanel;
	IBOutlet id filenameBox;
	IBOutlet id progressBar;
	
	// menu
	IBOutlet id playNextMenuItem;
	IBOutlet id playPreviousMenuItem;
	
    // data
	NSMutableArray *myData;
	int myPlayMode;
	
	// images
	NSImage *statusIcon;
	NSImage *playMode0Image;
	NSImage *playMode1Image;
	NSImage *playMode2Image;
	
	//toolbar
	NSMutableDictionary *toolbarItems;
	IBOutlet NSView *playerPlayToolbarView;
	IBOutlet NSView *playerStopToolbarView;
	IBOutlet NSView *playerPrevToolbarView;
	IBOutlet NSView *playerNextToolbarView;
	IBOutlet NSView *playerScrubToolbarView;
	IBOutlet NSView *playerVolumeToolbarView;
	
	NSMutableArray *preflightQueue;
}
//window 
- (IBAction)displayWindow:(id)sender;
- (IBAction)toggleWindow:(id)sender;
@property (nonatomic,readonly,getter=window) NSWindow *playListWindow;

// data access interface
- (MovieInfo *) itemAtIndex:(int) aIndex;
- (void) selectItemAtIndex:(int) aIndex;
- (MovieInfo *) selectedItem;
- (int) indexOfSelectedItem;
- (int) numberOfSelectedItems;
- (int) indexOfItem:(MovieInfo *)anItem;
- (int) itemCount;
- (void) appendItem:(MovieInfo *)anItem;
- (void) insertItem:(MovieInfo *)anItem atIndex:(int) aIndex;
- (void) deleteSelection;

// controller interface
- (void) updateView;
- (void) applyPrefs;
- (void) finishedPlayingItem:(MovieInfo *)playingItem;
- (int) getPlayMode;

// actions
- (IBAction)displayItemSettings:(id)sender;
- (IBAction)changePlayMode:(id)sender;
- (IBAction)cancelPreflight:(id)sender;
- (IBAction)playPrevious:(id)sender;
- (IBAction)playNext:(id)sender;
- (void)playItemAtIndex:(int)index;
- (void) removeItemAtIndex:(unsigned int)index;

// TableView data access methods
- (int)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pasteboard;

// delegate methods
- (BOOL) validateMenuItem:(NSMenuItem *)aMenuItem;
- (IBAction)doubleClick:(id)sender;
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row;
//- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
// notification handlers
- (void) appFinishedLaunching;
- (void) appShouldTerminate;
- (void) appTerminating;

//Required NSToolbar delegate methods
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;    
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
@end
