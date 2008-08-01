/*
 *  SettingsController.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "SettingsController.h"

// other controllers
#import "AppController.h"
#import "PlayerController.h"
#import "PlayListController.h"

@implementation SettingsController

/************************************************************************************
 INTERFACE
 ************************************************************************************/
- (void) displayForItem:(NSMutableDictionary *)anItem
{
	myItem = [anItem retain];
	
	// load values from myItem
	[self reloadValues];
	
	// display dialog
	[settingsPanel makeKeyAndOrderFront:nil];
}
/************************************************************************************/
- (BOOL) isVisible
{
	return [settingsPanel isVisible];
}

/************************************************************************************
 MISC
 ************************************************************************************/
- (void) reloadValues
{
	NSMutableString *theString = [NSMutableString string];
	
	// setings options
	// title of playlits item
	if ([myItem objectForKey:@"ItemTitle"])
		[titleBox setStringValue:[myItem objectForKey:@"ItemTitle"]];
	else
		[titleBox setStringValue:@""];
	
	// subtitles file path
	if ([myItem objectForKey:@"SubtitlesFile"])
		[subtitlesBox setStringValue:[myItem objectForKey:@"SubtitlesFile"]];
	else
		[subtitlesBox setStringValue:@""];
	
	// audio file path
	if ([myItem objectForKey:@"AudioFile"])
		[audioBox setStringValue:[myItem objectForKey:@"AudioFile"]];
	else
		[audioBox setStringValue:@""];
		
//		// audio file path
//	if ([myItem objectForKey:@"AudioExportFile"])
//		[audioExportBox setStringValue:[myItem objectForKey:@"AudioExportFile"]];
//	else
//		[audioExportBox setStringValue:@""];
		
		
		
//	//newstuff
//		// subtitles file path
//	if ([myItem objectForKey:@"MovieExportFile"])
///		[movieExportBox setStringValue:[myItem objectForKey:@"MovieExportFile"]];
//   else
	//	[movieExportBox setStringValue:@""];
	
	// audio export
	
	
	// rebuild index option
	if ([myItem objectForKey:@"RebuildIndex"]) {
		if ([[myItem objectForKey:@"RebuildIndex"] isEqualToString:@"YES"])
			[rebuildIndexButton setState:NSOnState];
		else
			[rebuildIndexButton setState:NSOffState];
	}
	else
		[rebuildIndexButton setState:NSOffState];
	
	// subtitles encoding menu
	if ([myItem objectForKey:@"SubtitlesEncoding"]) {
		[encodingMenu selectItemWithTitle:[myItem objectForKey:@"SubtitlesEncoding"]];
		if ([encodingMenu indexOfSelectedItem] < 0)
			[encodingMenu selectItemWithTitle:NSLocalizedString(@"default",nil)];
		}
	else
		[encodingMenu selectItemWithTitle:NSLocalizedString(@"default",nil)];
	
	// info strings
	// file format
	if ([myItem objectForKey:@"ID_FILE_FORMAT"])
		[fileFormatBox setStringValue:[myItem objectForKey:@"ID_FILE_FORMAT"]];
	else
		[fileFormatBox setStringValue:NSLocalizedString(@"N/A",nil)];
	
	// movie file path
	if ([myItem objectForKey:@"MovieFile"])
		[movieFileBox setStringValue:[myItem objectForKey:@"MovieFile"]];
	
	// video format string
	[theString setString:@""];
	if ([myItem objectForKey:@"ID_VIDEO_FORMAT"]) {
		[theString appendString:[myItem objectForKey:@"ID_VIDEO_FORMAT"]];
		[theString appendString:@", "];
	}
	if ([myItem objectForKey:@"ID_VIDEO_BITRATE"]) {
		[theString appendString:
				[NSString stringWithFormat:@"%3.1f kbps",
						([[myItem objectForKey:@"ID_VIDEO_BITRATE"] floatValue]/1000)]];
		[theString appendString:@", "];
	}
	if ([myItem objectForKey:@"ID_VIDEO_WIDTH"] && [myItem objectForKey:@"ID_VIDEO_HEIGHT"]) {
		[theString appendString:[myItem objectForKey:@"ID_VIDEO_WIDTH"]];
		[theString appendString:@" x "];
		[theString appendString:[myItem objectForKey:@"ID_VIDEO_HEIGHT"]];
		[theString appendString:@", "];
	}
	if ([myItem objectForKey:@"ID_VIDEO_FPS"]) {
		[theString appendString:[NSString
				stringWithFormat:@"%2.1f fps",
					[[myItem objectForKey:@"ID_VIDEO_FPS"] floatValue]]];
		[theString appendString:@", "];
	}
	if ([theString length] > 0)
		[videoFormatBox setStringValue:[theString
				substringWithRange:NSMakeRange(0,[theString length]-2)]];
	else
		[videoFormatBox setStringValue:@"N/A"];
	
	// audio format string
	[theString setString:@""];
	if ([myItem objectForKey:@"ID_AUDIO_CODEC"]) {
		[theString appendString:[myItem objectForKey:@"ID_AUDIO_CODEC"]];
		[theString appendString:@", "];
	}
	if ([myItem objectForKey:@"ID_AUDIO_BITRATE"]) {
		[theString appendString:
				[NSString stringWithFormat:@"%d kbps",
						([[myItem objectForKey:@"ID_AUDIO_BITRATE"] intValue]/1000)]];
		[theString appendString:@", "];
	}
	if ([myItem objectForKey:@"ID_AUDIO_RATE"]) {
		[theString appendString:
				[NSString stringWithFormat:@"%2.1f kHz",
						([[myItem objectForKey:@"ID_AUDIO_RATE"] floatValue]/1000)]];
		[theString appendString:@", "];
	}
	if ([myItem objectForKey:@"ID_AUDIO_NCH"]) {
		int myInt = [[myItem objectForKey:@"ID_AUDIO_NCH"] intValue];
		switch (myInt) {
		case 1 :
			[theString appendString:@"Mono"];
			break;
		case 2 :
			[theString appendString:@"Stereo"];
			break;
		default :
			[theString appendString:[NSString stringWithFormat:@"%d chanels",myInt]];
			break;
		}
		[theString appendString:@", "];
	}
	if ([theString length] > 0)
		[audioFormatBox setStringValue:[theString
				substringWithRange:NSMakeRange(0,[theString length]-2)]];
	else
		[audioFormatBox setStringValue:@"N/A"];
	
	// length string
	if ([myItem objectForKey:@"ID_LENGTH"]) {
		int seconds = [[myItem objectForKey:@"ID_LENGTH"] intValue];
		[lengthBox setStringValue:[NSString stringWithFormat:@"%01d:%02d:%02d",
				seconds/3600,(seconds%3600)/60,seconds%60]];
	}
	else
		[lengthBox setStringValue:@"N/A"];
}

