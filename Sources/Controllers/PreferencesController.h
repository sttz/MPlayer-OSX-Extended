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
	
	// ** Playback
	// Languages
	IBOutlet id audioLanguages;
	IBOutlet id subtitleLanguages;
	// Playlist
	IBOutlet id playlistOnStartup;
	IBOutlet id playlistSmallText;
	IBOutlet id playlistRemember;
	// Misc
	IBOutlet id correctPts;
	IBOutlet id cacheSizeSlider;
	IBOutlet id cacheSizeBox;
	
	// ** Video
	// General
	IBOutlet id enableVideo;
	IBOutlet id videoCodecs;
	// Decoding
	IBOutlet id framedrop;
	IBOutlet id fastLibavcodec;
	// Filters
	IBOutlet id deinterlace;
	IBOutlet id postprocessing;
	// Subtitles
	IBOutlet id assSubtitles;
	IBOutlet id embeddedFonts;
	IBOutlet id subFontMenu;
	IBOutlet id subEncodingMenu;
	IBOutlet id subSizeBox;
	
	// ** Audio
	// General
	IBOutlet id enableAudio;
	IBOutlet id audioCodecs;
	// Filters
	IBOutlet id hrtfFilter;
	IBOutlet id karaokeFilter;
	
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
	IBOutlet id deviceIdStepper;
	IBOutlet id videoDriverMenu;
	IBOutlet id screenshots;
	IBOutlet id assPreFilter;
	
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
	
	
}
// misc
- (void) reloadValues;
- (void) initFontMenu;

// actions
- (IBAction)displayPreferences:(id)sender;
- (IBAction)applyPrefs:(id)sender;
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
