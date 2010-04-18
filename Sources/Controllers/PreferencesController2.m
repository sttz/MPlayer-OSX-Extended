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

#include <CoreAudio/CoreAudio.h>

#include <mach-o/arch.h>

#import "PreferencesController2.h"

#import "MenuController.h"
#import "AppController.h"
#import "PlayerController.h"

#import "Debug.h"
#import "Preferences.h"
#import "BinaryBundle.h"
#import "CocoaAdditions.h"

#import <fontconfig/fontconfig.h>
#import "RegexKitLite.h"
#import <Sparkle/Sparkle.h>

// regex for parsing aspect ratio
#define ASPECT_REGEX	@"^(\\d+\\.?\\d*|\\.\\d+)(?:\\:(\\d+\\.?\\d*|\\.\\d+))?$"

@implementation PreferencesController2
@synthesize fonts, outputDevices, customAspectRatioChooser, binaryInfo, binariesController;

- (void) awakeFromNib
{
	// Dictionary with all preference pane views
	views = [[NSDictionary alloc] initWithObjectsAndKeys:
			 generalView,	@"General",
			 displayView,	@"Display",
			 textView,		@"Text",
			 audioView,		@"Audio",
			 videoView,		@"Video",
			 mplayerView,	@"MPlayer",
			 advancedView,	@"Advanced",
			 nil];
	
	// Compile toobar identifiers from tags
	viewTags = [[NSDictionary alloc] initWithObjectsAndKeys:
				@"General",	@"0",
				@"Display",	@"1",
				@"Text",	@"2",
				@"Video",	@"3",
				@"Audio",	@"4",
				@"MPlayer",	@"5",
				@"Advanced",@"6",
				nil];
	
	NSMutableDictionary *idents = [NSMutableDictionary new];
	for (NSToolbarItem *item in [[[self window] toolbar] items]) {
		if ([item tag] >= 0) {
			NSString *viewName = [viewTags objectForKey:[NSString stringWithFormat:@"%d",[item tag]]];
			[idents setObject:[item itemIdentifier] 
					   forKey:viewName];
		}
	}
	identifiers = idents;
	
	// Restore selected view from preferences or default to first one
	if ([PREFS objectForKey:MPESelectedPreferencesSection])
		[self loadView:[PREFS stringForKey:MPESelectedPreferencesSection]];
	else
		[self loadView:@"General"];
	
	// Set autosave name here to avoid window loading the frame with an unitialized view
	[self setWindowFrameAutosaveName:@"MPEPreferencesWindow"];
	
	// For subtitle colors we want to be able to select alpha
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES]; 
	
	// Check if custom screenshot path exists
	if ([PREFS objectForKey:MPECustomScreenshotsSavePath] && 
			![[NSFileManager defaultManager] fileExistsAtPath:[PREFS stringForKey:MPECustomScreenshotsSavePath]]) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Screenshot save path '%@' doesn't exist anymore, using default location.",
												[PREFS stringForKey:MPECustomScreenshotsSavePath]];
		[PREFS removeObjectForKey:MPECustomScreenshotsSavePath];
		[PREFS removeObjectForKey:MPEScreenshotSaveLocation];
	}
	
	// If the user cancels out the screenshot path selection, 
	// we need this to properly reset the menu
	screenshotSavePathLastSelection = [PREFS integerForKey:MPEScreenshotSaveLocation];
	
	// Add observer for binary selection to update autoupdate checkbox
	[binariesController addObserver:self
						 forKeyPath:@"selection"
							options:NSKeyValueObservingOptionInitial
							context:nil];
	
	// Register for double-clicks on the binary table
	[binariesTable setTarget:self];
	[binariesTable setDoubleAction:@selector(selectBinary:)];
	
	[self scanBinaries];
	
	// reset selected binary if it can't be found or is not compatible
	NSString *identifier = [PREFS objectForKey:MPESelectedBinary];
	if (!identifier || ![self binaryHasRequiredMinVersion:[binaryInfo objectForKey:identifier]]
		|| ![self binaryHasCompatibleArch:[binaryBundles objectForKey:identifier]]) {
		[Debug log:ASL_LEVEL_WARNING withMessage:@"Reset to default binary (selected binary either not found or not compatible)."];
		[PREFS removeObjectForKey:MPESelectedBinary];
	}
	
	// Load audio output devices
	[self loadOutputDevices];
	
	// listen for playback restarts to recheck if the restart requirement
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(requireRestart:)
												 name:MPEPlaybackStoppedNotification
											   object:[[AppController sharedController] firstPlayerController]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(playersHaveChanged:)
												 name:MPENewPlayerOpenedNotification
											   object:[AppController sharedController]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(playersHaveChanged:)
												 name:MPEPlayerClosedNotification
											   object:[AppController sharedController]];
}

