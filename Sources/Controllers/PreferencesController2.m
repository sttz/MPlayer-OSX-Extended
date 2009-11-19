//
//  PreferencesController2.m
//  MPlayer OSX Extended
//
//  Created by Adrian on 05.11.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PreferencesController2.h"

#import "AppController.h"
#import "Debug.h"

#import <fontconfig/fontconfig.h>

@implementation PreferencesController2
@synthesize fonts;

- (void) awakeFromNib
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	
	views = [[NSDictionary alloc] initWithObjectsAndKeys:
			 generalView,	@"General",
			 displayView,	@"Display",
			 textView,		@"Text",
			 audioView,		@"Audio",
			 videoView,		@"Video",
			 mplayerView,	@"MPlayer",
			 advancedView,	@"Advanced",
			 nil];
	
	if ([prefs objectForKey:@"MPESelectedPreferencesSection"])
		[self loadView:[prefs stringForKey:@"MPESelectedPreferencesSection"]];
	else
		[self loadView:@"General"];
	
	screenshotSavePathLastSelection = [prefs integerForKey:@"MPEScreenshotSaveLocation"];
	
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
	[[[self window] contentView] addSubview:restartView];
	[self loadView:currentViewName];
}

- (IBAction) restartPlayback:(id)sender
{
	[restartView removeFromSuperview];
	[self loadView:currentViewName];
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
	
	NSString *oldPath = [prefs objectForKey:@"MPECustomScreenshotsSavePath"];
	
	if ([panel runModalForDirectory:oldPath file:nil types:nil] == NSOKButton) {
		[prefs setObject:[[panel filenames] objectAtIndex:0] 
				  forKey:@"MPECustomScreenshotsSavePath"];
		[sender selectItemWithTag:4];
    } else {
		[sender selectItemWithTag:screenshotSavePathLastSelection];
	}
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
		fonts = [[NSMutableDictionary dictionaryWithCapacity:set->nfont] retain];
		
		int i;
		for (i = 0; i < set->nfont; i++) {
			
			FcChar8 *family;
			FcChar8 *fontstyle;
			NSMutableArray *styles;
			
			if (FcPatternGetString(set->fonts[i], FC_FAMILY, 0, &family) == FcResultMatch) {
				
				// For now just take the 0th family and style name, which should be the english one
				if (![fonts objectForKey:[NSString stringWithUTF8String:(const char*)family]]) {
					styles = [NSMutableArray arrayWithCapacity:1];
					[fonts setObject:styles	forKey:[NSString stringWithUTF8String:(const char*)family]];
				} else {
					styles = [fonts objectForKey:[NSString stringWithUTF8String:(const char*)family]];
				}
				
				if (FcPatternGetString(set->fonts[i], FC_STYLE, 0, &fontstyle) == FcResultMatch)
					[styles addObject:[NSString stringWithUTF8String:(const char*)fontstyle]];
				
			}
			
		}
		
		[fontsController setContent:fonts];
	} else {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to create font list."];
	}
	
	// Load font selection
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSString *defaultFont;
	if ([prefs objectForKey:@"MPEFont"])
		defaultFont = [prefs stringForKey:@"MPEFont"];
	else
		defaultFont = @"Helvetica";
	
	[fontsMenu selectItemWithTitle:defaultFont];
	
	FcFontSetDestroy(set);
	FcFini();
}

- (IBAction) changeFont:(NSPopUpButton *)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[sender titleOfSelectedItem] forKey:@"MPEFont"];
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
				 @"Disabled",	@"",
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