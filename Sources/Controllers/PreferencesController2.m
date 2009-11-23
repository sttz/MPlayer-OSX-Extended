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

#import "PreferencesController2.h"

#import "AppController.h"
#import "PlayerController.h"

#import "Debug.h"
#import "Preferences.h"

#import <fontconfig/fontconfig.h>
#import "RegexKitLite.h"

// regex for parsing aspect ratio
#define ASPECT_REGEX	@"^(\\d+\\.?\\d*|\\.\\d+)(?:\\:(\\d+\\.?\\d*|\\.\\d+))?$"

@implementation PreferencesController2
@synthesize fonts, customAspectRatioChooser;

- (void) awakeFromNib
{
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
	
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES]; 
	
	screenshotSavePathLastSelection = [PREFS integerForKey:MPECustomScreenshotsSavePath];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(loadFonts)
												 name:NSApplicationDidFinishLaunchingNotification
											   object:NSApp];
}

- (void) dealloc
{
	[views release];
	[currentViewName release];
	
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

- (IBAction) requireRestart:(id)sender
{
	BOOL restart = [[[AppController sharedController] playerController] changesRequireRestart];
	NSLog(@"require restart? %d",restart);
	
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
	NSModalSession modal = NULL;
	
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
		[cacheStatusWindow makeKeyAndOrderFront:self];
		[cacheStatusIndicator setUsesThreadedAnimation:YES];
		[cacheStatusIndicator startAnimation:self];
		modal = [NSApp beginModalSessionForWindow:cacheStatusWindow];
	}
	
	if (!FcConfigBuildFonts(config)) {
		FcConfigDestroy(config);
		return [Debug log:ASL_LEVEL_ERR withMessage:@"Failed to build Fontconfig cache."];
	}
	
	if (modal) {
		[NSApp endModalSession:modal];
		[cacheStatusWindow close];
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