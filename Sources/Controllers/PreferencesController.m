/*
 *  PreferencesController.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "PreferencesController.h"
#import <RegexKit/RegexKit.h> 

// other controllers
#import "AppController.h"
#import "PlayerController.h"
#import "LanguageCodes.h"

#import <fontconfig/fontconfig.h>
#import <Sparkle/Sparkle.h>

// regex for parsing aspect ratio
#define ASPECT_REGEX	@"^(\\d+\\.?\\d*|\\.\\d+)(?:\\:(\\d+\\.?\\d*|\\.\\d+))?$"

@implementation PreferencesController

- (void) awakeFromNib;
{
	// register for app launch finish
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(loadFonts)
			name: NSApplicationDidFinishLaunchingNotification
			object:NSApp];
	
	// compile guess codes
	guessCodes = [[NSArray alloc] initWithObjects:
				  @"__",	// None	
				  @"be",	// Belarussian
				  @"bg",	// Bulgarian
				  @"cs",	// Czech
				  @"et",	// Estonian
				  @"hr",	// Croatian
				  @"hu",	// Hungarian
				  @"lt",	// Latvian
				  @"lv",	// Lithuanian
				  @"pl",	// Polish
				  @"ru",	// Russian
				  @"sk",	// Slovak
				  @"sl",	// Slovene
				  @"uk",	// Ukrainian
				  @"zh",	// Chinese
				  nil
				  ];
	
	// add codes to menu
	int i;
	for (i = 0; i < [guessLanguage numberOfItems]; i++) {
		[[guessLanguage itemAtIndex:i] setRepresentedObject:[guessCodes objectAtIndex:i]];
	}
	
}


- (void)loadFonts
{
	FcConfig *config;
	FcPattern *pat;
	FcFontSet *set;
	FcObjectSet *os;
	NSModalSession modal = NULL;
	
	// Initialize fontconfig with own config directory
	setenv("FONTCONFIG_PATH", [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"fonts"] cString], 1);
	
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
		[fcWindow makeKeyAndOrderFront:self];
		[fcProgress setUsesThreadedAnimation:YES];
		[fcProgress startAnimation:self];
		modal = [NSApp beginModalSessionForWindow:fcWindow];
	}
	
	if (!FcConfigBuildFonts(config)) {
		FcConfigDestroy(config);
		return [Debug log:ASL_LEVEL_ERR withMessage:@"Failed to build Fontconfig cache."];
	}
	
	if (modal) {
		[NSApp endModalSession:modal];
		[fcWindow close];
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
				if (![fonts objectForKey:[NSString stringWithCString:(const char*)family]]) {
					styles = [NSMutableArray arrayWithCapacity:1];
					[fonts setObject:styles	forKey:[NSString stringWithCString:(const char*)family]];
				} else {
					styles = [fonts objectForKey:[NSString stringWithCString:(const char*)family]];
				}
				
				if (FcPatternGetString(set->fonts[i], FC_STYLE, 0, &fontstyle) == FcResultMatch)
					[styles addObject:[NSString stringWithCString:(const char*)fontstyle]];
				
			}
			
		}
	} else {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to create font list."];
	}
	
	FcFontSetDestroy(set);
	FcFini();
}

/************************************************************************************
 MISC
 ************************************************************************************/