/************************************************************************************
 ACTIONS
 ************************************************************************************/
- (IBAction)applySettings:(id)sender
{
	// save settings
	if (![[titleBox stringValue] isEqualToString:@""])
		[myItem setObject:[titleBox stringValue] forKey:@"ItemTitle"];
	else
		[myItem removeObjectForKey:@"ItemTitle"];
	
	if (![[subtitlesBox stringValue] isEqualToString:@""])
		[myItem setObject:[subtitlesBox stringValue] forKey:@"SubtitlesFile"];
	else
		[myItem removeObjectForKey:@"SubtitlesFile"];
	
	if (![[audioBox stringValue] isEqualToString:@""])
		[myItem setObject:[audioBox stringValue] forKey:@"AudioFile"];
	else
		[myItem removeObjectForKey:@"AudioFile"];
		
	//newstuff
//		if (![[movieExportBox stringValue] isEqualToString:@""])
//		[myItem setObject:[movieExportBox stringValue] forKey:@"MovieExportFile"];
//	else
//		[myItem removeObjectForKey:@"MovieExportFile"];
	
//	if (![[audioExportBox stringValue] isEqualToString:@""])
///		[myItem setObject:[audioExportBox stringValue] forKey:@"AudioExportFile"];
//	else
//		[myItem removeObjectForKey:@"AudioExportFile"];
	
	
	
	if ([rebuildIndexButton state] == NSOnState)
		[myItem setObject:@"YES" forKey:@"RebuildIndex"];
	else
		[myItem setObject:@"NO" forKey:@"RebuildIndex"];
	
	if ([[encodingMenu titleOfSelectedItem] isEqualToString:
			NSLocalizedString(@"default",nil)])
		[myItem removeObjectForKey:@"SubtitlesEncoding"];
	else
		[myItem setObject:[encodingMenu titleOfSelectedItem] forKey:@"SubtitlesEncoding"];
	
	// item will no longer be needed
	[myItem release];

	// applay settings to mplayer
	if ([playerController playingItem] == myItem) {
		[playerController applySettings];
		if ([playerController changesRequireRestart]) {
			NSBeginAlertSheet(
					NSLocalizedString(@"Do you want to restart playback?",nil),
					NSLocalizedString(@"OK",nil),
					NSLocalizedString(@"Later",nil), nil, settingsPanel, self,
					@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
					NSLocalizedString(@"Some of the changes requires player to restart playback that might take a while.",nil));
			return;
		}
	}

	// hide panel	
	[settingsPanel orderOut:nil];
	
	[playListController updateView];
}
/************************************************************************************/
- (IBAction)cancelSettings:(id)sender
{
	[settingsPanel orderOut:nil];
	[playListController updateView];
	[myItem release];
}
/************************************************************************************/
- (IBAction)chooseAudio:(id)sender
{
	NSString *newPath = [appController
			openDialogForTypes:[appController typeExtensionsForName:@"Audio file"]];
	if (newPath)
		[audioBox setStringValue:newPath];
}
/************************************************************************************/
- (IBAction)chooseSubtitles:(id)sender
{
	NSString *newPath = [appController
			openDialogForTypes:[appController typeExtensionsForName:@"Subtitles file"]];
	if (newPath)
		[subtitlesBox setStringValue:newPath];
}
/************************************************************************************/
- (IBAction)removeAudio:(id)sender
{
	[audioBox setStringValue:@""];
}
/************************************************************************************/
- (IBAction)removeSubtitles:(id)sender
{
	[subtitlesBox setStringValue:@""];
}


//newstuff
/**********************************************AudioExportFile**************/
//- (IBAction)chooseAudioExport:(id)sender
//{
//	NSString *newPath = [appController
///			saveDialogForTypes:[appController typeExtensionsForName:@"AudioExportFile"]];
//	if (newPath)
//		[audioExportBox setStringValue:newPath];
//}
/************************************************************************************/
/************************************************************************************/
//- (IBAction)removeAudioExport:(id)sender
//{
//	[audioExportBox setStringValue:@""];
//}
/************************************************************************************/






/************************************************************************************
 DELEGATE METHODS
 ************************************************************************************/
- (void) sheetDidEnd:(NSWindow *)sheet
		returnCode:(int)returnCode
		contextInfo:(void *)contextInfo
{
	// hide panel	
	[settingsPanel orderOut:nil];

	if (returnCode == NSAlertDefaultReturn)
		[playerController applyChangesWithRestart:YES];
	else
		[playerController applyChangesWithRestart:NO];
		
	[playListController updateView];
}

@end
