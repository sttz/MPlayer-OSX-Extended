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
	[myItem release];
	myItem = [anItem retain];
	
	// load values from myItem
	[self reloadValues];
	
	// display dialog
	[settingsPanel makeKeyAndOrderFront:nil];
}
/************************************************************************************/
- (void) dealloc
{
	[myItem release];
	
	[super dealloc];
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
	MovieInfo *info = [MovieInfo fromDictionary:myItem];
	
	// file format
	if ([info fileFormat])
		[fileFormatBox setStringValue:[info fileFormat]];
	else
		[fileFormatBox setStringValue:NSLocalizedString(@"N/A",nil)];
	
	// movie file path
	if ([info filename])
		[movieFileBox setStringValue:[info filename]];
	
	// video format string
	[theString setString:@""];
	if ([info videoForamt]) {
		[theString appendString:[info videoForamt]];
		[theString appendString:@", "];
	}
	if ([info videoBitrate] > 0) {
		[theString appendString:
				[NSString stringWithFormat:@"%3.1f kbps",
						([info videoBitrate]/1000)]];
		[theString appendString:@", "];
	}
	if ([info videoWidth] > 0 && [info videoHeight] > 0) {
		[theString appendString:[NSString stringWithFormat:@"%i",[info videoWidth]]];
		[theString appendString:@" x "];
		[theString appendString:[NSString stringWithFormat:@"%i",[info videoHeight]]];
		[theString appendString:@", "];
	}
	if ([info videoFps] > 0) {
		[theString appendString:[NSString
				stringWithFormat:@"%2.1f fps",
					[info videoFps]]];
		[theString appendString:@", "];
	}
	if ([theString length] > 0)
		[videoFormatBox setStringValue:[theString
				substringWithRange:NSMakeRange(0,[theString length]-2)]];
	else
		[videoFormatBox setStringValue:@"N/A"];
	
	// audio format string
	[theString setString:@""];
	if ([info audioCodec]) {
		[theString appendString:[info audioCodec]];
		[theString appendString:@", "];
	}
	if ([info audioBitrate] > 0) {
		[theString appendString:
				[NSString stringWithFormat:@"%d kbps",
						([info audioBitrate]/1000)]];
		[theString appendString:@", "];
	}
	if ([info audioSampleRate] > 0) {
		[theString appendString:
				[NSString stringWithFormat:@"%2.1f kHz",
						([info audioSampleRate]/1000)]];
		[theString appendString:@", "];
	}
	if ([info audioChannels]) {
		switch ([info audioChannels]) {
		case 1 :
			[theString appendString:@"Mono"];
			break;
		case 2 :
			[theString appendString:@"Stereo"];
			break;
		default :
			[theString appendString:[NSString stringWithFormat:@"%d chanels",[info audioChannels]]];
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
	if ([info length] > 0) {
		[lengthBox setStringValue:[NSString stringWithFormat:@"%01d:%02d:%02d",
				[info length]/3600,([info length]%3600)/60,[info length]%60]];
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
	NSString *newPath = [[AppController sharedController] openDialogForType:MP_DIALOG_AUDIO];
	if (newPath)
		[audioBox setStringValue:newPath];
}
/************************************************************************************/
- (IBAction)chooseSubtitles:(id)sender
{
	NSString *newPath = [[AppController sharedController] openDialogForType:MP_DIALOG_SUBTITLES];
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
//	NSString *newPath = [[AppController sharedController]
///			saveDialogForTypes:[[AppController sharedController] typeExtensionsForName:@"AudioExportFile"]];
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