- (void) dealloc
{
	[views release];
	[currentViewName release];
	[fonts release];
	[outputDevices release];
	[binaryBundles release];
	[binaryInfo release];
	[binaryUpdaters release];
	[identifiers release];
	[viewTags release];
	
	[super dealloc];
}

- (void) playersHaveChanged:(NSNotification *)notification
{
	PlayerController *player = [[notification userInfo] objectForKey:MPEPlayerNotificationPlayerControllerKey];
	
	if ([notification name] == MPENewPlayerOpenedNotification) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(requireRestart:)
													 name:MPEPlaybackStoppedNotification
												   object:player];
	} else {
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:MPEPlaybackStoppedNotification
													  object:player];
	}
}

- (IBAction) switchView:(NSToolbarItem*)sender
{
	[self loadView:[[identifiers allKeysForObject:[sender itemIdentifier]] objectAtIndex:0]];
}

/** Switch prefences section.
 *  Load a new view corresponding to a preferences section using its name.
 */
- (void) loadView:(NSString*)viewName
{
	NSView *newView = [views objectForKey:viewName];
	
	if (!newView)
		return;
	
	if (currentViewName != viewName)
		[[views objectForKey:currentViewName] removeFromSuperview];
	
	[currentViewName release];
	currentViewName = [viewName retain];
	
	[[[self window] toolbar] setSelectedItemIdentifier:[identifiers objectForKey:viewName]];
	
	NSRect contentFrame = [newView frame];
	
	// calculate the position of the view if the restart view is visible
	if ([restartView superview])
		contentFrame.size.height += [restartView frame].size.height;
	
	NSRect viewFrame = [newView frame];
	if (![newView superview] && [restartView superview])
		viewFrame.origin.y = [restartView frame].size.height;
	else if (![newView superview])
		viewFrame.origin.y = 0;
	[newView setFrame:viewFrame];
	
	// expand the window from the top, adjust the frame accordingly
	NSRect newWindowFrame = [[self window] frameRectForContentRect:contentFrame];
    newWindowFrame.origin = [[self window] frame].origin;
    newWindowFrame.origin.y -= newWindowFrame.size.height - [[self window] frame].size.height;
	
	[[self window] setFrame:newWindowFrame display:YES animate:YES];
	
	[[self window] setTitle:[NSString stringWithFormat:@"Preferences - %@",viewName]];
	
	[[[self window] contentView] addSubview:newView];
	
	[PREFS setObject:viewName forKey:MPESelectedPreferencesSection];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	// Return all identifiers, they're always selectable
	NSArray *items = [toolbar items];
	NSMutableArray *idents = [NSMutableArray arrayWithCapacity:[items count]];
	
	for (NSToolbarItem *item in items) {
		[idents addObject:[item itemIdentifier]];
	}
	
	return idents;
}

/** Manually trigger update check for a binary.
 */
- (IBAction) checkForUpdates:(id)sender
{
	NSDictionary *info = [[[binariesController selectedObjects] objectAtIndex:0] value];
	NSString *identifier = [self updateIdentifierForBinaryWithIdentifier:[info objectForKey:@"CFBundleIdentifier"]];
	SUUpdater *updater = [binaryUpdaters objectForKey:identifier];
	
	if (!updater)
		updater = [self createUpdaterForBundle:[binaryBundles objectForKey:identifier]
					 whichUpdatesAutomatically:NO];
	
	[updater checkForUpdates:sender];
}

/** Action sent by controls that require a restart.
 *  Actually checks with the PlayerController to see if a restart is really required.
 */
