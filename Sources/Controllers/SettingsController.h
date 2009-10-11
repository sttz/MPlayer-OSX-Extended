/*
 *  SettingsController.h
 *  MPlayer OS X
 *
 *	Description:
 *		It's controller for Info dialog
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import <Cocoa/Cocoa.h>

@interface SettingsController : NSObject
{
	// controller outlets
	IBOutlet id appController;
    IBOutlet id playerController;
	IBOutlet id playListController;
	
    // UI outlets
	IBOutlet id settingsPanel;
	IBOutlet id audioBox;
	// new stuff BETA
//	IBOutlet id audioExportBox;
//	IBOutlet id movieExportBox;

	
    IBOutlet NSPopUpButton *encodingMenu;
    IBOutlet id rebuildIndexButton;
    IBOutlet id subtitlesBox;
    IBOutlet id titleBox;
    IBOutlet id movieFileBox;
    IBOutlet id fileFormatBox;
	IBOutlet id videoFormatBox;
	IBOutlet id audioFormatBox;
	IBOutlet id lengthBox;
	
	// properties
	NSMutableDictionary *myItem;
}
// interface
- (void) displayForItem:(NSMutableDictionary *)anItem;
- (BOOL) isVisible;
// misc
- (void) reloadValues;
// actions
- (IBAction)applySettings:(id)sender;
- (IBAction)cancelSettings:(id)sender;
- (IBAction)chooseAudio:(id)sender;
- (IBAction)chooseSubtitles:(id)sender;
- (IBAction)removeAudio:(id)sender;
- (IBAction)removeSubtitles:(id)sender;
//new stuff
//- (IBAction)chooseAudioExport:(id)sender;  ///-ao pcm -aofile
//- (IBAction)chooseVideoExport:(id)sender;
//- (IBAction)removeAudioExport:(id)sender;
//- (IBAction)removeVideoExport:(id)sender;

// delegate methods
- (void) sheetDidEnd:(NSWindow *)sheet
		returnCode:(int)returnCode
		contextInfo:(void *)contextInfo;
@end
