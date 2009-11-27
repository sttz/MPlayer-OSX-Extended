/*  
 *  PreferencesController2.m
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

#import "PreferencesController2.h"

#import "AppController.h"
#import "PlayerController.h"

#import "Debug.h"
#import "Preferences.h"

#import <fontconfig/fontconfig.h>
#import "RegexKitLite.h"
#import <Sparkle/Sparkle.h>

// regex for parsing aspect ratio
#define ASPECT_REGEX	@"^(\\d+\\.?\\d*|\\.\\d+)(?:\\:(\\d+\\.?\\d*|\\.\\d+))?$"

static NSDictionary const *architectures;

@implementation PreferencesController2
@synthesize fonts, customAspectRatioChooser, binaryInfo, binariesController;

- (void) awakeFromNib
{
	if (!architectures) {
		architectures = [[NSDictionary alloc] initWithObjectsAndKeys:
						 @"ppc",   [NSNumber numberWithInt:NSBundleExecutableArchitecturePPC],
						 @"ppc64", [NSNumber numberWithInt:NSBundleExecutableArchitecturePPC64],
						 @"i386",  [NSNumber numberWithInt:NSBundleExecutableArchitectureI386],
						 @"x86_64",[NSNumber numberWithInt:NSBundleExecutableArchitectureX86_64],
						 nil];
	}
	
	views = [[NSDictionary alloc] initWithObjectsAndKeys:
			 generalView,	@"General",
			 displayView,	@"Display",
			 textView,		@"Text",
			 audioView,		@"Audio",
			 videoView,		@"Video",
			 mplayerView,	@"MPlayer",
			 advancedView,	@"Advanced",
			 nil];
	
	if ([PREFS objectForKey:@"MPESelectedPreferencesSection"])
		[self loadView:[PREFS stringForKey:@"MPESelectedPreferencesSection"]];
	else
		[self loadView:@"General"];
	
	// Set autosave name here to avoid window loading the frame with an unitialized view
	[self setWindowFrameAutosaveName:@"MPEPreferencesWindow"];
	
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES]; 
	
	screenshotSavePathLastSelection = [PREFS integerForKey:MPECustomScreenshotsSavePath];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(loadFonts)
												 name:NSApplicationDidFinishLaunchingNotification
											   object:NSApp];
	
	[binariesController addObserver:self
						 forKeyPath:@"selection"
							options:NSKeyValueObservingOptionInitial
							context:nil];
	
	[binariesTable setTarget:self];
	[binariesTable setDoubleAction:@selector(selectBinary:)];
	
	[self scanBinaries];
	
	// reset selected binary if it can't be found or is not compatible
	NSDictionary *selectedBinary = [binaryInfo objectForKey:[PREFS objectForKey:MPESelectedBinary]];
	if (!selectedBinary || ![self binaryHasRequiredMinVersion:selectedBinary]) {
		[Debug log:ASL_LEVEL_WARNING withMessage:@"Reset to default binary (selected binary either not found or not compatible)."];
		[PREFS removeObjectForKey:MPESelectedBinary];
	}
}

- (void) dealloc
{
	[views release];
	[currentViewName release];
	[fonts release];
	[binaryBundles release];
	[binaryInfo release];
	[binaryUpdaters release];
	
	[super dealloc];
}

- (IBAction) switchView:(NSToolbarItem*)sender
{
	[self loadView:[sender itemIdentifier]];
}

- (void) loadView:(NSString*)viewName
{
	NSView *newView = [views objectForKey:viewName];
	
	if (!newView)
		return;
	
	if (currentViewName != viewName)
		[[views objectForKey:currentViewName] removeFromSuperview];
	
	[currentViewName release];
	currentViewName = [viewName retain];
	
	[[[self window] toolbar] setSelectedItemIdentifier:viewName];
	
	NSRect contentFrame = [newView frame];
	
	if ([restartView superview])
		contentFrame.size.height += [restartView frame].size.height;
	
	NSRect viewFrame = [newView frame];
	if (![newView superview] && [restartView superview])
		viewFrame.origin.y = [restartView frame].size.height;
	else if (![newView superview])
		viewFrame.origin.y = 0;
	[newView setFrame:viewFrame];
	
	NSRect newWindowFrame = [[self window] frameRectForContentRect:contentFrame];
    newWindowFrame.origin = [[self window] frame].origin;
    newWindowFrame.origin.y -= newWindowFrame.size.height - [[self window] frame].size.height;
	
	[[self window] setFrame:newWindowFrame display:YES animate:YES];
	
	[[self window] setTitle:[NSString stringWithFormat:@"Preferences - %@",viewName]];
	
	[[[self window] contentView] addSubview:newView];
	
	[[NSUserDefaults standardUserDefaults] setObject:viewName forKey:@"MPESelectedPreferencesSection"];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	NSArray *items = [toolbar items];
	NSMutableArray *idents = [NSMutableArray arrayWithCapacity:[items count]];
	
	for (NSToolbarItem *item in items) {
		[idents addObject:[item itemIdentifier]];
	}
	
	return idents;
}

- (IBAction) checkForUpdates:(id)sender
{
	NSDictionary *info = [[[binariesController selectedObjects] objectAtIndex:0] value];
	SUUpdater *updater = [binaryUpdaters objectForKey:[info objectForKey:@"CFBundleIdentifier"]];
	
	if (!updater)
		updater = [self createUpdaterForBundle:[binaryBundles objectForKey:[info objectForKey:@"CFBundleIdentifier"]]
					 whichUpdatesAutomatically:NO];
	
	[updater checkForUpdates:sender];
}

- (IBAction) requireRestart:(id)sender
{
	BOOL restart = [[[AppController sharedController] playerController] changesRequireRestart];
	
	if (restart	&& !restartIsRequired) {
		[[[self window] contentView] addSubview:restartView];
		[self loadView:currentViewName];
		
	} else if (!restart && restartIsRequired) {
		[restartView removeFromSuperview];
		[self loadView:currentViewName];
	}
	
	restartIsRequired = restart;
}

- (IBAction) restartPlayback:(id)sender
{
	[restartView removeFromSuperview];
	[self loadView:currentViewName];
	
	[[[AppController sharedController] playerController] applyChangesWithRestart:YES];
	restartIsRequired = NO;
}

- (void) scanBinaries
{
	if (!binaryBundles) {
		binaryBundles  = [NSMutableDictionary new];
		binaryInfo     = [NSMutableDictionary new]; 
		binaryUpdaters = [NSMutableDictionary new];
	}
	
	NSString *binPath;
	
	NSArray *results = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
														   NSUserDomainMask, YES);
	
	if ([results count] > 0) {
		binPath = [[results objectAtIndex:0] stringByAppendingPathComponent:@"MPlayer OSX Extended/Binaries"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:binPath])
			[self loadBinariesFromDirectory:binPath];
	}
	
	binPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Binaries"];
	[self loadBinariesFromDirectory:binPath];
	
	[self setBinaryInfo:binaryInfo];
}

- (void) loadBinariesFromDirectory:(NSString *)path
{
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
	
	if (!files || [files count] == 0) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to load binaries from path: %@",path];
		return;
	}
	
	for (NSString *file in files) {
		if ([[file pathExtension] isEqualToString:@"mpBinaries"]) {
			
			NSString *bundlePath = [path stringByAppendingPathComponent:file];
			NSBundle *binary = [[[NSBundle alloc] initWithPath:bundlePath] autorelease];
			
			if (!binary) {
				[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to load bundle at path: %@",path];
				return;
			}
			
			NSString *bundleIdentifier = [binary bundleIdentifier];
			
			if ([binaryBundles objectForKey:bundleIdentifier])
				return;
			
			NSMutableDictionary *info = [[[binary infoDictionary] mutableCopy] autorelease];
			NSMutableArray *archs = [[[binary executableArchitectures] mutableCopy] autorelease];
			
			NSUInteger i;
			for (i=0; i < [archs count]; i++) {
				if ([architectures objectForKey:[archs objectAtIndex:i]])
					[archs replaceObjectAtIndex:i withObject:[architectures objectForKey:[archs objectAtIndex:i]]];
			}
			
			[info setObject:archs forKey:@"MPEBinaryArchs"];
			[info setObject:[archs componentsJoinedByString:@", "] forKey:@"MPEBinaryArchsString"];
			
			BOOL isCompatible = [self binaryHasRequiredMinVersion:info];
			[info setObject:[NSNumber numberWithBool:isCompatible] forKey:@"MPEBinaryIsCompatible"];
			if (!isCompatible) {
				[info setObject:[NSString stringWithFormat:@"Version not compatible: %@",
								 [info objectForKey:@"CFBundleShortVersionString"]]
						 forKey:@"CFBundleShortVersionString"];
				[info setObject:[NSColor redColor] forKey:@"MPEVersionStringTextColor"];
			}
			
			if ([PREFS boolForKey:@"SUEnableAutomaticChecks"] && [info objectForKey:@"SUFeedURL"]
				&& [[PREFS arrayForKey:MPEUpdateBinaries] containsObject:bundleIdentifier])
				[self createUpdaterForBundle:binary whichUpdatesAutomatically:YES];
			
			[Debug log:ASL_LEVEL_INFO withMessage:@"Found binary %@ in %@",
			 file,[[path stringByDeletingLastPathComponent] lastPathComponent]];
			[binaryBundles setValue:binary forKey:bundleIdentifier];
			[binaryInfo setValue:info forKey:bundleIdentifier];
		}
	}
}

- (BOOL) binaryHasRequiredMinVersion:(NSDictionary *)info
{
	int minRev = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"MPEBinaryMinRevision"] intValue];
	int bundleRev = [[info objectForKey:@"MPEBinarySVNRevisionEquivalent"] intValue];
	return (bundleRev >= minRev);
}

- (void) installBinary:(NSString *)path
{
	NSBundle *binary = [[[NSBundle alloc] initWithPath:path] autorelease];
	
	if (!binary || ![[binary infoDictionary] objectForKey:@"MPEBinarySVNRevisionEquivalent"]) {
		NSRunAlertPanel(@"Binary Installation Error", 
						[NSString stringWithFormat:@"The MPlayer binary '%@' couldn't be recognized.",
							[path lastPathComponent]], 
						 @"OK", nil, nil);
		return;
	}
	
	NSDictionary *info = [binary infoDictionary];
	NSString *identifier = [info objectForKey:@"CFBundleIdentifier"];
	
	if (![self binaryHasRequiredMinVersion:info]) {
		NSRunAlertPanel(@"Binary Installation Error", 
						[NSString stringWithFormat:@"The MPlayer binary '%@' is not compatible with this %@ version (at least r%d required).",
						 [path lastPathComponent],
						 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
						 [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"MPEBinaryMinRevision"] intValue]], 
						@"OK", nil, nil);
		return;
	}
	
	if ([binaryBundles objectForKey:identifier]) {
		
		NSString *installedVersion = [[binaryInfo objectForKey:identifier] objectForKey:@"CFBundleVersion"];
		NSString *newVersion = [info objectForKey:@"CFBundleVersion"];
		NSComparisonResult result = [installedVersion compare:newVersion options:NSNumericSearch];
		
		if (result == NSOrderedSame) {
			
			if (NSRunAlertPanel(@"Binary Already Installed", 
				[NSString stringWithFormat:
				 @"The MPlayer binary '%@' is already installed (version %@). Do you want to install it again?",
				 [info objectForKey:@"CFBundleName"],
				 [info objectForKey:@"CFBundleShortVersionString"]],
				 @"Cancel", @"Reinstall", nil) == NSAlertDefaultReturn) return;
			
		} else if (result == NSOrderedAscending) {
			
			if (NSRunAlertPanel(@"Upgrade Binary", 
				[NSString stringWithFormat:
				 @"Do you want to upgrade the MPlayer binary '%@' from version %@ to %@?",
				 [info objectForKey:@"CFBundleName"],
				 [[binaryInfo objectForKey:identifier] objectForKey:@"CFBundleShortVersionString"],
				 [info objectForKey:@"CFBundleShortVersionString"]],
				 @"Upgrade", @"Cancel", nil) == NSAlertAlternateReturn) return;
			
		} else {
			
			if (NSRunAlertPanel(@"Downgrade Binary", 
				[NSString stringWithFormat:
				 @"A newer version of the MPlayer binary '%@' is already installed. Do you want to downgrade from version %@ to %@?",
				 [info objectForKey:@"CFBundleName"],
				 [[binaryInfo objectForKey:identifier] objectForKey:@"CFBundleShortVersionString"],
				 [info objectForKey:@"CFBundleShortVersionString"]],
				 @"Cancel", @"Downgrade", nil) == NSAlertDefaultReturn) return;
			
		}
		
	} else {
		
		NSAlert *alert = [NSAlert alertWithMessageText:@"Install Binary"
										 defaultButton:@"Install"
									   alternateButton:@"Cancel"
										   otherButton:nil
							 informativeTextWithFormat:@"Do you want to install the MPlayer binary '%@'?",
														[info objectForKey:@"CFBundleName"]];
		[alert setAccessoryView:binaryInstallOptions];
		[binaryInstallUpdatesCheckbox setHidden:(![info objectForKey:@"SUFeedURL"])];
		
		[binaryInstallUpdatesCheckbox setState:NSOnState];
		[binaryInstallDefaultCheckbox setState:NSOnState];
		
		if ([alert runModal] != NSAlertDefaultReturn)
			return;
	}
	
	NSArray *results = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
														   NSUserDomainMask,
														   YES);
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *installPath = [[results objectAtIndex:0] 
							 stringByAppendingPathComponent:@"MPlayer OSX Extended/Binaries"];
	
	if (![fm fileExistsAtPath:installPath]) {
		NSError *error;
		if (![fm createDirectoryAtPath:installPath
		   withIntermediateDirectories:YES 
							attributes:nil 
								 error:&error]) {
			[Debug log:ASL_LEVEL_ERR withMessage:@"Couldn't create directory at path: %@, Error: %@",installPath,[error localizedDescription]];
			return;
		}
	}
	
	installPath = [installPath stringByAppendingPathComponent:[path lastPathComponent]];
	
	NSError *error;
	if (![fm moveItemAtPath:path toPath:installPath error:&error]) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Couldn't move binary to '%@', Error: %@",installPath,[error localizedDescription]];
		return;
	}
	
	if (![binaryInstallDefaultCheckbox isHidden]) {
		NSMutableArray *updates = [[[PREFS arrayForKey:MPEUpdateBinaries] mutableCopy] autorelease];
		if ([updates containsObject:identifier] && [binaryInstallUpdatesCheckbox state] == NSOffState)
			[updates removeObject:identifier];
		else if (![updates containsObject:identifier] && [binaryInstallUpdatesCheckbox state] == NSOnState)
			[updates addObject:identifier];
		[PREFS setObject:updates forKey:MPEUpdateBinaries];
	}
	
	if ([binaryInstallDefaultCheckbox state] == NSOnState)
		[PREFS setObject:identifier forKey:MPESelectedBinary];
	
	[self scanBinaries];
	
	[[self window] makeKeyAndOrderFront:nil];
	[self loadView:@"MPlayer"];
}

- (NSString *) identifierForBinaryName:(NSString *)name
{
	for (NSString *key in binaryInfo) {
		if ([name isEqualToString:[[binaryInfo objectForKey:key] objectForKey:@"CFBundleName"]])
			return key;
	}
	return nil;
}

- (NSString *) pathForBinaryWithIdentifier:(NSString *)identifier
{
	if (![binaryBundles objectForKey:identifier]) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Binary not found for identifier: %@",identifier];
		return nil;
	}
	
	return [[binaryBundles objectForKey:identifier] executablePath];
}

- (SUUpdater *)createUpdaterForBundle:(NSBundle *)bundle whichUpdatesAutomatically:(BOOL)autoupdate
{
	SUUpdater *updater = [SUUpdater updaterForBundle:bundle];
	
	[updater setAutomaticallyChecksForUpdates:autoupdate];
	[updater setNeedsRelaunchAfterInstall:NO];
	[updater setDelegate:self];
	
	[binaryUpdaters setObject:updater forKey:[bundle bundleIdentifier]];
	
	return updater;
}

- (void)updater:(SUUpdater *)updater hasFinishedInstallforUdpate:(SUAppcastItem *)update
{
	NSString *identifier = [[binaryUpdaters allKeysForObject:updater] objectAtIndex:0];
	
	[binaryInfo removeObjectForKey:identifier];
	[binaryBundles removeObjectForKey:identifier];
	
	[self scanBinaries];
}

- (IBAction) selectNewScreenshotPath:(NSPopUpButton *)sender
{
	if ([sender selectedTag] != -1) {
		screenshotSavePathLastSelection = [sender selectedTag];
		return;
	}
	
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	
	NSString *oldPath = [prefs objectForKey:MPECustomScreenshotsSavePath];
	
	if ([panel runModalForDirectory:oldPath file:nil types:nil] == NSOKButton) {
		[prefs setObject:[[panel filenames] objectAtIndex:0] 
				  forKey:MPECustomScreenshotsSavePath];
		[sender selectItemWithTag:MPEScreenshotSaveLocationCustom];
    } else {
		[sender selectItemWithTag:screenshotSavePathLastSelection];
	}
	
	[self requireRestart:sender];
}

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
	[fullscreenSelectionMatrix selectCellWithTag:1];
	
	return YES;
}

- (void)loadFonts
{
	FcConfig *config;
	FcPattern *pat;
	FcFontSet *set;
	FcObjectSet *os;
	
	// Initialize fontconfig with own config directory
	setenv("FONTCONFIG_PATH", [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"fonts"] UTF8String], 1);
	
	config = FcInitLoadConfig();
	if (!config)
		return [Debug log:ASL_LEVEL_ERR withMessage:@"Failed to initialize Fontconfig."];
	FcConfigSetCurrent(config);
	
	// Check if the cache needs to be rebuilt
	FcStrList *fontDirs = FcConfigGetFontDirs(config);
	FcChar8 *fontDir;
	FcBool cachesAreValid = FcTrue;
	while (fontDir = FcStrListNext(fontDirs)) {
		cachesAreValid = (FcDirCacheValid(fontDir) || !FcFileIsDir(fontDir)) && cachesAreValid;
	}
	
	// Display rebuilding dialog while Fontconfig is working
	if (!cachesAreValid) {
		[cacheStatusIndicator setUsesThreadedAnimation:YES];
		[cacheStatusIndicator startAnimation:self];
		[NSApp beginSheet:cacheStatusWindow
		   modalForWindow:[[[AppController sharedController] playerController] playerWindow] 
			modalDelegate:nil 
		   didEndSelector:nil 
			  contextInfo:nil];
	}
	
	if (!FcConfigBuildFonts(config)) {
		FcConfigDestroy(config);
		return [Debug log:ASL_LEVEL_ERR withMessage:@"Failed to build Fontconfig cache."];
	}
	
	if (!cachesAreValid) {
		[NSApp endSheet:cacheStatusWindow];
		[cacheStatusWindow orderOut:self];
	}
	
	// Create pattern for all fonts and include family and style information
	pat = FcPatternCreate();
	os = FcObjectSetBuild(FC_FAMILY, FC_STYLE, (char *) 0);
	set = FcFontList(0, pat, os);
	
	FcObjectSetDestroy(os);
	FcPatternDestroy(pat);
	
	// Read fonts into dictionary
	if (set) {
		NSMutableDictionary *mfonts = [[NSMutableDictionary dictionaryWithCapacity:set->nfont] retain];
		
		int i;
		for (i = 0; i < set->nfont; i++) {
			
			FcChar8 *family;
			FcChar8 *fontstyle;
			NSMutableArray *styles;
			
			if (FcPatternGetString(set->fonts[i], FC_FAMILY, 0, &family) == FcResultMatch) {
				
				// For now just take the 0th family and style name, which should be the english one
				if (![mfonts objectForKey:[NSString stringWithUTF8String:(const char*)family]]) {
					styles = [NSMutableArray arrayWithCapacity:1];
					[mfonts setObject:styles	forKey:[NSString stringWithUTF8String:(const char*)family]];
				} else {
					styles = [mfonts objectForKey:[NSString stringWithUTF8String:(const char*)family]];
				}
				
				if (FcPatternGetString(set->fonts[i], FC_STYLE, 0, &fontstyle) == FcResultMatch)
					[styles addObject:[NSString stringWithUTF8String:(const char*)fontstyle]];
			}
			
		}
		
		for (NSString *key in mfonts) {
			[[mfonts objectForKey:key] sortUsingSelector:@selector(caseInsensitiveCompare:)];
		}
		
		[self setFonts:mfonts];
	} else {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to create font list."];
	}
	
	// Load font selection
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSString *defaultFont;
	if ([prefs objectForKey:MPEFont])
		defaultFont = [prefs stringForKey:MPEFont];
	else
		defaultFont = @"Helvetica";
	
	[fontsController setSelectionIndex:[fontsMenu indexOfItemWithTitle:defaultFont]];
	
	FcFontSetDestroy(set);
	FcFini();
}

- (IBAction) changeFont:(NSPopUpButton *)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[sender titleOfSelectedItem] forKey:MPEFont];
	
	[self requireRestart:sender];
}

- (IBAction) selectBinary:(id)sender
{
	if (sender == binariesTable && [binariesTable clickedRow] < 0)
		return;
	
	NSDictionary *info = [[[binariesController selectedObjects] objectAtIndex:0] value];
	
	if (![[PREFS stringForKey:MPESelectedBinary] 
		  isEqualToString:[info objectForKey:@"CFBundleIdentifier"]]
		&& [self binaryHasRequiredMinVersion:info]) {
		
		[PREFS setObject:[info objectForKey:@"CFBundleIdentifier"] forKey:MPESelectedBinary];
		
		[self setBinaryInfo:binaryInfo];
		
		[self requireRestart:sender];
	}
}

- (IBAction) visitBinaryHomepage:(id)sender
{
	NSDictionary *info = [[[binariesController selectedObjects] objectAtIndex:0] value];
	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[info objectForKey:@"MPEBinaryHomepage"]]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"selection"]) {
		NSArray *selection = [binariesController selectedObjects];
		BOOL state;
		if ([selection count] > 0) {
			NSDictionary *info = [[selection objectAtIndex:0] value];
			NSString *identifier = [info objectForKey:@"CFBundleIdentifier"];
			state = [[PREFS arrayForKey:MPEUpdateBinaries] containsObject:identifier];
		}
		[binaryUpdateCheckbox setState:state];
	}
}

- (IBAction) setChecksForUpdates:(NSButton *)sender
{
	NSDictionary *info = [[[binariesController selectedObjects] objectAtIndex:0] value];
	NSString *identifier = [info objectForKey:@"CFBundleIdentifier"];
	
	NSArray *updates = [PREFS arrayForKey:MPEUpdateBinaries];
	NSMutableArray *newUpdates;
	
	if ([sender state] == NSOnState && ![updates containsObject:identifier]) {
		newUpdates = [[updates mutableCopy] autorelease];
		[newUpdates addObject:identifier];
	} else if ([sender state] == NSOffState && [updates containsObject:identifier]) {
		newUpdates = [[updates mutableCopy] autorelease];
		[newUpdates removeObject:identifier];
	}
	
	if (newUpdates)
		[PREFS setObject:newUpdates forKey:MPEUpdateBinaries];
}

- (NSView *) binarySelectionView
{
	[binarySelectionPopUp selectItemWithTag:-1];
	return binarySelectionView;
}

- (NSString *) identifierFromSelectionInView
{
	if ([binarySelectionPopUp selectedTag] > -1)
		return [self identifierForBinaryName:[[binarySelectionPopUp selectedItem] title]];
	else
		return nil;
}

+ (float) parseAspectRatio:(NSString *)aspectString
{
	if ([aspectString length] > 0) {
		
		// Parse custom aspect ratio field (eiher "x.x or x.x:x.x)
		if ([aspectString isMatchedByRegex:ASPECT_REGEX]) {
			
			// Parts of custom aspect ratio
			NSString *part1 = [aspectString stringByMatching:ASPECT_REGEX capture:1];
			NSString *part2 = [aspectString stringByMatching:ASPECT_REGEX capture:2];
			
			float aspectValue;
			
			if (part1 && part2)				
				aspectValue = [part1 floatValue] / [part2 floatValue];
			else
				aspectValue = [part1 floatValue];
			
			return aspectValue;
		} else
			return -1;
	}
	
	return 0;
}

+ (NSColor *) unarchiveColor:(NSData *)data
{
	NSColor *aColor = nil;
	
	if (data != nil)
		aColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:data];
	
	return aColor;
}

@end


@implementation ENCACodeTransformer

+ (Class)transformedValueClass
{
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)init
{
	if ((self = [super init])) {
		codes = [[NSDictionary alloc] initWithObjectsAndKeys:
				 @"Disabled",	@"disabled",
				 @"Multibyte encodings only",@"__",
				 @"Belarussian",@"be",
				 @"Bulgarian",	@"bg",
				 @"Czech",		@"cs",
				 @"Estonian",	@"et",
				 @"Croatian",	@"hr",
				 @"Hungarian",	@"hu",
				 @"Latvian",	@"lt",
				 @"Lithuanian",	@"lv",
				 @"Polish",		@"pl",
				 @"Russian",	@"ru",
				 @"Slovak",		@"sk",
				 @"Slovene",	@"sl",
				 @"Ukrainian",	@"uk",
				 @"Chinese",	@"zh",
				 nil
				 ];
	}
	return self;
}

- (void)dealloc
{
	[codes release];
	[super dealloc];
}

- (id)transformedValue:(id)value
{
	if ([codes objectForKey:value])
		return [codes objectForKey:value];
	else
		return [codes objectForKey:@""];
}

- (id)reverseTransformedValue:(id)value
{
	NSArray *matches = [codes allKeysForObject:value];
	
	if ([matches count] > 0)
		return [[codes allKeysForObject:value] objectAtIndex:0];
	else
		return @"";
}

@end


@implementation AspectRatioFormatter

- (NSString *)stringForObjectValue:(id)anObject
{	
	if (![anObject isKindOfClass:[NSDictionary class]])
		return nil;
	
	if ([anObject objectForKey:MPECustomAspectRatioStringKey])
		return [anObject objectForKey:MPECustomAspectRatioStringKey];
	
	else if ([anObject objectForKey:MPECustomAspectRatioValueKey])
		return [NSString stringWithFormat:@"%.2f", 
				[[anObject objectForKey:MPECustomAspectRatioValueKey] floatValue]];
	
	return nil;
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
	float aspectValue = 0;
	
	if (string) {
		
		aspectValue = [PreferencesController2 parseAspectRatio:string];
		
		if (aspectValue < 0) {
			
			if (error)
				*error = @"Unrecognized aspect ratio. Please enter aspect ratios as either \
decimal values (1.33) or fractions (4:3).";
			
			return NO;
		}
		
	}
		
	if (aspectValue > 0)
		*anObject = [NSDictionary dictionaryWithObjectsAndKeys:
					 [[string copy] autorelease], MPECustomAspectRatioStringKey,
					 [NSNumber numberWithFloat:aspectValue], MPECustomAspectRatioValueKey,
					 nil];
	else
		*anObject = nil;
	
	return YES;
}
@end


@implementation AspectRatioTransformer

+ (Class)transformedValueClass
{
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue:(id)value
{
	NSString *menuTitle = value;
	
	if (!menuTitle || ![value isKindOfClass:[NSString class]])
		return @"Original";
	else if ([menuTitle isEqualToString:@"Custom"])
		return @"Custom:";
	else
		return menuTitle;
}

- (id)reverseTransformedValue:(id)value
{
	NSString *menuTitle = value;
	
	if ([menuTitle isEqualToString:@"Original"])
		return nil;
	else if ([menuTitle isEqualToString:@"Custom:"])
		return @"Custom";
	else
		return menuTitle;
}

@end

@implementation IsSelectedBinaryTransformer

+ (Class)transformedValueClass
{
	return [NSString class];
}

- (id)transformedValue:(id)value
{
	if (![value isKindOfClass:[NSString class]])
		return nil;
	
	return [NSNumber numberWithBool:[value isEqualToString:[PREFS objectForKey:MPESelectedBinary]]];
}

@end


@implementation IsNotSelectedBinaryTransformer

+ (Class)transformedValueClass
{
	return [NSString class];
}

- (id)transformedValue:(id)value
{
	NSNumber *tv = [super transformedValue:value];
	
	if (!tv)
		return nil;
	
	return [NSNumber numberWithBool:![tv boolValue]];
}

@end


@implementation OnlyValidBinariesTransformer

+ (Class)transformedValueClass
{
	return [NSString class];
}

- (id)transformedValue:(id)value
{
	if (![value isKindOfClass:[NSArray class]])
		return nil;
	
	NSMutableArray *validBinaries = [NSMutableArray array];
	PreferencesController2 *preferencesController = [[AppController sharedController] preferencesController];
	
	for (NSString *name in value) {
		NSString *identifier = [preferencesController identifierForBinaryName:name];
		if (identifier) {
			NSDictionary *info = [[preferencesController binaryInfo] objectForKey:identifier];
			if ([[info objectForKey:@"MPEBinaryIsCompatible"] boolValue])
				[validBinaries addObject:name];
		}
	}
	
	return validBinaries;
}

@end
