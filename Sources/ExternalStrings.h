/*
 *  ExternalStrings.h
 *  MPlayer OS X
 *
 *	This file is not supposed to be imported, it's only for information about used strings
 *
 *  Created by Jan Volf on Wed Feb 26 2003.
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 *
 */

// Info dictionary keys
	//	@"ApplicationDefaults"	// factory defaults key

// Preferences keys
	//	@"PathToPlayer"			NSString - relative to bundle resources
	//	@"LastTrack"			NSNumber int - index
	//	@"LastAudioVolume"		NSNumber double - value of NSSlider
	//	@"PlayMode"				NSNumber int	- 
	//	@"MinimizedWindow"		NSString bool	- whether the window was minimized on quit
	
	//	@"SmallPlaylistText"	// string bool
	//	@"RememberPosition"		// string bool
	//	@"VideoFrameSize"		// number index
	//	@"VideoFrameWidth"		// number integer
	//	@"VideoAspectRatio"		// number index
	//	@"FullscreenByDefault"	// string bool
	//	@"DropFrames"			// string bool
	//	@"SubtitlesFontPath"	// string path
	//	@"SubtitlesEncoding"	// string name
	//	@"SubtitlesSize"		// number index
	//	@"CacheSize"			// number megabytes
	//	@"EnableAdditionalParams"	// string bool
	//	@"AdditionalParams"		// string

// play list item pasteboard type (for draging inside table)
	//	@"PlaylistSelectionEnumeratorType"	
		
// File type names
	//	@"Movie file"			NSString - path to file
	//	@"Audio file"			NSString - path to file
	//	@"Subtitles file"		NSString - path to file

// Playlist item dictionary keys
	//	@"ItemTitle"
	// file paths
		//	@"MovieFile"
		//	@"SubtitlesFile"
		//	@"AudioFile"
	// options
		//	@"RebuildIndex"
		//	@"SubtitlesEncoding"
		//	@"DisableAudio"
	// misc 
		//	@"LastSeconds"
	
// Notifications
// custom NSApp notification (sent from applicationShouldTerminate delegate method)
	//	@"ApplicationShouldTerminateNotification"
