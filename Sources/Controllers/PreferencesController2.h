/*  
 *  LanguageCodes.m
 *  MPlayerOSX Extended
 *  
 *  Created on 05.11.2009
 *  
 *  Description:
 *	Controller for the preferences window.
 *  
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

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