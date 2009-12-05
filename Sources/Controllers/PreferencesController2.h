/*  
 *  PreferencesController2.h
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

@class SUUpdater, BinaryBundle;

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
	
	NSMutableDictionary *binaryBundles;
	NSMutableDictionary *binaryInfo;
	NSMutableDictionary *binaryUpdaters;
	IBOutlet NSTableView *binariesTable;
	IBOutlet NSButton *binaryUpdateCheckbox;
	IBOutlet NSDictionaryController *binariesController;
	
	IBOutlet NSView *binaryInstallOptions;
	IBOutlet NSButton *binaryInstallUpdatesCheckbox;
	IBOutlet NSButton *binaryInstallDefaultCheckbox;
	
	IBOutlet NSView *binarySelectionView;
	IBOutlet NSPopUpButton *binarySelectionPopUp;
}

@property (retain) NSMutableDictionary *fonts;
@property (retain) NSMutableDictionary *binaryInfo;
@property (readonly) NSWindow *customAspectRatioChooser;
@property (readonly) NSDictionaryController *binariesController;

- (IBAction) switchView:(NSToolbarItem*)sender;
- (void) loadView:(NSString*)viewName;

- (void) scanBinaries;
- (void) loadBinariesFromDirectory:(NSString *)path;
- (void) unloadBinary:(NSString *)identifier withUpdater:(BOOL)updater;
- (SUUpdater *)createUpdaterForBundle:(NSBundle *)bundle whichUpdatesAutomatically:(BOOL)autoupdate;
- (NSComparisonResult) compareBinaryVersion:(NSDictionary *)b1 toBinary:(NSDictionary*)b2;
- (BOOL) binaryHasRequiredMinVersion:(NSDictionary *)bundle;
- (BOOL) binaryHasCompatibleArch:(BinaryBundle *)bundle;
- (void) installBinary:(NSString *)path;
- (NSString *) identifierForBinaryName:(NSString *)name;
- (NSString *) pathForBinaryWithIdentifier:(NSString *)identifier;

- (IBAction) requireRestart:(id)sender;
- (IBAction) restartPlayback:(id)sender;

- (IBAction) selectNewScreenshotPath:(NSPopUpButton *)sender;

- (void) loadFonts;
- (IBAction) changeFont:(NSPopUpButton *)sender;

- (IBAction) chooseCustomAspectRatio:(NSButton *)sender;

+ (float) parseAspectRatio:(NSString *)aspectString;

- (NSView *) binarySelectionView;
- (NSString *) identifierFromSelectionInView;

- (IBAction) selectBinary:(id)sender;
- (IBAction) visitBinaryHomepage:(id)sender;
- (IBAction) setChecksForUpdates:(NSButton *)sender;
- (IBAction) checkForUpdates:(id)sender;

@end


@interface ENCACodeTransformer : NSValueTransformer {
	NSDictionary *codes;
}
@end

@interface AspectRatioTransformer : NSValueTransformer { }
@end

@interface IsSelectedBinaryTransformer : NSValueTransformer { }
@end

@interface IsNotSelectedBinaryTransformer : IsSelectedBinaryTransformer { }
@end

@interface OnlyValidBinariesTransformer : NSValueTransformer { }
@end

@interface AspectRatioFormatter : NSFormatter { }
@end