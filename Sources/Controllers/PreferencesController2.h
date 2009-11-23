//
//  PreferencesController2.h
//  MPlayer OSX Extended
//
//  Created by Adrian on 05.11.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define MPE

@interface PreferencesController2 : NSWindowController {
	
	IBOutlet NSUserDefaultsController *defaultsController;
	
	NSString *currentViewName;
	
	NSDictionary *views;
	IBOutlet NSView *generalView;
	IBOutlet NSView *displayView;
	IBOutlet NSView *textView;
	IBOutlet NSView *videoView;
	IBOutlet NSView *audioView;
	IBOutlet NSView *mplayerView;
	IBOutlet NSView *advancedView;
	
	BOOL restartIsRequired;
	IBOutlet NSView *restartView;
	
	IBOutlet NSMatrix *fullscreenSelectionMatrix;
	
	NSInteger screenshotSavePathLastSelection;
	
	IBOutlet NSDictionaryController *fontsController;
	IBOutlet NSPopUpButton *fontsMenu;
	NSMutableDictionary *fonts;
	IBOutlet NSWindow *cacheStatusWindow;
	IBOutlet NSProgressIndicator *cacheStatusIndicator;
	
	IBOutlet NSWindow *customAspectRatioChooser;
}

@property (retain) NSMutableDictionary *fonts;
@property (readonly) NSWindow *customAspectRatioChooser;

- (IBAction) switchView:(NSToolbarItem*)sender;
- (void) loadView:(NSString*)viewName;

- (IBAction) requireRestart:(id)sender;
- (IBAction) restartPlayback:(id)sender;

- (IBAction) selectNewScreenshotPath:(NSPopUpButton *)sender;

- (void) loadFonts;
- (IBAction) changeFont:(NSPopUpButton *)sender;

+ (float) parseAspectRatio:(NSString *)aspectString;
+ (NSColor *) unarchiveColor:(NSData *)data;

@end


@interface ENCACodeTransformer : NSValueTransformer {
	NSDictionary *codes;
}
@end

@interface AspectRatioFormatter : NSFormatter {

}
@end