- (void) reloadValues
{
	NSUserDefaults *thePrefs = [appController preferences];
	
	// ** Playback
	
	// audio languages
	if ([thePrefs objectForKey:@"AudioLanguages"])
		[audioLanguages setStringValue:[thePrefs stringForKey:@"AudioLanguages"]];
	else
		[audioLanguages setStringValue:@""];
	
	// subtitle languages
	if ([thePrefs objectForKey:@"SubtitleLanguages"])
		[subtitleLanguages setStringValue:[thePrefs stringForKey:@"SubtitleLanguages"]];
	else
		[subtitleLanguages setStringValue:@""];
	
	// display paylist on startup
	if ([thePrefs objectForKey:@"PlaylistOnStartup"])
		[playlistOnStartup setState:[thePrefs boolForKey:@"PlaylistOnStartup"]];
	
	// remember position option
	if ([thePrefs objectForKey:@"PlaylistRemember"])
		[playlistRemember setState:[thePrefs boolForKey:@"PlaylistRemember"]];
	
	// playlist text size
	if ([thePrefs objectForKey:@"SmallPlaylistText"])
		[playlistSmallText setState:[thePrefs boolForKey:@"SmallPlaylistText"]];
	
	// cache settings
	if ([thePrefs objectForKey:@"CacheSize"]) {
		[cacheSizeSlider setFloatValue:
					[[thePrefs objectForKey:@"CacheSize"] floatValue]];
		if ([[thePrefs objectForKey:@"CacheSize"] floatValue] > 0) {
			[cacheSizeBox setStringValue:
					[NSString stringWithFormat:@"%.1fMB", [[thePrefs objectForKey:@"CacheSize"] floatValue]]
			];
		}
		else
			[cacheSizeBox setStringValue:@""];
	}
	else {
		[cacheSizeSlider setFloatValue: 0];
		[cacheSizeBox setStringValue:@""];
	}
	
	// check for updates
	[checkForUpdates setState:[[SUUpdater sharedUpdater] automaticallyChecksForUpdates]];
	
	// check for prereleases
	if ([thePrefs objectForKey:@"CheckForPrereleases"])
		[checkForPrereleases setState:[thePrefs boolForKey:@"CheckForPrereleases"]];
	
	
	// *** Display
	
	// display type
	if ([thePrefs objectForKey:@"DisplayType"])
		[displayType selectCellWithTag: [[thePrefs objectForKey:@"DisplayType"] intValue]];
	else
		[displayType selectCellWithTag: 0];
	
	// flip vertical
	if ([thePrefs objectForKey:@"FlipVertical"])
		[flipVertical setState:[thePrefs boolForKey:@"FlipVertical"]];
	
	// flip horizontal
	if ([thePrefs objectForKey:@"FlipHorizontal"])
		[flipHorizontal setState:[thePrefs boolForKey:@"FlipHorizontal"]];
	
	// video size menu
	if ([thePrefs objectForKey:@"VideoSize"])
		[videoSizeMenu selectItemAtIndex:
				[[thePrefs objectForKey:@"VideoSize"] intValue]];
	else
		[videoSizeMenu selectItemWithTitle:NSLocalizedString(@"original",nil)];
	
	// video size box
	if ([thePrefs objectForKey:@"CustomVideoSize"])
		[videoSizeBox setIntValue:[[thePrefs
				objectForKey:@"CustomVideoSize"] unsignedIntValue]];
	else
		[videoSizeBox setStringValue:@""];
	
	// video aspect menu
	if ([thePrefs objectForKey:@"VideoAspect"])
		[videoAspectMenu selectItemAtIndex:
				[[thePrefs objectForKey:@"VideoAspect"] intValue]];
	else
		[videoAspectMenu selectItemWithTitle:NSLocalizedString(@"original",nil)];
	
	// video aspect box
	if ([thePrefs objectForKey:@"CustomVideoAspect"])
		[videoAspectBox setStringValue:[thePrefs stringForKey:@"CustomVideoAspect"]];
	else
		[videoAspectBox setStringValue:@""];
	
	// fullscreen device
	if ([thePrefs objectForKey:@"FullscreenDeviceSameAsPlayer"])
		[fullscreenSameAsPlayer setState:[thePrefs boolForKey:@"FullscreenDeviceSameAsPlayer"]];
	
	if ([thePrefs objectForKey:@"FullscreenDevice"])
		[fullscreenDeviceId setIntValue:[[thePrefs
				objectForKey:@"FullscreenDevice"] unsignedIntValue]];
	else
		[fullscreenDeviceId setStringValue:@"0"];
	
	// black out screens
	if ([thePrefs objectForKey:@"BlackOutOtherScreens"])
		[blackoutScreens setState:[thePrefs boolForKey:@"BlackOutOtherScreens"]];
	
	// video driver
	if ([thePrefs objectForKey:@"VideoDriver"])
		[videoDriverMenu selectItemAtIndex: [[thePrefs objectForKey:@"VideoDriver"] intValue]];
	else
		[videoDriverMenu selectItemAtIndex: 0];
	
	// screenshots
	if ([thePrefs objectForKey:@"Screenshots"])
		[screenshots selectItemAtIndex: [[thePrefs objectForKey:@"Screenshots"] intValue]];
	else
		[screenshots selectItemAtIndex: 1];
	
	// animate transitions
	if ([thePrefs objectForKey:@"AnimateInterfaceTransitions"])
		[animateInterface setState:[thePrefs boolForKey:@"AnimateInterfaceTransitions"]];
	
	
	// *** Text
	
	// create fonts menu
	[subFontMenu removeAllItems];
	
	// add first item - none and separator
	[subFontMenu addItemWithTitle:NSLocalizedString(@"none",nil)];
	[[subFontMenu lastItem] setTag:0];
	
	if (fonts) {
		[[subFontMenu menu] addItem:[NSMenuItem separatorItem]];
		
		// add fonts
		NSEnumerator *e = [[[fonts allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectEnumerator];
		id obj;
		while (obj = [e nextObject]) {
			[subFontMenu addItemWithTitle:obj];
		}
		
		// select font
		if ([thePrefs objectForKey:@"SubtitlesFontName"]) {
			[subFontMenu selectItemAtIndex:[subFontMenu indexOfItemWithTitle:
											[thePrefs objectForKey:@"SubtitlesFontName"]]];
			if ([subFontMenu indexOfSelectedItem] < 0)
				[subFontMenu selectItemAtIndex:0];
		}
		else
			[subFontMenu selectItemAtIndex:0];
		
		// create font style menu
		[self initFontStyleMenu];
	}
	
	// subtitles encoding
	if ([thePrefs objectForKey:@"SubtitlesEncoding"]) {
		[subEncodingMenu selectItemWithTitle:[thePrefs objectForKey:@"SubtitlesEncoding"]];
		if ([subEncodingMenu indexOfSelectedItem] < 0)
			[subEncodingMenu selectItemAtIndex:0];
	}
	else
		[subEncodingMenu selectItemAtIndex:0];
	
	// guess encoding
	if ([thePrefs objectForKey:@"SubtitlesGuessEncoding"])
		[guessEncoding setState:[thePrefs boolForKey:@"SubtitlesGuessEncoding"]];
	
	// guess language
	if ([thePrefs objectForKey:@"SubtitlesGuessLanguage"]) {
		int i;
		for (i = 0; i < [guessLanguage numberOfItems]; i++) {
			if ([[[guessLanguage itemAtIndex:i] representedObject] 
				 isEqualToString:[thePrefs stringForKey:@"SubtitlesGuessLanguage"]]) {
				[guessLanguage selectItemAtIndex:i];
			}
		}
		if ([guessLanguage indexOfSelectedItem] < 0)
			[guessLanguage selectItemAtIndex:0];
	}
	else
		[guessLanguage selectItemAtIndex:0];
	
	// ass subtitles
	if ([thePrefs objectForKey:@"ASSSubtitles"])
		[assSubtitles setState:[thePrefs boolForKey:@"ASSSubtitles"]];
	
	// subtitles size
	if ([thePrefs objectForKey:@"SubtitlesScale"])
		[subSizeBox setIntValue:[[thePrefs objectForKey:@"SubtitlesScale"] intValue]];
	else
		[subSizeBox setIntValue:100];
	
	// embedded fonts
	if ([thePrefs objectForKey:@"EmbeddedFonts"])
		[embeddedFonts setState:[thePrefs boolForKey:@"EmbeddedFonts"]];
	
	// ass at the beginning of filter chain
	if ([thePrefs objectForKey:@"ASSPreFilter"])
		[assPreFilter setState:[thePrefs boolForKey:@"ASSPreFilter"]];
	
	// subtitle color
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES]; 
	if ([thePrefs objectForKey:@"SubtitlesColor"] 
			&& [NSUnarchiver unarchiveObjectWithData:[thePrefs objectForKey:@"SubtitlesColor"]])
		[subColorWell setColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[thePrefs objectForKey:@"SubtitlesColor"]]];
	else
		[subColorWell setColor:[NSColor whiteColor]];
	
	// subtitle border color
	if ([thePrefs objectForKey:@"SubtitlesBorderColor"] 
			&& [NSUnarchiver unarchiveObjectWithData:[thePrefs objectForKey:@"SubtitlesBorderColor"]])
		[subBorderColorWell setColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[thePrefs objectForKey:@"SubtitlesBorderColor"]]];
	else
		[subBorderColorWell setColor:[NSColor blackColor]];
	
	// osd level
	if ([thePrefs objectForKey:@"OSDLevel"])
		[osdLevel selectItemAtIndex:[thePrefs integerForKey:@"OSDLevel"]];
	else
		[osdLevel selectItemAtIndex:1];
	
	// osd scale
	if ([thePrefs objectForKey:@"OSDScale"])
		[osdScale setIntValue:[[thePrefs objectForKey:@"OSDScale"] intValue]];
	else
		[osdScale setIntValue:100];
	
	
	
	// ** Video
	
	// enable video
	if ([thePrefs objectForKey:@"EnableVideo"])
		[enableVideo setState:[thePrefs boolForKey:@"EnableVideo"]];
	
	// video codecs
	if ([thePrefs objectForKey:@"VideoCodecs"]) {
		[videoCodecs setStringValue: [thePrefs stringForKey:@"VideoCodecs"]];
	}
	else
		[videoCodecs setStringValue:@""];
	
	// framedrop
	if ([thePrefs objectForKey:@"Framedrop"])
		[framedrop setSelectedSegment: [thePrefs integerForKey:@"Framedrop"]];
	else
		[framedrop setSelectedSegment: 0];
	
	// fast libavcodec decoding
	if ([thePrefs objectForKey:@"FastLibavcodecDecoding"])
		[fastLibavcodec setState:[thePrefs boolForKey:@"FastLibavcodecDecoding"]];
	
	// deinterlace
	if ([thePrefs objectForKey:@"Deinterlace_r9"])
		[deinterlace setSelectedSegment: [thePrefs integerForKey:@"Deinterlace_r9"]];
	else
		[deinterlace setSelectedSegment: 0];
	
	// postprocessing
	if ([thePrefs objectForKey:@"Postprocessing"])
		[postprocessing setSelectedSegment: [thePrefs integerForKey:@"Postprocessing"]];
	else
		[postprocessing setSelectedSegment: 0];
	
	// FFmpeg-MT
	if ([thePrefs objectForKey:@"UseFFmpegMT"])
		[useFFmpegMT setState:[thePrefs boolForKey:@"UseFFmpegMT"]];
	
	// skip loopfilter
	if ([thePrefs objectForKey:@"SkipLoopfilter"])
		[skipLoopfilter setSelectedSegment: [thePrefs integerForKey:@"SkipLoopfilter"]];
	else
		[skipLoopfilter setSelectedSegment: 0];
	
	
	// *** Audio
	
	// enable audio
	if ([thePrefs objectForKey:@"EnableAudio"])
		[enableAudio setState:[thePrefs boolForKey:@"EnableAudio"]];
	
	// audio codecs
	if ([thePrefs objectForKey:@"AudioCodecs"]) {
		[audioCodecs setStringValue: [thePrefs stringForKey:@"AudioCodecs"]];
	}
	else
		[audioCodecs setStringValue:@""];
	
	// ac3 passthrough
	if ([thePrefs objectForKey:@"PassthroughAC3"])
		[passthroughAC3 setState:[thePrefs boolForKey:@"PassthroughAC3"]];
	
	// ac3 passthrough
	if ([thePrefs objectForKey:@"PassthroughDTS"])
		[passthroughDTS setState:[thePrefs boolForKey:@"PassthroughDTS"]];
	
	// hrtf filter
	if ([thePrefs objectForKey:@"HRTFFilter"])
		[hrtfFilter setState:[thePrefs boolForKey:@"HRTFFilter"]];
	
	// karaoke filter
	if ([thePrefs objectForKey:@"KaraokeFilter"])
		[karaokeFilter setState:[thePrefs boolForKey:@"KaraokeFilter"]];
	
	
	
	// *** Advanced
	
	// aduio equalizer enabled
	if ([thePrefs objectForKey:@"AudioEqualizerEnabled"])
		[equalizerEnabled setState:[thePrefs boolForKey:@"AudioEqualizerEnabled"]];
	// audio equalizer
	if ([thePrefs objectForKey:@"AudioEqualizerValues"]) {
		
		NSArray *values = [thePrefs arrayForKey:@"AudioEqualizerValues"];
		/*if ([values count] != 10) {
			break;
			//[values release];
		}*/
		if ([values count] == 10) {
			[equalizer32 setFloatValue: [[values objectAtIndex:0] floatValue]];
			[equalizer63 setFloatValue: [[values objectAtIndex:1] floatValue]];
			[equalizer125 setFloatValue: [[values objectAtIndex:2] floatValue]];
			[equalizer250 setFloatValue: [[values objectAtIndex:3] floatValue]];
			[equalizer500 setFloatValue: [[values objectAtIndex:4] floatValue]];
			[equalizer1k setFloatValue: [[values objectAtIndex:5] floatValue]];
			[equalizer2k setFloatValue: [[values objectAtIndex:6] floatValue]];
			[equalizer4k setFloatValue: [[values objectAtIndex:7] floatValue]];
			[equalizer8k setFloatValue: [[values objectAtIndex:8] floatValue]];
			[equalizer16k setFloatValue: [[values objectAtIndex:9] floatValue]];
			//[values release];
		}
	}
	
	// video equalizer enabled
	if ([thePrefs objectForKey:@"VideoEqualizerEnabled"])
		[veEnabled setState:[thePrefs boolForKey:@"VideoEqualizerEnabled"]];
	// video equalizer
	if ([thePrefs objectForKey:@"VideoEqualizer"]) {
		
		NSArray *values = [thePrefs arrayForKey:@"VideoEqualizer"];
		/*if ([values count] != 8) {
			break;
			//[values release];
		}*/
		if ([values count] == 8) {
			[veGamma setFloatValue: [[values objectAtIndex:0] floatValue]];
			[veContrast setFloatValue: [[values objectAtIndex:1] floatValue]];
			[veBrightness setFloatValue: [[values objectAtIndex:2] floatValue]];
			[veSaturation setFloatValue: [[values objectAtIndex:3] floatValue]];
			[veGammaRed setFloatValue: [[values objectAtIndex:4] floatValue]];
			[veGammaGreen setFloatValue: [[values objectAtIndex:5] floatValue]];
			[veGammaBlue setFloatValue: [[values objectAtIndex:6] floatValue]];
			[veWeight setFloatValue: [[values objectAtIndex:7] floatValue]];
			//[values release];
		}
	}
	
	// additional params box
	if ([thePrefs objectForKey:@"EnableAdditionalParams"]) {
		[addParamsButton setState:[thePrefs boolForKey:@"EnableAdditionalParams"]];
	}
	else
		[addParamsButton setState:NSOffState];
	// additional
	[addParamsBox removeAllItems];
	[addParamsBox setHasVerticalScroller:NO];
	if ([thePrefs objectForKey:@"AdditionalParams"]) {
		if ([[thePrefs objectForKey:@"AdditionalParams"] isKindOfClass:[NSString class]])
			[addParamsBox addItemWithObjectValue:[thePrefs objectForKey:@"AdditionalParams"]];
		else
			[addParamsBox addItemsWithObjectValues:[thePrefs objectForKey:@"AdditionalParams"]];
		[addParamsBox selectItemAtIndex:0];
		[addParamsBox setHasVerticalScroller:NO];
		[addParamsBox setNumberOfVisibleItems:[addParamsBox numberOfItems]];
	}
	
	
	
	[self enableControls:nil];
}
/************************************************************************************/
- (void) initFontStyleMenu
{
	if ([subFontMenu indexOfSelectedItem] != 0) {
		
		NSUserDefaults *thePrefs = [appController preferences];
		
		[subStyleMenu removeAllItems];
		
		NSEnumerator *e = [[[fonts objectForKey:[subFontMenu titleOfSelectedItem]] 
							sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] 
						   objectEnumerator];
		id obj;
		while (obj = [e nextObject]) {
			[subStyleMenu addItemWithTitle:obj];
		}
		
		if ([thePrefs objectForKey:@"SubtitlesStyleName"])
			[subStyleMenu selectItemWithTitle:[thePrefs stringForKey:@"SubtitlesStyleName"]];
		else
			[subStyleMenu selectItemWithTitle:@"Regular"];
		
		if ([subStyleMenu indexOfSelectedItem] < 0)
			[subStyleMenu selectItemAtIndex:0];
		
		[subStyleMenu setEnabled:([subStyleMenu numberOfItems] > 0)];
		
	} else
		[subStyleMenu setEnabled:NO];
}