- (IBAction) requireRestart:(id)sender
{
	BOOL restart = NO;
	
	for (PlayerController *player in [[AppController sharedController] players]) {
		if ([player changesRequireRestart]) {
			restart = YES;
			break;
		}
	}
	
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
	
	for (PlayerController *player in [[AppController sharedController] players]) {
		if ([player changesRequireRestart])
			[player applyChangesWithRestart:YES];
	}
	
	restartIsRequired = NO;
}

/** Scan for binaries.
 *  Scan the application and the user's library for binaries and add new found ones.
 */
- (void) scanBinaries
{
	if (!binaryBundles) {
		binaryBundles  = [NSMutableDictionary new];
		binaryInfo     = [NSMutableDictionary new]; 
		binaryUpdaters = [NSMutableDictionary new];
	}
	
	NSString *binPath = [AppController userApplicationSupportDirectoryPath];
	
	if (binPath) {
		binPath = [binPath stringByAppendingPathComponent:@"MPlayer OSX Extended/Binaries"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:binPath])
			[self loadBinariesFromDirectory:binPath];
	}
	
	// Scan the application's resource directory
	binPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Binaries"];
	[self loadBinariesFromDirectory:binPath];
	
	// Force an update of the GUI
	[self setBinaryInfo:binaryInfo];
}

/** Scan a given directory for binary bundles.
 */
- (void) loadBinariesFromDirectory:(NSString *)path
{
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
	
	if (!files || [files count] == 0) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to load binaries from path: %@",path];
		return;
	}
	
	for (NSString *file in files) {
		if ([[file pathExtension] isEqualToString:@"mpBinaries"]) {
			
			[self loadBinaryAtPath:[path stringByAppendingPathComponent:file] withParent:nil];
		}
	}
}

