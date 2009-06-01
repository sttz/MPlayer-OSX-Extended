/*
 *  PreferencesController.h
 *  MPlayer OS X
 *
 *	Description:
 *		It's controller forPreferences dialog
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import <Cocoa/Cocoa.h>
#import "Debug.h"

@interface PreferencesController : NSObject
{
	// controller outlets
	IBOutlet id appController;
	IBOutlet id playListController;
	IBOutlet id playerController;
	
	// GUI outlets
	IBOutlet NSPanel *preferencesPanel;
	IBOutlet NSWindow *fcWindow;
	IBOutlet NSProgressIndicator *fcProgress;
	
	// ** Playback
	// Languages
	IBOutlet id audioLanguages;
	IBOutlet id subtitleLanguages;
	// Playlist
	IBOutlet id playlistOnStartup;
	IBOutlet id playlistSmallText;
	IBOutlet id playlistRemember;
	// Misc
	IBOutlet id cacheSizeSlider;
	IBOutlet id cacheSizeBox;
	// Updates
	IBOutlet id checkForUpdates;
	IBOutlet id checkForPrereleases;
	
	// ** Display
	// Display
	IBOutlet id displayType;
	// Transform
	IBOutlet id flipVertical;
	IBOutlet id flipHorizontal;
	IBOutlet id videoSizeMenu;
	IBOutlet id videoSizeBox;
	IBOutlet id videoAspectMenu;
	IBOutlet id videoAspectBox;
	// Output
	IBOutlet id fullscreenSameAsPlayer;
	IBOutlet id fullscreenDeviceId;
	IBOutlet id blackoutScreens;
	IBOutlet id deviceIdStepper;
	IBOutlet id videoDriverMenu;
	IBOutlet id screenshots;
	// Interace
	IBOutlet id animateInterface;
	
	// ** Text
	// General
	IBOutlet id subFontMenu;
	IBOutlet id subStyleMenu;
	IBOutlet id subEncodingMenu;
	IBOutlet id guessEncoding;
	IBOutlet id guessLanguage;
	// Subtitles
	IBOutlet id assSubtitles;
	IBOutlet id subSizeBox;
	// ASS
	IBOutlet id embeddedFonts;
	IBOutlet id assPreFilter;
	IBOutlet id subColorWell;
	IBOutlet id subBorderColorWell;
	// OSD
	IBOutlet id osdLevel;
	IBOutlet id osdScale;
	
	
	// ** Video
	// General
	IBOutlet id enableVideo;
	IBOutlet id videoCodecs;
	// Decoding
	IBOutlet id framedrop;
	IBOutlet id fastLibavcodec;
	IBOutlet id useFFmpegMT;
	IBOutlet id skipLoopfilter;
	// Filters
	IBOutlet id deinterlace;
	IBOutlet id postprocessing;
	
	
	// ** Audio
	// General
	IBOutlet id enableAudio;
	IBOutlet id audioCodecs;
	// Output
	IBOutlet id passthroughAC3;
	IBOutlet id passthroughDTS;
	// Filters
	IBOutlet id hrtfFilter;
	IBOutlet id bs2bFilter;
	IBOutlet id karaokeFilter;
	
	// *** Advanced
	// Audio Equalizer
	IBOutlet id equalizer32;
	IBOutlet id equalizer63;
	IBOutlet id equalizer125;
	IBOutlet id equalizer250;
	IBOutlet id equalizer500;
	IBOutlet id equalizer1k;
	IBOutlet id equalizer2k;
	IBOutlet id equalizer4k;
	IBOutlet id equalizer8k;
	IBOutlet id equalizer16k;
	IBOutlet id equalizerReset;
	IBOutlet id equalizerEnabled;
	// Video Equalizer
	IBOutlet id veGamma;
	IBOutlet id veContrast;
	IBOutlet id veBrightness;
	IBOutlet id veSaturation;
	IBOutlet id veGammaRed;
	IBOutlet id veGammaGreen;
	IBOutlet id veGammaBlue;
	IBOutlet id veWeight;
	IBOutlet id veReset;
	IBOutlet id veEnabled;
	// Additional parameters
	IBOutlet id addParamsButton;
	IBOutlet id addParamsBox;
	
	BOOL closeAfterApply;
	NSMutableDictionary *fonts;
	NSArray *guessCodes;
	
}
// misc
- (void) reloadValues;
- (void) initFontStyleMenu;
- (void) loadFonts;

// actions
- (IBAction)displayPreferences:(id)sender;
- (IBAction)applyPrefs:(id)sender;
- (IBAction)applyAndClose:(id)sender;
- (IBAction)cancelPrefs:(id)sender;
- (IBAction)restorePrefs:(id)sender;
- (IBAction)prefsChanged:(id)sender;
- (IBAction)enableControls:(id)sender;
- (IBAction)cacheSizeChanged:(id)sender;
- (IBAction)resetEqualizer:(id)sender;
- (IBAction)resetVideoEqualizer:(id)sender;
- (IBAction)videoDeviceStepper:(id)sender;


// delegate methods
- (void) sheetDidEnd:(NSWindow *)sheet
		returnCode:(int)returnCode
		contextInfo:(void *)contextInfo;
@end
