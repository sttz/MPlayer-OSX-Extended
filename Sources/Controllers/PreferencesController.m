/*
 *  PreferencesController.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "PreferencesController.h"

// other controllers
#import "AppController.h"
#import "PlayerController.h"
#import "LanguageCodes.h"

@implementation PreferencesController

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
	
	// correct pts
	if ([thePrefs objectForKey:@"CorrectPTS"])
		[correctPts setState:[thePrefs boolForKey:@"CorrectPTS"]];
	
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
		[videoAspectBox setFloatValue:[[thePrefs
				objectForKey:@"CustomVideoAspect"] floatValue]];
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
	if ([thePrefs objectForKey:@"Deinterlace"])
		[deinterlace setSelectedSegment: [thePrefs integerForKey:@"Deinterlace"]];
	else
		[deinterlace setSelectedSegment: 0];
	
	// postprocessing
	if ([thePrefs objectForKey:@"Postprocessing"])
		[postprocessing setSelectedSegment: [thePrefs integerForKey:@"Postprocessing"]];
	else
		[postprocessing setSelectedSegment: 0];
	
	// ass subtitles
	if ([thePrefs objectForKey:@"ASSSubtitles"])
		[assSubtitles setState:[thePrefs boolForKey:@"ASSSubtitles"]];
	
	// embedded fonts
	if ([thePrefs objectForKey:@"EmbeddedFonts"])
		[embeddedFonts setState:[thePrefs boolForKey:@"EmbeddedFonts"]];
	
	// create fonts menu
	[self initFontMenu];
	
	// subtitles font
	if ([thePrefs objectForKey:@"SubtitlesFontName"]) {
		//[subFontMenu selectItemAtIndex:[subFontMenu indexOfItemWithRepresentedObject:
		//		[thePrefs objectForKey:@"SubtitlesFontPath"]]];
		[subFontMenu selectItemAtIndex:[subFontMenu indexOfItemWithTitle:
		 		[thePrefs objectForKey:@"SubtitlesFontName"]]];
		if ([subFontMenu indexOfSelectedItem] < 0)
			[subFontMenu selectItemAtIndex:0];
	}
	else
		[subFontMenu selectItemAtIndex:0];
		
	// subtitles encoding
	if ([thePrefs objectForKey:@"SubtitlesEncoding"]) {
		[subEncodingMenu selectItemWithTitle:[thePrefs objectForKey:@"SubtitlesEncoding"]];
		if ([subEncodingMenu indexOfSelectedItem] < 0)
			[subEncodingMenu selectItemAtIndex:0];
		}
	else
		[subEncodingMenu selectItemAtIndex:0];
	
	// subtitles size
	if ([thePrefs objectForKey:@"SubtitlesScale"])
		[subSizeBox setIntValue:
				[[thePrefs objectForKey:@"SubtitlesScale"] intValue]];
	else
		[subSizeBox setIntValue:100];
	
	// subtitle color
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES]; 
	if ([thePrefs objectForKey:@"SubtitlesColor"])
		[subColorWell setColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[thePrefs objectForKey:@"SubtitlesColor"]]];
	else
		[subColorWell setColor:[NSColor whiteColor]];
	
	// ass at the beginning of filter chain
	if ([thePrefs objectForKey:@"ASSPreFilter"])
		[assPreFilter setState:[thePrefs boolForKey:@"ASSPreFilter"]];
	
	
	
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
- (void) initFontMenu
{
	NSArray *paths;
	NSArray *fontLibrary;
	NSEnumerator *pathsEnum;
	NSString *path;
	int count = 0;

	// clear menu
	[subFontMenu removeAllItems];
	
	// add first item - none and separator
	[subFontMenu addItemWithTitle:NSLocalizedString(@"none",nil)];
	[[subFontMenu lastItem] setTag:0];
	[[subFontMenu menu] addItem:[NSMenuItem separatorItem]];

	// get paths for system dir fonts
	fontLibrary = [NSArray arrayWithObjects:	@"/Library/Fonts",
												[[NSString stringWithString:@"~/Library/Fonts"] stringByExpandingTildeInPath],
												[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Fonts"],nil];

	for(count=0; count<[fontLibrary count]; count++)
	{
		NSString *fontPath = [fontLibrary objectAtIndex:count];
		paths = [[NSFileManager defaultManager] subpathsAtPath:fontPath];
		pathsEnum = [paths objectEnumerator];
		while (path = [pathsEnum nextObject])
		{
			if ([[path pathExtension] caseInsensitiveCompare:@"ttf"] == NSOrderedSame)
			{
				[subFontMenu addItemWithTitle:[[path lastPathComponent] stringByDeletingPathExtension]];
				[[subFontMenu lastItem] setTag:1];
				//[[subFontMenu lastItem] setRepresentedObject:[fontPath stringByAppendingPathComponent:path]];
			}
			/*else if ([[path lastPathComponent] caseInsensitiveCompare:@"font.desc"] == NSOrderedSame)
			{
				[subFontMenu addItemWithTitle:[path stringByDeletingLastPathComponent]];
				[[subFontMenu lastItem] setTag:2];
				//[[subFontMenu lastItem] setRepresentedObject:path];
			}*/
		}
		
		// if last item is not separator then add it
		if (![[subFontMenu lastItem] isSeparatorItem])
			[[subFontMenu menu] addItem:[NSMenuItem separatorItem]];
	}

	// remove separator if it is last item
	if ([[subFontMenu lastItem] isSeparatorItem])
		[subFontMenu removeItemAtIndex:[subFontMenu numberOfItems]-1];
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
	
	[thePrefs setObject:@"ext6" forKey:@"Version"];
	
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
	
	// correct pts
	[thePrefs setBool:[correctPts state] forKey:@"CorrectPTS"];
	
	// cache size
	[thePrefs setObject:[NSNumber numberWithFloat:[cacheSizeSlider floatValue]]
			forKey:@"CacheSize"];
	
	// enable additional params
	[thePrefs setBool:[addParamsButton state] forKey:@"EnableAdditionalParams"];
	
	
	
	// *** Display
	
	// display type
	[thePrefs setObject:[NSNumber numberWithInt:[[displayType selectedCell] tag]]
			forKey:@"DisplayType"];
	
	// flip vertical
	[thePrefs setBool:[flipVertical state] forKey:@"FlipVertical"];
	//[thePrefs setBool:[[NSNumber numberWithInt: [flipVertical state]] boolValue] forKey:@"FlipVertical"];
	
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
	[thePrefs setObject:[NSNumber numberWithFloat:[videoAspectBox floatValue]]
			forKey:@"CustomVideoAspect"];
	
	// fullscreen device id
	[thePrefs setBool:[fullscreenSameAsPlayer state] forKey:@"FullscreenDeviceSameAsPlayer"];
	
	if ([fullscreenDeviceId intValue] >= 0)
		[thePrefs setObject:[NSNumber numberWithInt:[fullscreenDeviceId intValue]]
				forKey:@"FullscreenDevice"];
	else
		[thePrefs setObject:[NSNumber numberWithInt:0] forKey:@"FullscreenDevice"];
	
	// video out module
	[thePrefs setObject:[NSNumber numberWithInt:[videoDriverMenu indexOfSelectedItem]]
			forKey:@"VideoDriver"];
	
	// screenshots
	[thePrefs setObject:[NSNumber numberWithInt:[screenshots indexOfSelectedItem]]
			forKey:@"Screenshots"];
	
	
	
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
			forKey:@"Deinterlace"];
	
	// postprocessing
	[thePrefs setObject:[NSNumber numberWithInt:[postprocessing indexOfSelectedItem]]
			forKey:@"Postprocessing"];
	
	// ass subtitles
	[thePrefs setBool:[assSubtitles state] forKey:@"ASSSubtitles"];
	
	// embedded fonts
	[thePrefs setBool:[embeddedFonts state] forKey:@"EmbeddedFonts"];
	
	// subtitles font
	if ([subFontMenu indexOfSelectedItem] <= 0)
		[thePrefs removeObjectForKey:@"SubtitlesFontName"];
	else
		[thePrefs setObject:[subFontMenu titleOfSelectedItem] forKey:@"SubtitlesFontName"];
		//[thePrefs setObject:[[subFontMenu selectedItem] representedObject] forKey:@"SubtitlesFontPath"];
	
	// subtitles encoding
	[thePrefs setObject:[subEncodingMenu titleOfSelectedItem]
			forKey:@"SubtitlesEncoding"];
	
	// subtitles size
	[thePrefs setObject:[NSNumber numberWithInt:[subSizeBox intValue]]
			forKey:@"SubtitlesScale"];
	
	// subtitle color
	NSData *color = [NSArchiver archivedDataWithRootObject:[[subColorWell color] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]];
	[thePrefs setObject:color forKey:@"SubtitlesColor"];
	
	// ass pre filter
	[thePrefs setBool:[assPreFilter state] forKey:@"ASSPreFilter"];
	
	
	
	// *** Audio
	
	// audio enabled
	[thePrefs setBool:[enableAudio state] forKey:@"EnableAudio"];
	
	// audio codecs
	[thePrefs setObject:[audioCodecs stringValue] forKey:@"AudioCodecs"];
	
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
		system("defaults delete hu.mplayerhq.mplayerosx");
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
	
	// enable subtitles settings deppending on selected font
	/*switch ([[subFontMenu selectedItem] tag]) {
	case 1 : // truetype font
		[subSizeMenu setEnabled:YES];
		[subEncodingMenu setEnabled:YES];
		break;
	default : // pre-rendered fonts and none
		[subSizeMenu setEnabled:NO];
		[subEncodingMenu setEnabled:NO];
		break;
	}*/
	
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

@end