- (void) loadBinaryAtPath:(NSString *)path withParent:(NSString *)parentIdentifier
{
	BinaryBundle *binary = [[[BinaryBundle alloc] initWithPath:path] autorelease];
	
	if (!binary) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to load bundle at path: %@",path];
		return;
	}
	
	NSMutableDictionary *info = [[[binary infoDictionary] mutableCopy] autorelease];
	NSString *bundleIdentifier = [binary bundleIdentifier];
	
	// Consider binaries with the same identifier as same
	if ([binaryBundles objectForKey:bundleIdentifier]) {
		NSDictionary *existing = [[binaryBundles objectForKey:bundleIdentifier] infoDictionary];
		NSNumber *isCompatible = [existing objectForKey:@"MPEBinaryIsCompatible"];
		// Unload older or incompatible bundle to load new one
		if ((isCompatible && ![isCompatible boolValue])
			|| [self compareBinaryVersion:info toBinary:existing] == NSOrderedDescending) {
			[Debug log:ASL_LEVEL_ERR withMessage:@"Ignoring older or incompatible version of a bundle found at '%@'.",path];
			[self unloadBinary:bundleIdentifier withUpdater:YES];
			// A newer one is aleady loaded, skip
		} else
			return;
	}
	
	// Check for container bundles
	if ([info objectForKey:@"MPENestedBinaryBundles"]) {
		
		NSArray *nested = [info objectForKey:@"MPENestedBinaryBundles"];
		
		if (![nested isKindOfClass:[NSArray class]] || [nested count] == 0) {
			[Debug log:ASL_LEVEL_ERR withMessage:@"Invalid or empty container bundle found at '%@'.",path];
			return;
		}
		
		// Instantiate updater object if updates are enabled
		if ([PREFS boolForKey:@"SUEnableAutomaticChecks"] && [info objectForKey:@"SUFeedURL"]
			&& [[PREFS arrayForKey:MPEUpdateBinaries] containsObject:bundleIdentifier])
			[self createUpdaterForBundle:binary whichUpdatesAutomatically:YES];
		
		[Debug log:ASL_LEVEL_INFO withMessage:@"Found container bundle %@ in %@",
		 [path lastPathComponent],[[path stringByDeletingLastPathComponent] lastPathComponent]];
		[binaryBundles setValue:binary forKey:bundleIdentifier];
		
		// Load contained binaries
		for (NSString *relativePath in nested)
			[self loadBinaryAtPath:[path stringByAppendingPathComponent:relativePath] 
						withParent:bundleIdentifier];
		
		return;
	}
	
	// Save parent bundle identifier
	if (parentIdentifier) {
		[info setObject:parentIdentifier forKey:@"MPEParentBundleIdentifier"];
		// Set dummy SUFeedURL for preferences section
		[info setObject:@"dummy" forKey:@"SUFeedURL"];
	// Only container bundles can update in nested bundles
	} else if ([PREFS boolForKey:@"SUEnableAutomaticChecks"] && [info objectForKey:@"SUFeedURL"]
				 && [[PREFS arrayForKey:MPEUpdateBinaries] containsObject:bundleIdentifier])
		[self createUpdaterForBundle:binary whichUpdatesAutomatically:YES];
	
	NSArray *archs = [binary executableArchitectureStrings];
	
	// Join the architectures array for displaying in the GUI
	[info setObject:archs forKey:@"MPEBinaryArchs"];
	if ([archs count] > 0)
		[info setObject:[archs componentsJoinedByString:@", "] forKey:@"MPEBinaryArchsString"];
	else
		[info setObject:@"???" forKey:@"MPEBinaryArchsString"];
	
	// Check binary architecture
	BOOL archIsCompatible = [self binaryHasCompatibleArch:binary];
	if (!archIsCompatible) {
		// Set a string a color for the GUI
		[info setObject:[NSString stringWithFormat:@"Not compatible: %@",
						 [info objectForKey:@"MPEBinaryArchsString"]]
				 forKey:@"MPEBinaryArchsString"];
		[info setObject:[NSColor redColor] forKey:@"MPEArchStringTextColor"];
	}
	
	// Save if binary has required minimum SVN-equivalent version
	BOOL versionIsCompatible = [self binaryHasRequiredMinVersion:info];
	if (!versionIsCompatible) {
		// Set a string a color for the GUI
		[info setObject:[NSString stringWithFormat:@"Not compatible: %@",
						 [info objectForKey:@"CFBundleShortVersionString"]]
				 forKey:@"CFBundleShortVersionString"];
		[info setObject:[NSColor redColor] forKey:@"MPEVersionStringTextColor"];
	}
	
	[info setObject:[NSNumber numberWithBool:(versionIsCompatible && archIsCompatible)] 
			 forKey:@"MPEBinaryIsCompatible"];
	
	[Debug log:ASL_LEVEL_INFO withMessage:@"Found binary %@ in %@",
	 [path lastPathComponent],[[path stringByDeletingLastPathComponent] lastPathComponent]];
	[binaryBundles setValue:binary forKey:bundleIdentifier];
	[binaryInfo setValue:info forKey:bundleIdentifier];
}

- (void) unloadBinary:(NSString *)identifier withUpdater:(BOOL)updater
{
	// Unload nested binaries
	if (![binaryInfo objectForKey:identifier]) {
		
		// Find nested binaries
		NSMutableArray *nestedIdentifiers = [NSMutableArray array];
		
		for (NSString *subIdent in binaryInfo) {
			NSString *parent = [[binaryInfo objectForKey:subIdent] objectForKey:@"MPEParentBundleIdentifier"];
			if (parent && [parent isEqualToString:identifier])
				[nestedIdentifiers addObject:subIdent];
		}
		
		// Unload them all
		for (NSString *subIdent in nestedIdentifiers)
			[self unloadBinary:subIdent withUpdater:updater];
	
	} else
		[binaryInfo removeObjectForKey:identifier];
	
	// Invalidate bundle object
	[[binaryBundles objectForKey:identifier] invalidateBinaryBundle];
	// Remove bundle objects
	[binaryBundles removeObjectForKey:identifier];
	
	if (updater)
		[binaryUpdaters removeObjectForKey:identifier];
}

- (BOOL) binaryHasRequiredMinVersion:(NSDictionary *)info
{
	int minRev = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"MPEBinaryMinRevision"] intValue];
	int bundleRev = [[info objectForKey:@"MPEBinarySVNRevisionEquivalent"] intValue];
	return (bundleRev >= minRev);
}