/************************************************************************************
 ACTIONS
 ************************************************************************************/
- (IBAction)displayPreferences:(id)sender
{
	// init values
	[self reloadValues];
	closeAfterApply = NO;
	
	[preferencesPanel makeKeyAndOrderFront:self];
}
/************************************************************************************/
- (IBAction)applyAndClose:(id)sender
{
	closeAfterApply = YES;
	[self applyPrefs:self];
}
/************************************************************************************/
- (IBAction)applyPrefs:(id)sender
{
	NSUserDefaults *thePrefs = [appController preferences];
	
	[thePrefs setObject:@"rev7" forKey:@"Version"];
	
	// *** Playback
	
	// audio languages
	[thePrefs setObject:[audioLanguages stringValue] forKey:@"AudioLanguages"];
	
	// subtitle languages
	[thePrefs setObject:[subtitleLanguages stringValue] forKey:@"SubtitleLanguages"];
	
	// playlist on startup
	[thePrefs setBool:[playlistOnStartup state] forKey:@"PlaylistOnStartup"];
	
	// playlist remember position
	[thePrefs setBool:[playlistRemember state] forKey:@"PlaylistRemember"];
	
	// playlist small text
	[thePrefs setBool:[playlistSmallText state] forKey:@"SmallPlaylistText"];
	
	// cache size
	[thePrefs setObject:[NSNumber numberWithFloat:[cacheSizeSlider floatValue]]
			forKey:@"CacheSize"];
	
	// check for updates
	[[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:[checkForUpdates state]];
	
	// check for prereleases
	[thePrefs setBool:[checkForPrereleases state] forKey:@"CheckForPrereleases"];
	[appController setSparkleFeed];
	
	
	
	// *** Display
	
	// display type
	[thePrefs setObject:[NSNumber numberWithInt:[[displayType selectedCell] tag]]
			forKey:@"DisplayType"];
	
	// flip vertical
	[thePrefs setBool:[flipVertical state] forKey:@"FlipVertical"];
	
	// flip horizontal
	[thePrefs setBool:[flipHorizontal state] forKey:@"FlipHorizontal"];
	
	// video size menu
	[thePrefs setObject:[NSNumber numberWithInt:[videoSizeMenu indexOfSelectedItem]]
			forKey:@"VideoSize"];
	
	// video size box
	[thePrefs setObject:[NSNumber numberWithInt:[videoSizeBox intValue]]
			forKey:@"CustomVideoSize"];
	
	// video aspect menu
	[thePrefs setObject:[NSNumber numberWithInt:[videoAspectMenu indexOfSelectedItem]]
			forKey:@"VideoAspect"];
	
	// video aspect box
	[thePrefs setObject:[videoAspectBox stringValue] forKey:@"CustomVideoAspect"];
	
	// parse value
	if ([[videoAspectBox stringValue] length] > 0) {
		// Parts of custom aspect ratio
		NSString *part1 = nil, *part2 = nil;
		// Parse custom aspect ratio field (eiher "x.x or x.x:x.x)
		if ([[videoAspectBox stringValue] getCapturesWithRegexAndReferences:
			 ASPECT_REGEX,
			 @"${1}", &part1,
			 @"${2}", &part2, nil]) {
			
			if (part1 && part2)				
				[thePrefs setFloat:([part1 floatValue] / [part2 floatValue]) forKey:@"CustomVideoAspectValue"];
			else
				[thePrefs setFloat:[part1 floatValue] forKey:@"CustomVideoAspectValue"];
		} else
			[thePrefs setFloat:[videoAspectBox floatValue] forKey:@"CustomVideoAspectValue"];
	} else
		[thePrefs setFloat:0.0 forKey:@"CustomVideoAspectValue"];
	
	// update aspect menu
	[appController updateAspectMenu];
	
	// fullscreen device id
	[thePrefs setBool:[fullscreenSameAsPlayer state] forKey:@"FullscreenDeviceSameAsPlayer"];
	
	if ([fullscreenDeviceId intValue] >= 0)
		[thePrefs setObject:[NSNumber numberWithInt:[fullscreenDeviceId intValue]]
				forKey:@"FullscreenDevice"];
	else
		[thePrefs setObject:[NSNumber numberWithInt:0] forKey:@"FullscreenDevice"];
	
	// black out other screens
	[thePrefs setBool:[blackoutScreens state] forKey:@"BlackOutOtherScreens"];
	
	// video out module
	[thePrefs setObject:[NSNumber numberWithInt:[videoDriverMenu indexOfSelectedItem]]
			forKey:@"VideoDriver"];
	
	// screenshots
	[thePrefs setObject:[NSNumber numberWithInt:[screenshots indexOfSelectedItem]]
			forKey:@"Screenshots"];
	
	// animations
	[thePrefs setBool:[animateInterface state] forKey:@"AnimateInterfaceTransitions"];
	
	
	
	// *** Text
	
	// subtitles font
	if ([subFontMenu indexOfSelectedItem] <= 0)
		[thePrefs removeObjectForKey:@"SubtitlesFontName"];
	else
		[thePrefs setObject:[subFontMenu titleOfSelectedItem] forKey:@"SubtitlesFontName"];
	
	// font style
	if ([subStyleMenu indexOfSelectedItem] == -1)
		[thePrefs removeObjectForKey:@"SubtitlesStyleName"];
	else
		[thePrefs setObject:[subStyleMenu titleOfSelectedItem] forKey:@"SubtitlesStyleName"];
	
	// subtitles encoding
	[thePrefs setObject:[subEncodingMenu titleOfSelectedItem]
				 forKey:@"SubtitlesEncoding"];
	
	// guess encoding
	[thePrefs setBool:[guessEncoding state] forKey:@"SubtitlesGuessEncoding"];
	
	// guess language
	if ([guessLanguage indexOfSelectedItem] > 0)
		[thePrefs setObject:[[guessLanguage selectedItem] representedObject] forKey:@"SubtitlesGuessLanguage"];
	else
		[thePrefs removeObjectForKey:@"SubtitlesGuessLanguage"];
	
	// ass subtitles
	[thePrefs setBool:[assSubtitles state] forKey:@"ASSSubtitles"];
	
	// subtitles size
	[thePrefs setObject:[NSNumber numberWithInt:[subSizeBox intValue]]
				 forKey:@"SubtitlesScale"];
	
	// embedded fonts
	[thePrefs setBool:[embeddedFonts state] forKey:@"EmbeddedFonts"];
	
	// ass pre filter
	[thePrefs setBool:[assPreFilter state] forKey:@"ASSPreFilter"];
	
	// subtitle color
	NSData *color = [NSArchiver archivedDataWithRootObject:[[subColorWell color] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]];
	[thePrefs setObject:color forKey:@"SubtitlesColor"];
	
	// subtitle border color
	color = [NSArchiver archivedDataWithRootObject:[[subBorderColorWell color] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]];
	[thePrefs setObject:color forKey:@"SubtitlesBorderColor"];
	
	// osd level
	[thePrefs setInteger:[osdLevel indexOfSelectedItem] forKey:@"OSDLevel"];
	
	// osd scale
	[thePrefs setObject:[NSNumber numberWithInt:[osdScale intValue]]
				 forKey:@"OSDScale"];
	
	
	
	// *** Video
	
	// video enabled
	[thePrefs setBool:[enableVideo state] forKey:@"EnableVideo"];
	
	// video codecs
	[thePrefs setObject:[videoCodecs stringValue] forKey:@"VideoCodecs"];
	
	// framedrop
	[thePrefs setObject:[NSNumber numberWithInt:[framedrop indexOfSelectedItem]]
			forKey:@"Framedrop"];
	
	// fast libavcodec
	[thePrefs setBool:[fastLibavcodec state] forKey:@"FastLibavcodecDecoding"];
	
	// deinterlace
	[thePrefs setObject:[NSNumber numberWithInt:[deinterlace indexOfSelectedItem]]
			forKey:@"Deinterlace_r9"];
	
	// postprocessing
	[thePrefs setObject:[NSNumber numberWithInt:[postprocessing indexOfSelectedItem]]
			forKey:@"Postprocessing"];
	
	// skip loopfilter
	[thePrefs setObject:[NSNumber numberWithInt:[skipLoopfilter indexOfSelectedItem]]
			forKey:@"SkipLoopfilter"];
	
	// use ffmpeg-mt
	[thePrefs setBool:[useFFmpegMT state] forKey:@"UseFFmpegMT"];
	
	
	
	// *** Audio
	
	// audio enabled
	[thePrefs setBool:[enableAudio state] forKey:@"EnableAudio"];
	
	// audio codecs
	[thePrefs setObject:[audioCodecs stringValue] forKey:@"AudioCodecs"];
	
	// ac3 passthrough
	[thePrefs setBool:[passthroughAC3 state] forKey:@"PassthroughAC3"];
	
	// dts passthrough
	[thePrefs setBool:[passthroughDTS state] forKey:@"PassthroughDTS"];
	
	// hrtf filter
	[thePrefs setBool:[hrtfFilter state] forKey:@"HRTFFilter"];
	
	// karaoke filter
	[thePrefs setBool:[karaokeFilter state] forKey:@"KaraokeFilter"];
	
	
	
	// *** Advanced
	
	// audio equalizer
	[thePrefs setBool:[equalizerEnabled state] forKey:@"AudioEqualizerEnabled"];
	[thePrefs setObject:[NSArray arrayWithObjects:
			[NSNumber numberWithFloat:[equalizer32 floatValue]],
			[NSNumber numberWithFloat:[equalizer63 floatValue]],
			[NSNumber numberWithFloat:[equalizer125 floatValue]],
			[NSNumber numberWithFloat:[equalizer250 floatValue]],
			[NSNumber numberWithFloat:[equalizer500 floatValue]],
			[NSNumber numberWithFloat:[equalizer1k floatValue]],
			[NSNumber numberWithFloat:[equalizer2k floatValue]],
			[NSNumber numberWithFloat:[equalizer4k floatValue]],
			[NSNumber numberWithFloat:[equalizer8k floatValue]],
			[NSNumber numberWithFloat:[equalizer16k floatValue]],nil]
			forKey:@"AudioEqualizerValues"];
	
	// video equalizer
	[thePrefs setBool:[veEnabled state] forKey:@"VideoEqualizerEnabled"];
	[thePrefs setObject:[NSArray arrayWithObjects:
			[NSNumber numberWithFloat:[veGamma floatValue]],
			[NSNumber numberWithFloat:[veContrast floatValue]],
			[NSNumber numberWithFloat:[veBrightness floatValue]],
			[NSNumber numberWithFloat:[veSaturation floatValue]],
			[NSNumber numberWithFloat:[veGammaRed floatValue]],
			[NSNumber numberWithFloat:[veGammaGreen floatValue]],
			[NSNumber numberWithFloat:[veGammaBlue floatValue]],
			[NSNumber numberWithFloat:[veWeight floatValue]],nil]
			forKey:@"VideoEqualizer"];
	
	// enable additional params
	[thePrefs setBool:[addParamsButton state] forKey:@"EnableAdditionalParams"];
	
	// additional params
	if (![[[addParamsBox stringValue] stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) {
		// get array of parameters
		NSMutableArray *theArray = [NSMutableArray
				arrayWithArray:[addParamsBox objectValues]];
		if ([addParamsBox indexOfItemWithObjectValue:
				[addParamsBox stringValue]] != NSNotFound) {
			// if the entered param exist in the history then remove it from array
			[theArray removeObjectAtIndex:[addParamsBox
					indexOfItemWithObjectValue: [addParamsBox stringValue]]];
		}
		// add parameter at the top of the array
		[theArray insertObject:[addParamsBox stringValue] atIndex:0];
		if ([theArray count] > 10)	// remove last object if there is too much objects
			[theArray removeLastObject];
		// save array to the prefs
		[thePrefs setObject:theArray forKey:@"AdditionalParams"];
	}
	
	
		
	[playerController applyPrefs];
	if ([playerController changesRequireRestart] && ![playerController movieIsSeekable]) {
		NSBeginAlertSheet(
				NSLocalizedString(@"Do you want to restart playback?",nil),
				NSLocalizedString(@"OK",nil),
				NSLocalizedString(@"Later",nil), nil, preferencesPanel, self,
				@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
				NSLocalizedString(@"Some of the changes requires player to restart playback that might take a while.",nil));
	}
	else if ([playerController changesRequireRestart]) {
		if (closeAfterApply)
			[preferencesPanel orderOut:nil];
		[playerController applyChangesWithRestart:YES];
		[playListController applyPrefs];
	}
	else {
		if (closeAfterApply)
			[preferencesPanel orderOut:nil];
		[playListController applyPrefs];
	}
}
/************************************************************************************/
- (IBAction)cancelPrefs:(id)sender
{
	[preferencesPanel orderOut:nil];
}

/************************************************************************************/
- (IBAction)restorePrefs:(id)sender
{
	int result = NSRunAlertPanel(@"Alert", @"You are about to restore default preferences. Are you sure.", @"Cancel", @"Restore", nil);

	if(result == 0)
	{
		system("defaults delete hu.mplayerhq.mplayerosx.extended");
		[Debug log:ASL_LEVEL_WARNING withMessage:@"User Default Deleted"];
		NSRunAlertPanel(@"Alert", @"Default preferences restored, MPlayer OSX will close", @"Done", nil, nil);
		exit(0);
	}
}

/************************************************************************************/
- (IBAction)prefsChanged:(id)sender
{
}
/************************************************************************************/
- (IBAction)enableControls:(id)sender
{
	
	// ** Playback
	
	[checkForPrereleases setEnabled:([checkForUpdates state] == NSOnState)];
	
	// ** Display
	
	// video width box
	if ([[videoSizeMenu titleOfSelectedItem]
			isEqualToString:NSLocalizedString(@"custom:",nil)])
		[videoSizeBox setEnabled:YES];
	else
		[videoSizeBox setEnabled:NO];
	
	// video aspect box
	if ([[videoAspectMenu titleOfSelectedItem]
			isEqualToString:NSLocalizedString(@"custom:",nil)])
		[videoAspectBox setEnabled:YES];
	else
		[videoAspectBox setEnabled:NO];
	
	// fullscreen device
	if ([fullscreenSameAsPlayer state] == NSOffState) {
		[fullscreenDeviceId setEnabled:YES];
		[deviceIdStepper setEnabled:YES];
	} else {
		[fullscreenDeviceId setEnabled:NO];
		[deviceIdStepper setEnabled:NO];
	}
	
	// ** Video
	
	// enable font style menu
	[self initFontStyleMenu];
	
	// enable guess encoding language menu
	[guessLanguage setEnabled:([guessEncoding state] == NSOnState)];
	
	// ** Advanced
	
	// enable audio equalizer
	if ([equalizerEnabled state] != [equalizer32 isEnabled]) {
		[equalizer32 setEnabled:[equalizerEnabled state]];
		[equalizer63 setEnabled:[equalizerEnabled state]];
		[equalizer125 setEnabled:[equalizerEnabled state]];
		[equalizer250 setEnabled:[equalizerEnabled state]];
		[equalizer500 setEnabled:[equalizerEnabled state]];
		[equalizer1k setEnabled:[equalizerEnabled state]];
		[equalizer2k setEnabled:[equalizerEnabled state]];
		[equalizer4k setEnabled:[equalizerEnabled state]];
		[equalizer8k setEnabled:[equalizerEnabled state]];
		[equalizer16k setEnabled:[equalizerEnabled state]];
	}
	
	// enable audio equalizer
	if ([veEnabled state] != [veGamma isEnabled]) {
		[veGamma setEnabled:[veEnabled state]];
		[veContrast setEnabled:[veEnabled state]];
		[veBrightness setEnabled:[veEnabled state]];
		[veSaturation setEnabled:[veEnabled state]];
		[veGammaRed setEnabled:[veEnabled state]];
		[veGammaGreen setEnabled:[veEnabled state]];
		[veGammaBlue setEnabled:[veEnabled state]];
		[veWeight setEnabled:[veEnabled state]];
	}
	
	// enable additionals params box
	if ([addParamsButton state] == NSOnState)
		[addParamsBox setEnabled:YES];
	else
		[addParamsBox setEnabled:NO];
	
	// if initiated by control then let the action continue
	if (sender)
		[self prefsChanged:sender];
}
/************************************************************************************/
- (IBAction)cacheSizeChanged:(id)sender
{
	if ([sender floatValue] > 0)
		[cacheSizeBox setStringValue:[NSString stringWithFormat:@"%.1fMB", [sender floatValue]]];
	else
		[cacheSizeBox setStringValue:@""];
}
/************************************************************************************/
- (IBAction)resetEqualizer:(id)sender
{
	[equalizer32 setFloatValue: 0.0];
	[equalizer63 setFloatValue: 0.0];
	[equalizer125 setFloatValue: 0.0];
	[equalizer250 setFloatValue: 0.0];
	[equalizer500 setFloatValue: 0.0];
	[equalizer1k setFloatValue: 0.0];
	[equalizer2k setFloatValue: 0.0];
	[equalizer4k setFloatValue: 0.0];
	[equalizer8k setFloatValue: 0.0];
	[equalizer16k setFloatValue: 0.0];
}
/************************************************************************************/
- (IBAction)resetVideoEqualizer:(id)sender
{
	[veGamma setFloatValue: 10.0];
	[veContrast setFloatValue: 1.0];
	[veBrightness setFloatValue: 0.0];
	[veSaturation setFloatValue: 1.0];
	[veGammaRed setFloatValue: 10.0];
	[veGammaGreen setFloatValue: 10.0];
	[veGammaBlue setFloatValue: 10.0];
	[veWeight setFloatValue: 1.0];
}
/************************************************************************************/
- (IBAction)videoDeviceStepper:(id)sender
{
	if ([sender intValue] > 0 || [fullscreenDeviceId intValue] > 0)
		[fullscreenDeviceId setIntValue: [fullscreenDeviceId intValue] + [sender intValue]];
	[sender setIntValue:0];
}
/************************************************************************************
 DELEGATE METHODS
 ************************************************************************************/
- (void) sheetDidEnd:(NSWindow *)sheet
		returnCode:(int)returnCode
		contextInfo:(void *)contextInfo
{
	if (closeAfterApply)
		[preferencesPanel orderOut:nil];

	if (returnCode == NSAlertDefaultReturn)
		[playerController applyChangesWithRestart:YES];
	else
		[playerController applyChangesWithRestart:NO];
	
	[playListController applyPrefs];	
}

- (void) dealloc
{
	[fonts release];
	[guessCodes release];
	[super dealloc];
}

@end