- (BOOL) binaryHasCompatibleArch:(BinaryBundle *)bundle
{
	const NXArchInfo *current_arch = NXGetLocalArchInfo();
	
	// Allow all arches if we fail to determine ours
	if (!current_arch)
		return YES;
	
	NSArray *binaryArches = [bundle executableArchitectureStrings];
	
	// Probably not a valid binary
	if ([binaryArches count] == 0)
		return NO;
	
	// extra 64bit check since CPU_TYPE_X86_64 doesn't seem to be very reliable
	int is64bitCapable;
	size_t len = sizeof(is64bitCapable);
	if (sysctlbyname("hw.optional.x86_64",&is64bitCapable,&len,NULL,0))
		is64bitCapable = NO;
	
	// x86_64 is able to run all (i386 and ppc through Rosetta)
	if (current_arch->cputype == CPU_TYPE_X86_64
		|| (current_arch->cputype == CPU_TYPE_I386 && is64bitCapable))
		return YES;
	// i386 is able to run i386 and ppc trough Rosetta
	else if (current_arch->cputype == CPU_TYPE_I386 && ([binaryArches containsObject:@"i386"] 
													   || [binaryArches containsObject:@"ppc64"]
													   || [binaryArches containsObject:@"ppc"]))
		return YES;
	// ppc64 is able to run ppc
	else if (current_arch->cputype == CPU_TYPE_POWERPC64 && ([binaryArches containsObject:@"ppc64"]
															|| [binaryArches containsObject:@"ppc"]))
		return YES;
	// ppc
	else if (current_arch->cputype == CPU_TYPE_POWERPC && [binaryArches containsObject:@"ppc"])
		return YES;
	
	return NO;
}

- (NSComparisonResult) compareBinaryVersion:(NSDictionary *)b1 toBinary:(NSDictionary*)b2
{
	return [[b1 objectForKey:@"CFBundleVersion"] compare:[b2 objectForKey:@"CFBundleVersion"]
												 options:NSNumericSearch];
}

/** Install a new binary from the Finder.
 */
- (void) installBinary:(NSString *)path
{
	BinaryBundle *binary = [[[BinaryBundle alloc] initWithPath:path] autorelease];
	
	// Check if given path is a bundle and is a valid binary bundle
	if (!binary || ![[binary infoDictionary] objectForKey:@"MPEBinarySVNRevisionEquivalent"]) {
		NSRunAlertPanel(@"Binary Installation Error", 
						[NSString stringWithFormat:@"The MPlayer binary '%@' couldn't be recognized.",
							[path lastPathComponent]], 
						 @"OK", nil, nil);
		return;
	}
	
	NSDictionary *info = [binary infoDictionary];
	NSString *identifier = [info objectForKey:@"CFBundleIdentifier"];
	
	// Check if the binary has minimum required version
	if (![self binaryHasRequiredMinVersion:info]) {
		NSRunAlertPanel(@"Binary Installation Error", 
						[NSString stringWithFormat:@"The MPlayer binary '%@' is not compatible with this %@ version (at least r%d required).",
						 [path lastPathComponent],
						 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
						 [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"MPEBinaryMinRevision"] intValue]], 
						@"OK", nil, nil);
		return;
	}
	
	BOOL isNewBinary;
	
	// A bundle with this identifier is already loaded: compare versions
	if ([binaryBundles objectForKey:identifier]) {
		
		isNewBinary = NO;
		NSDictionary *oldInfo;
		if ([binaryInfo objectForKey:identifier])
			oldInfo = [binaryInfo objectForKey:identifier];
		else
			oldInfo = [[binaryBundles objectForKey:identifier] infoDictionary];
		
		NSLog(@"old: %@",oldInfo);
		
		NSString *installedVersion = [oldInfo objectForKey:@"CFBundleVersion"];
		NSString *newVersion = [info objectForKey:@"CFBundleVersion"];
		NSComparisonResult result = [installedVersion compare:newVersion options:NSNumericSearch];
		NSLog(@"compare: %@ <-> %@ = %d",installedVersion,newVersion,result);
		
		// The versions are the same -> Reinstall?
		if (result == NSOrderedSame) {
			
			if (NSRunAlertPanel(@"Binary Already Installed", 
				[NSString stringWithFormat:
				 @"The MPlayer binary '%@' is already installed (version %@). Do you want to install it again?",
				 [info objectForKey:@"CFBundleName"],
				 [info objectForKey:@"CFBundleShortVersionString"]],
				 @"Cancel", @"Reinstall", nil) == NSAlertDefaultReturn) return;
		
		// The binary we're installing is newer -> Upgrade?
		} else if (result == NSOrderedAscending) {
			
			if (NSRunAlertPanel(@"Upgrade Binary", 
				[NSString stringWithFormat:
				 @"Do you want to upgrade the MPlayer binary '%@' from version %@ to %@?",
				 [info objectForKey:@"CFBundleName"],
				 [oldInfo objectForKey:@"CFBundleShortVersionString"],
				 [info objectForKey:@"CFBundleShortVersionString"]],
				 @"Upgrade", @"Cancel", nil) == NSAlertAlternateReturn) return;
		
		// The binary we're installing is older -> Downgrade?
		} else {
			
			if (NSRunAlertPanel(@"Downgrade Binary", 
				[NSString stringWithFormat:
				 @"A newer version of the MPlayer binary '%@' is already installed. Do you want to downgrade from version %@ to %@?",
				 [info objectForKey:@"CFBundleName"],
				 [oldInfo objectForKey:@"CFBundleShortVersionString"],
				 [info objectForKey:@"CFBundleShortVersionString"]],
				 @"Cancel", @"Downgrade", nil) == NSAlertDefaultReturn) return;
			
		}
		
	} else {
		
		// Install a new binary, ask if it should be autoupdated and made default
		isNewBinary = YES;
		
		NSAlert *alert = [NSAlert alertWithMessageText:@"Install Binary"
										 defaultButton:@"Install"
									   alternateButton:@"Cancel"
										   otherButton:nil
							 informativeTextWithFormat:@"Do you want to install the MPlayer binary '%@'?",
														[info objectForKey:@"CFBundleName"]];
		[alert setAccessoryView:binaryInstallOptions];
		[binaryInstallUpdatesCheckbox setHidden:(![info objectForKey:@"SUFeedURL"])];
		[binaryInstallDefaultCheckbox setHidden:(!![info objectForKey:@"MPENestedBinaryBundles"])];
		
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
	
	// Remove old binary if it's in the application support folder
	if ([binaryBundles objectForKey:identifier]) {
		NSString *bundlePath = [[binaryBundles objectForKey:identifier] bundlePath];
		if ([bundlePath rangeOfString:installPath].location != NSNotFound)
			FSPathMoveObjectToTrashSync([bundlePath UTF8String],NULL,0);
		
		// Invalidate bundle and remove binary references so it can be reloaded
		[self unloadBinary:identifier withUpdater:YES];
	}
	
	// Copy binary to user's application support directory
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
	
	// Apply install options
	if (isNewBinary) {
		
		// Enable/Disable automatic updates for this binary
		if (![binaryInstallUpdatesCheckbox isHidden]) {
			NSMutableArray *updates = [[[PREFS arrayForKey:MPEUpdateBinaries] mutableCopy] autorelease];
			if ([updates containsObject:identifier] && [binaryInstallUpdatesCheckbox state] == NSOffState)
				[updates removeObject:identifier];
			else if (![updates containsObject:identifier] && [binaryInstallUpdatesCheckbox state] == NSOnState)
				[updates addObject:identifier];
			[PREFS setObject:updates forKey:MPEUpdateBinaries];
		}
		
		// Make binary the default if the user wished it
		if (![binaryInstallDefaultCheckbox isHidden] && [binaryInstallDefaultCheckbox state] == NSOnState)
			[PREFS setObject:identifier forKey:MPESelectedBinary];
	}
	
	// Rescan binaries to load it
	[self scanBinaries];
	
	// Open the MPlayer preferences section
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

- (NSString *) updateIdentifierForBinaryWithIdentifier:(NSString *)identifier
{
	NSDictionary *info = [binaryInfo objectForKey:identifier];
	
	// Use update state parent bundle for nested bundles
	if ([info objectForKey:@"MPEParentBundleIdentifier"])
		return [info objectForKey:@"MPEParentBundleIdentifier"];
	else
		return [info objectForKey:@"CFBundleIdentifier"];
}

- (id) objectForInfoKey:(NSString *)keyName ofBinary:(NSString *)identifier
{
	if (![binaryInfo objectForKey:identifier]) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Binary not found for identifier: %@",identifier];
		return nil;
	}
	
	return [[binaryInfo objectForKey:identifier] objectForKey:keyName];
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

/** Callback from sparkle when the installation is complete to reload the binary
 */
- (void)updater:(SUUpdater *)updater hasFinishedInstallforUdpate:(SUAppcastItem *)update
{
	NSString *identifier = [[binaryUpdaters allKeysForObject:updater] objectAtIndex:0];
	
	[self unloadBinary:identifier withUpdater:YES];
	
	[self scanBinaries];
}

- (IBAction) selectNewScreenshotPath:(NSPopUpButton *)sender
{
	// Keep track of the last selection to reset the menu
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
		[PREFS setObject:[NSNumber numberWithInt:MPEScreenshotSaveLocationCustom] 
				  forKey:MPEScreenshotSaveLocation];
    } else {
		// User cancel: Reset the menu to the last selection
		[PREFS setObject:[NSNumber numberWithInt:screenshotSavePathLastSelection] 
				  forKey:MPEScreenshotSaveLocation];
	}
	
	[self requireRestart:sender];
}

/** Auto-select the fullscreen option when the user changes the screen number
 */
- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
	[fullscreenSelectionMatrix selectCellWithTag:1];
	
	return YES;
}

/** Use FontConfig to generate list of installed fonts.
 */
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
		   modalForWindow:[[[AppController sharedController] firstPlayerController] playerWindow] 
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

- (void) loadOutputDevices
{
	AudioDeviceID *devids;
	OSStatus err;
    AudioObjectPropertyAddress property_address;
    UInt32 i_param_size;
    
	// Get list of all audio device ids
    property_address.mSelector = kAudioHardwarePropertyDevices;
    property_address.mScope    = kAudioObjectPropertyScopeGlobal;
    property_address.mElement  = kAudioObjectPropertyElementMaster;
	
    err = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &property_address, 
										 0, NULL, &i_param_size);
	
    if (err != noErr)
        return [Debug log:ASL_LEVEL_ERR withMessage:@"Failed to get list of output devices: [%4.4s]",&err];
	
    devids = malloc(i_param_size);
	
    err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &property_address, 
									 0, NULL, &i_param_size, devids);
	
    if (err != noErr) {
        free(devids);
        return [Debug log:ASL_LEVEL_ERR withMessage:@"Failed to get list of output devices: [%4.4s]",&err];
    }
	
    int num_devices = i_param_size / sizeof(AudioDeviceID);
	
	CFStringRef string;
	
	// Construct device selection menu
	NSMenu *menu = [audioDeviceMenu menu];
	NSMenuItem *item;
	[menu removeAllItems];
	
	item = [[NSMenuItem new] autorelease];
	[item setTitle:@"Default Output Device"];
	[item setTag:0];
	[menu addItem:item];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	int i;
    for (i = 0; i < num_devices; ++i) {
		
		property_address.mSelector = kAudioDevicePropertyStreams;
		property_address.mScope    = kAudioDevicePropertyScopeOutput;
		
		// Check for output streams
		err = AudioObjectGetPropertyDataSize(devids[i], &property_address, 
											 0, NULL, &i_param_size);
		
		if (err != noErr)
			return [Debug log:ASL_LEVEL_ERR withMessage:@"Failed to get list of output streams: [%4.4s]",&err];
		
		if ((i_param_size / sizeof(AudioStreamID)) == 0)
			continue;
		
		// Get device name
		property_address.mSelector = kAudioObjectPropertyName;
		property_address.mScope    = kAudioObjectPropertyScopeGlobal;
		
		i_param_size = sizeof(CFStringRef);
		err = AudioObjectGetPropertyData(devids[i], &property_address, 0, NULL, &i_param_size, &string);
		if (err != noErr) {
			[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to get name of output device: [%4.4s]",&err];
			continue;
		}
		
		item = [[NSMenuItem new] autorelease];
		[item setTitle:(NSString *)string];
		[item setTag:devids[i]];
		[menu addItem:item];
		
		CFRelease(string);
    }
	
    free(devids);
	
	int outputDevice = 0;
	if ([PREFS objectForKey:MPEAudioOutputDevice])
		outputDevice = [PREFS integerForKey:MPEAudioOutputDevice];
	
	[audioDeviceMenu selectItemWithTag:outputDevice];
}

- (IBAction) selectOutputDevice:(NSPopUpButton *)sender
{
	[PREFS setInteger:[sender selectedTag] forKey:MPEAudioOutputDevice];
	
	[self requireRestart:sender];
}

- (IBAction) selectBinary:(id)sender
{
	// Ignore double-clicks outside of the table rows
	if (sender == binariesTable && [binariesTable clickedRow] < 0)
		return;
	
	NSDictionary *info = [[[binariesController selectedObjects] objectAtIndex:0] value];
	
	if (![[PREFS stringForKey:MPESelectedBinary] 
		  isEqualToString:[info objectForKey:@"CFBundleIdentifier"]]
		&& [self binaryHasRequiredMinVersion:info]) {
		
		[PREFS setObject:[info objectForKey:@"CFBundleIdentifier"] forKey:MPESelectedBinary];
		
		// Force update of the GUI
		[self setBinaryInfo:binaryInfo];
		
		[self requireRestart:sender];
	}
}

- (IBAction) visitBinaryHomepage:(id)sender
{
	NSDictionary *info = [[[binariesController selectedObjects] objectAtIndex:0] value];
	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[info objectForKey:@"MPEBinaryHomepage"]]];
}

/** Load state of the autoupdate check box when the selection changes.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"selection"]) {
		NSArray *selection = [binariesController selectedObjects];
		BOOL state = NO;
		if ([selection count] > 0) {
			
			NSDictionary *info = [[selection objectAtIndex:0] value];
			NSString *identifier = [self updateIdentifierForBinaryWithIdentifier:
									[info objectForKey:@"CFBundleIdentifier"]];
			state = [[PREFS arrayForKey:MPEUpdateBinaries] containsObject:identifier];
		}
		[binaryUpdateCheckbox setState:state];
	}
}

- (IBAction) setChecksForUpdates:(NSButton *)sender
{
	NSDictionary *info = [[[binariesController selectedObjects] objectAtIndex:0] value];
	NSString *identifier = [self updateIdentifierForBinaryWithIdentifier:[info objectForKey:@"CFBundleIdentifier"]];
	
	NSArray *updates = [PREFS arrayForKey:MPEUpdateBinaries];
	NSMutableArray *newUpdates = nil;
	
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

/** Initialize and return view for slecting a binary.
 */
- (NSView *) binarySelectionView
{
	[binarySelectionPopUp selectItemWithTag:-1];
	return binarySelectionView;
}

/** Return the identifier for the binary the user selected in the -binarySelectionView.
 */
- (NSString *) identifierFromSelectionInView
{
	if ([binarySelectionPopUp selectedTag] > -1)
		return [self identifierForBinaryName:[[binarySelectionPopUp selectedItem] title]];
	else
		return nil;
}

/** Action for the button in the custom aspect ratio chooser window.
 */
- (IBAction) chooseCustomAspectRatio:(NSButton *)sender
{
	// MenuController's setAspectFromMenu uses the custom aspect when it's nil
	[[[AppController sharedController] menuController] setAspectFromMenu:nil];
	
	[[sender window] orderOut:self];
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

+ (NSString *) osdLevelDescriptionForLevel:(int)osdLevel
{
	NSPopUpButton *popup = [[AppController sharedController] preferencesController]->osdLevelPopUp;
	return [popup itemTitleAtIndex:[popup indexOfItemWithTag:osdLevel]];
}

@end


/** Convert between ENCA two-letter codes and the display language
 */
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


/** Validate the custom aspect ratio and cache a parsed value
 */
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


/** Use the aspect ratio menu titles to save them and convert the special cases (Original/Custom)
 */
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

/** Transformer used to make the selected binary bold in the table
 */
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


/** Transformer used to only display valid binaries in selection menus
 */
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
