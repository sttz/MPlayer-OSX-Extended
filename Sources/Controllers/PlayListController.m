/*
 *  PlayListCtrllr.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */
#import "PlayListController.h"

// other controllers
#import "PlayerController.h"
#import "AppController.h"

#import "ScrubbingBar.h"
#import "MovieInfo.h"
#import "Preferences.h"
#import "CocoaAdditions.h"

static void addToolbarItem(NSMutableDictionary *theDict,NSString *identifier,NSString *label,NSString *paletteLabel,NSString *toolTip,id target,SEL settingSelector, id itemContent,SEL action, NSMenu * menu)
{
    NSMenuItem *mItem;

    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
    [item setLabel:label];
    [item setPaletteLabel:paletteLabel];
    [item setToolTip:toolTip];
    [item setTarget:target];

    [item performSelector:settingSelector withObject:itemContent];
    [item setAction:action];

    if (menu!=NULL)
    {
	// we actually need an NSMenuItem here, so we construct one
	mItem=[[[NSMenuItem alloc] init] autorelease];
	[mItem setSubmenu: menu];
	[mItem setTitle: [menu title]];
	[item setMenuFormRepresentation:mItem];
    }

    [theDict setObject:item forKey:identifier];
}

@implementation PlayListController
@synthesize playListWindow, currentMovieInfo;

/************************************************************************************/
-(void)awakeFromNib
{	    
	//window
	[playListWindow setLevel:NSNormalWindowLevel];
	[playListWindow setHidesOnDeactivate:NO];
	[playListWindow setBackgroundColor: [NSColor colorWithDeviceRed:0.8 green: 0.8 blue: 0.8 alpha:1]];
	
	// configure playlist table
	[playListTable setTarget:self];
	[playListTable setDoubleAction:@selector(doubleClick:)];
	[playListTable setVerticalMotionCanBeginDrag:YES];
	
    // register for dragged types
	[playListTable registerForDraggedTypes:[NSArray 
			arrayWithObjects:NSFilenamesPboardType,@"PlaylistSelectionEnumeratorType",nil]];
	
    // register for app pre-termination notification
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appShouldTerminate)
			name: @"ApplicationShouldTerminateNotification"
			object:NSApp];

	// register for table selection change notification
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(updateView) 
			name: NSTableViewSelectionDidChangeNotification
			object:playListTable];
	
	// redirect scrubbing events to player controller
	[[NSNotificationCenter defaultCenter] addObserver:playerController
											 selector:@selector(progresBarClicked:)
												 name:@"SBBarClickedNotification"
											   object:scrubbingBarToolbar];
	
	// preset status column for displaying pictures
	[[playListTable tableColumnWithIdentifier:@"status"] setDataCell:[[[NSImageCell alloc] initImageCell:nil] autorelease]];
	
	// load images
	playMode0Image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"play_mode_0"
							ofType:@"png"]];
	playMode1Image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"play_mode_1"
							ofType:@"png"]];
	playMode2Image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"play_mode_2"
							ofType:@"png"]];
	
	playImageOn = [[NSImage imageNamed:@"pl_play_button_on"] retain];
	playImageOff = [[NSImage imageNamed:@"pl_play_button_off"] retain];
	pauseImageOn = [[NSImage imageNamed:@"pl_pause_button_on"] retain];
	pauseImageOff = [[NSImage imageNamed:@"pl_pause_button_off"] retain];
	
	// set play mode
	if ([PREFS objectForKey:MPEPlaylistPlayMode])
		myPlayMode = [[PREFS objectForKey:MPEPlaylistPlayMode] intValue];
	else
		myPlayMode = 1;
	
	[self applyPrefs];
	
	//Setup Toolbar
	NSToolbar *toolbar=[[[NSToolbar alloc] initWithIdentifier:@"PlayListToolbar"] autorelease];
	toolbarItems=[[NSMutableDictionary dictionary] retain];
	
	//default set
	NSToolbarItem *item;
	item = [[[NSToolbarItem alloc] initWithItemIdentifier:NSToolbarSeparatorItemIdentifier] autorelease];
	[toolbarItems setObject:item forKey:NSToolbarSeparatorItemIdentifier];
	item = [[[NSToolbarItem alloc] initWithItemIdentifier:NSToolbarSpaceItemIdentifier] autorelease];
	[toolbarItems setObject:item forKey:NSToolbarSpaceItemIdentifier];
	item = [[[NSToolbarItem alloc] initWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier] autorelease];
	[toolbarItems setObject:item forKey:NSToolbarFlexibleSpaceItemIdentifier];
	item = [[[NSToolbarItem alloc] initWithItemIdentifier:NSToolbarCustomizeToolbarItemIdentifier] autorelease];
	[toolbarItems setObject:item forKey:NSToolbarCustomizeToolbarItemIdentifier];
		
	//custom set
	addToolbarItem(toolbarItems,@"PlayerPlayTool",@"Play",@"Play",nil,self,@selector(setView:),playerPlayToolbarView,nil,nil);
	addToolbarItem(toolbarItems,@"PlayerStopTool",@"Stop",@"Stop",nil,self,@selector(setView:),playerStopToolbarView,nil,nil);
	addToolbarItem(toolbarItems,@"PlayerPrevTool",@"Play Previous",@"Play Previous",nil,self,@selector(setView:),playerPrevToolbarView,nil,nil);
	addToolbarItem(toolbarItems,@"PlayerNextTool",@"Play Next",@"Play Next",nil,self,@selector(setView:),playerNextToolbarView,nil,nil);
	addToolbarItem(toolbarItems,@"PlayerScrubTool",@"Scrub Bar Control",@"Scrub Bar Control",nil,self,@selector(setView:),playerScrubToolbarView,nil,nil);
	addToolbarItem(toolbarItems,@"PlayerVolumeTool",@"Volume Control",@"Volume Control",nil,self,@selector(setView:),playerVolumeToolbarView,nil,nil);
	
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration: YES]; 
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    [playListWindow setToolbar:toolbar];
	
	//display if playlist was opened on last quit
	if ([PREFS boolForKey:MPEPlaylistOpen]) 
		[self displayWindow:nil];
	
	// Load playlist
	myData = [[NSMutableArray alloc] init];
	
	if ([PREFS objectForKey:MPEPlaylist]) {
		
		for (NSDictionary *item in [PREFS arrayForKey:MPEPlaylist])
			[tableData addObject:[MovieInfo movieInfoFromDictionaryRepresentation:item]];
	}
}

- (IBAction) displayWindow:(id)sender
{	
	[playListWindow makeKeyAndOrderFront:self];
}

- (IBAction) toggleWindow:(id)sender
{
	if ([playListWindow isVisible]) {
		[playListWindow close];
		[[playerController playerInterface] removeClient:self];
	} else {
		[playListWindow makeKeyAndOrderFront:self];
		[[playerController playerInterface] addClient:self];
	}
}

/************************************************************************************
 INTERFACE
 ************************************************************************************/
- (MovieInfo *) itemAtIndex:(int) aIndex
{
	if (aIndex >= 0 || aIndex < [[tableData arrangedObjects] count])
		return [[tableData arrangedObjects] objectAtIndex:aIndex];
	else
		return nil;
}
/************************************************************************************/
- (void) selectItemAtIndex:(int) aIndex
{
	[playListTable selectRowIndexes:[NSIndexSet indexSetWithIndex:aIndex] byExtendingSelection:NO];
}
/************************************************************************************/
- (MovieInfo *) selectedItem
{
	return [self itemAtIndex:[playListTable selectedRow]];
}
/************************************************************************************/
- (int) indexOfSelectedItem
{
	return [playListTable selectedRow];
}
/************************************************************************************/
- (int) numberOfSelectedItems
{
	return [playListTable numberOfSelectedRows];
}
/************************************************************************************/
- (int) indexOfItem:(MovieInfo *)anItem
{
	if ([[tableData arrangedObjects] count] > 0 && anItem) {
		NSUInteger aIndex = [[tableData arrangedObjects] indexOfObjectIdenticalTo:anItem];
		if (aIndex != NSNotFound)
			return aIndex;
	}
	return -1;
}
/************************************************************************************/
- (int) itemCount
{
	return [[tableData arrangedObjects] count];
}
/************************************************************************************/
- (void) appendItem:(MovieInfo *)anItem
{
	if (anItem) {
		if (![anItem containsInfo])
			[anItem preflight];
		[tableData addObject:anItem];
	}
}
/************************************************************************************/
- (void) insertItem:(MovieInfo *)anItem atIndex:(int) aIndex
{
	if (anItem && aIndex >= 0 && aIndex <= [[tableData arrangedObjects] count])
		[tableData insertObject:anItem atArrangedObjectIndex:aIndex];
}
/************************************************************************************/
- (void) removeItemAtIndex:(unsigned int)index
{
	if ([[tableData arrangedObjects] objectAtIndex:index])
		[tableData removeObjectAtArrangedObjectIndex:index];
}
/************************************************************************************/
- (void)deleteSelection
{
	[tableData removeObjectsAtArrangedObjectIndexes:[tableData selectionIndexes]];
	
	[self updateView];
}

- (int)getPlayMode
{
    return myPlayMode;
}

/************************************************************************************/
- (void) updateView
{
	int totalTime = 0;
	int i;
	
	[playListTable reloadData];
	
	switch (myPlayMode) {
	case 1:
		[playModeButton setImage:playMode1Image];
		[playModeButton setToolTip:NSLocalizedString(@"Play mode: Repeating",nil)];
		break;
	case 2:
		[playModeButton setImage:playMode2Image];
		[playModeButton setToolTip:NSLocalizedString(@"Play mode: Continous",nil)];
		break;
	default:
		[playModeButton setImage:playMode0Image];
		[playModeButton setToolTip:NSLocalizedString(@"Play mode: Single",nil)];
		break;
	}
	
	//get total time
	for(i=0; i<[[tableData arrangedObjects] count]; i++)
	{
		if ([(MovieInfo *)[[tableData arrangedObjects] objectAtIndex:i] length] > 0)
		{
			totalTime += [(MovieInfo *)[[tableData arrangedObjects] objectAtIndex:i] length];
		}
	}
	
	if([self itemCount] == 1)
		[playListCount setStringValue:[NSString stringWithFormat:@"%d item, %01d:%02d:%02d",[self itemCount],totalTime/3600,(totalTime%3600)/60,totalTime%60]];
	else
		[playListCount setStringValue:[NSString stringWithFormat:@"%d items, %01d:%02d:%02d",[self itemCount],totalTime/3600,(totalTime%3600)/60,totalTime%60]];
	
	// update menu items
	//[playNextMenuItem setEnabled:[playerController isPlaying]];
	//[playPreviousMenuItem setEnabled:[playerController isPlaying]];
}
/************************************************************************************/
- (void) applyPrefs;
{
	NSEnumerator *columnsEnum;
	NSTableColumn *column;
	float textSize;
	
	NSUserDefaults *defaults = [[AppController sharedController] preferences];
	
	// set playlist text font size
	if ([defaults objectForKey:@"SmallPlaylistText"]) {
		if ([defaults boolForKey:@"SmallPlaylistText"])
			textSize = kSmallerTextSize;
		else
			textSize = kDefaultTextSize;
	}
	else
		textSize = kDefaultTextSize;
	
	// set row height
	[playListTable setRowHeight:textSize + 4];
	
	// set scroller size
	if ([[playListTable superview] isKindOfClass:[NSScrollView class]]) {
		NSScroller *theScroller = [(NSScrollView *)[playListTable superview] verticalScroller];
		if (textSize == kDefaultTextSize)
			[theScroller setControlSize:NSRegularControlSize];
		else
			[theScroller setControlSize:NSSmallControlSize];
		[(NSScrollView *)[playListTable superview] setVerticalScroller:theScroller];
	}
	
	// set playlist text font size
	columnsEnum = [[playListTable tableColumns] objectEnumerator];
	while (column = [columnsEnum nextObject]) {
		NSCell *theCell = [column dataCell];
		[theCell setFont:[NSFont systemFontOfSize:textSize]];	
		[column setDataCell:theCell];
	}

	[self updateView];
	[playListTable setNeedsDisplay:YES];
}
/************************************************************************************/
- (void) finishedPlayingItem:(MovieInfo *)playingItem
{
	int theIndex = [self indexOfItem:playingItem];
	if (theIndex < 0)
		return;
	
	switch (myPlayMode) {
	case 0 :								// single item play mode
		theIndex = -1;						// stop playback
		break;
	case 1 :								// continous play mode
		theIndex++;							// move to next track
		if (theIndex >= [self itemCount])	// if it was lats track
			theIndex = -1;					// stop playback
		break;
	case 2 :								// continous repeat mode
		theIndex++;							// move to next track
		if (theIndex >= [self itemCount])	// if it was lats track
			theIndex = 0;					// move it to the first track
		break;
	default :
		theIndex = -1;						// stop playback
		break;
	}
	
	// play the next item if it is set to do so
	NSLog(@"playing next playlist index %d",theIndex);
	if (theIndex >= 0)
		[playerController playItem:[self itemAtIndex:theIndex] fromPlaylist:YES];
	else
		[playerController stopFromPlaylist];
}
/************************************************************************************
 ACTIONS
 ************************************************************************************/
- (IBAction)displayItemSettings:(id)sender
{
	// if there is no info records for the item ged it first
	if (![(MovieInfo *)[self selectedItem] containsInfo])
		[(MovieInfo *)[self selectedItem] preflight];
		
	[[[[AppController sharedController] inspectorController] window] makeKeyAndOrderFront:self];
}
/************************************************************************************/
- (IBAction)changePlayMode:(id)sender
{
	myPlayMode++;
	if (myPlayMode > 2)
		myPlayMode = 0;
	[self updateView];
	[PREFS setInteger:myPlayMode forKey:MPEPlaylistPlayMode];
}
/************************************************************************************
 MISC METHODS
 ************************************************************************************/
// when a drag-and-drop operation comes through, and a filename is being dropped on the table,
// we need to tell the table where to put the new filename (right at the end of the table).
// This controls the visual feedback to the user on where their drop will go.
- (NSDragOperation)tableView:(NSTableView*)tv 
		validateDrop:(id <NSDraggingInfo>)info
		proposedRow:(int)row
		proposedDropOperation:(NSTableViewDropOperation)op
{
    NSPasteboard *myPasteboard=[info draggingPasteboard];
    NSString *availableType=[myPasteboard availableTypeFromArray:[NSArray
			arrayWithObjects:NSFilenamesPboardType,@"PlaylistSelectionEnumeratorType",nil]];
    int i;
	
	// check if one of allowed types is avialable in pasteboard
	if ([availableType isEqualToString:@"PlaylistSelectionEnumeratorType"]) {
		// drag inside the table
		[tv setDropRow:row dropOperation:NSTableViewDropAbove];
		return op;
	}
	
	if([availableType isEqualToString:NSFilenamesPboardType]) {
		int movieCount = 0, audioCount = 0, subsCount = 0, otherCount = 0;
		// then get array of filenames
		NSArray *propertyList = [myPasteboard propertyListForType:availableType];
		
		for (i=0;i<[propertyList count];i++) {
			// get extension of the path and check if it is not subtitles extension
			if ([[AppController sharedController] isExtension:[[propertyList objectAtIndex:i] pathExtension]
					ofType:MP_DIALOG_SUBTITLES]) {
				subsCount++;
				continue;
			}
			if ([[AppController sharedController] isExtension:[[propertyList objectAtIndex:i] pathExtension]
					ofType:MP_DIALOG_VIDEO]) {
				movieCount++;
				continue;
			}
			if ([[AppController sharedController] isExtension:[[propertyList objectAtIndex:i] pathExtension]
					ofType:MP_DIALOG_AUDIO]) {
				audioCount++;
				continue;
			}
			otherCount++;
		}

		if (op == NSTableViewDropOn) {
			if (row < 0) return NSDragOperationNone;
			if (movieCount > 0 || otherCount > 0 || audioCount > 0)
				return NSDragOperationNone;
			if (subsCount == 0) return NSDragOperationNone;
			[tv setDropRow:row dropOperation:op];
			return op;
		}
		
		if (op == NSTableViewDropAbove) {
			if (movieCount == 0 && otherCount == 0 && audioCount == 0)
				return NSDragOperationNone;
			[tv setDropRow:row dropOperation:op];
			return op;
		}
	}
	return NSDragOperationNone;
}
/************************************************************************************/
// This routine does the actual processing for a drag-and-drop operation on a tableview.
// As the tableview's data source, we get this call when it's time to update our backend data.
- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id < NSDraggingInfo >)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *myPasteboard=[info draggingPasteboard];
	// check if one of allowed types is avialable in pasteboard
    NSString *availableType=[myPasteboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType,@"PlaylistSelectionEnumeratorType",nil]];
	// get data from the pasteboard
	NSArray *propertyList=[myPasteboard propertyListForType:availableType];
	
	if ([availableType isEqualToString:@"PlaylistSelectionEnumeratorType"])
	{
		NSMutableArray *objects = [NSMutableArray array];
		NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
		
		for (NSNumber *index in propertyList) {
			[objects addObject:[[tableData arrangedObjects] objectAtIndex:[index unsignedIntegerValue]]];
			[set addIndex:[index unsignedIntegerValue]];
		}
		
		[tableData removeObjectsAtArrangedObjectIndexes:set];
		
		NSIndexSet *insertSet = [NSIndexSet indexSetWithIndexesInRange:
								  NSMakeRange(row - [set countOfIndexesInRange:NSMakeRange(0, row)], [objects count])];
		[tableData insertObjects:objects atArrangedObjectIndexes:insertSet];
	}
	
	if([availableType isEqualToString:NSFilenamesPboardType])
	{
		int i, insertIndex = row;
		NSMutableArray *movieList = [NSMutableArray array];
		NSMutableArray *subtitlesList = [NSMutableArray array];
		NSMutableArray *audioList = [NSMutableArray array];
		NSEnumerator *fileEnum = [propertyList objectEnumerator];
		NSString *path;
		
		// divide dragged files to arrays by its type
		while (path = [fileEnum nextObject])
		{
			if ([[AppController sharedController] isExtension:[path pathExtension] ofType:MP_DIALOG_SUBTITLES]) {
				[subtitlesList addObject:path];
				continue;
			}
			if ([[AppController sharedController] isExtension:[path pathExtension] ofType:MP_DIALOG_AUDIO]) {
				[audioList addObject:path];
				continue;
			}
			// all other files add as movies regardless extension, we will preflight it
			[movieList addObject:path];
		}

		if (operation == NSTableViewDropOn && [subtitlesList count] > 0)
		{
			// if only subtitles were dropped, take only first file and add it to the row
			[[myData objectAtIndex:row] setObject:[subtitlesList objectAtIndex:0] forKey:@"SubtitlesFile"];
		}
		else
		{
			// else
			NSModalSession progressSession = 0;
			NSArray *insertList;
			// we prefer movies before audio
			if ([movieList count] > 0)
				insertList = movieList;
			else
				insertList = audioList;
			// if there are more items than 3 then display progress for it
			
			if ([insertList count] > 3)
			{
				[progressBar setMaxValue:[insertList count]];
				[progressBar setDoubleValue:0];
				[filenameBox setStringValue:@""];
				progressSession = [NSApp beginModalSessionForWindow:preflightPanel];
			}
			// add objects to the playlist
			for (i=0;i<[insertList count];i++)
			{
				MovieInfo *item = [MovieInfo movieInfoWithPathToFile:[insertList objectAtIndex:i]];
				
				/*if ([movieList count] > 0)
				{
					// if movies are dropped
					if (i < [subtitlesList count])
						[myItem setObject:[subtitlesList objectAtIndex:i] forKey:@"SubtitlesFile"];
					if (i < [audioList count])
						[myItem setObject:[audioList objectAtIndex:i] forKey:@"AudioFile"];
					//audioexportlist BETA
					if (i < [audioExportList count])
						[myItem setObject:[audioList objectAtIndex:i] forKey:@"AudioExportFile"];
				}
				else
					[myItem setObject:[audioList objectAtIndex:i] forKey:@"MovieFile"];*/
				
				// if progress was created for this
				if (progressSession != 0)
				{
					if ([NSApp runModalSession:progressSession] != NSRunContinuesResponse)
						break;
					
					[filenameBox setStringValue:[[insertList objectAtIndex:i] lastPathComponent]];
					[progressBar setDoubleValue:(i+1)];
				}
				
				// insert item in to playlist
				//[myData insertObject:item atIndex:insertIndex];
				[tableData insertObject:item atArrangedObjectIndex:insertIndex];
				
				// manage selection
				/*if ([playListTable selectedRow] == -1)
					[playListTable selectRow:insertIndex byExtendingSelection:NO];
				else
					[playListTable selectRow:insertIndex byExtendingSelection:YES];*/
				
				[item preflight];
				
				insertIndex++;
			}
			// if progress was created then release it
			if (progressSession != 0)
			{
				[NSApp endModalSession:progressSession];
				[preflightPanel orderOut:nil];
			}
		}
    }
	
	[self updateView];
	return YES;
}
/************************************************************************************/
// handle drags inside the table
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	// prepare pasteboard
	[pboard declareTypes:[NSArray arrayWithObject:@"PlaylistSelectionEnumeratorType"] owner:nil];
	
	NSArray *objects = [[tableData arrangedObjects] objectsAtIndexes:rowIndexes];
	NSMutableArray *indexes = [NSMutableArray array];
	
	for (MovieInfo *obj in objects)
		[indexes addObject:[NSNumber numberWithUnsignedInteger:[[tableData arrangedObjects] indexOfObject:obj]]];
	
	// put data to the pasteboard
	return [pboard setPropertyList:indexes forType:@"PlaylistSelectionEnumeratorType"];
}

/************************************************************************************
 DELEGATE METHODS
 ************************************************************************************/
- (BOOL) validateMenuItem:(NSMenuItem *)aMenuItem
{
	return NO;
}
/************************************************************************************/
- (IBAction)doubleClick:(id)sender
{
	[playerController playItem:[[tableData arrangedObjects] objectAtIndex:[playListTable clickedRow]]
				  fromPlaylist:YES];
}

- (IBAction)playPrevious:(id)sender;
{
	if (![playerController isRunning])
		return;
	
	int itemIdx = [self indexOfItem:[playerController playingItem]];
	
	if(itemIdx > 0)
	{
		itemIdx--;
		[self selectItemAtIndex:itemIdx];
		[self updateView];
		[playerController playItem:[[tableData arrangedObjects] objectAtIndex:itemIdx]
					  fromPlaylist:YES];
	}
}

- (IBAction)playNext:(id)sender;
{
	if (![playerController isRunning])
		return;
	
	int itemIdx = [self indexOfItem:[playerController playingItem]];
	
	if(itemIdx >= 0 && itemIdx < ([self itemCount]-1))
	{
		itemIdx++;
		[self selectItemAtIndex:itemIdx];
		[self updateView];
		[playerController playItem:[[tableData arrangedObjects] objectAtIndex:itemIdx]
					  fromPlaylist:YES];
	}
}

- (void)playItemAtIndex:(int)index
{
	if (index >= [self itemCount]) {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Cannot play item at index %d, only %d item in Playlist.",index,[self itemCount]];
		return;
	}
	
	[self selectItemAtIndex:index];
	[self updateView];
	[playerController playItem:[[tableData arrangedObjects] objectAtIndex:index]
				  fromPlaylist:YES];
}

/************************************************************************************/
// Stop the table's rows from being editable when we double-click on them
- (BOOL)tableView:(NSTableView *)tableView
		shouldEditTableColumn:(NSTableColumn *)tableColumn 
		row:(int)row
{    
	return NO;
}

/************************************************************************************/
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([self selectedItem])
		[self setCurrentMovieInfo:[self selectedItem]];
	if ([playListWindow isKeyWindow] && [[AppController sharedController] movieInfoProvider] != self)
		[[AppController sharedController] setMovieInfoProvider:self];
}

/************************************************************************************
 NOTIFICATION HANDLERS
 ************************************************************************************/
- (void) interface:(MplayerInterface *)mi hasChangedStateTo:(NSNumber *)statenumber fromState:(NSNumber *)oldstatenumber
{	
	MIState state = [statenumber unsignedIntValue];
	unsigned int stateMask = (1<<state);
	MIState oldState = [oldstatenumber unsignedIntValue];
	unsigned int oldStateMask = (1<<oldState);
	
	// Change of Play/Pause state
	if (!!(stateMask & MIStatePPPlayingMask) != !!(oldStateMask & MIStatePPPlayingMask)) {
		// Playing
		if (stateMask & MIStatePPPlayingMask) {
			// Update interface
			[playButtonToolbar setImage:pauseImageOff];
			[playButtonToolbar setAlternateImage:pauseImageOn];
		// Pausing
		} else {
			// Update interface
			[playButtonToolbar setImage:playImageOff];
			[playButtonToolbar setAlternateImage:playImageOn];
		}
	}
	
	// Change of Running/Stopped state
	if (!!(stateMask & MIStateStoppedMask) != !!(oldStateMask & MIStateStoppedMask)) {
		// Stopped
		if (stateMask & MIStateStoppedMask) {
			[timeTextFieldToolbar setStringValue:@"00:00:00"];
		// Running
		} else {
			
		}
	}
	
	// Update progress bar
	if (stateMask & MIStateStoppedMask && !(oldStateMask & MIStateStoppedMask)) {
		// Reset progress bar
		[scrubbingBarToolbar setScrubStyle:MPEScrubbingBarEmptyStyle];
		[scrubbingBarToolbar setDoubleValue:0];
		[scrubbingBarToolbar setIndeterminate:NO];
	} else if (stateMask & MIStateIntermediateMask && !(oldStateMask & MIStateIntermediateMask)) {
		// Intermediate progress bar
		[scrubbingBarToolbar setScrubStyle:MPEScrubbingBarProgressStyle];
		[scrubbingBarToolbar setIndeterminate:YES];
	} else if (stateMask & MIStatePositionMask && !(oldStateMask & MIStatePositionMask)) {
		// Progress bar
		if ([[playerController playingItem] length] > 0) {
			[scrubbingBarToolbar setMaxValue: [[playerController playingItem] length]];
			[scrubbingBarToolbar setScrubStyle:MPEScrubbingBarPositionStyle];
		} else {
			[scrubbingBarToolbar setScrubStyle:MPEScrubbingBarProgressStyle];
			[scrubbingBarToolbar setMaxValue:100];
			[scrubbingBarToolbar setIndeterminate:NO];
		}
	}
}
/************************************************************************************/
- (void) interface:(MplayerInterface *)mi volumeUpdate:(NSNumber *)volume
{
	[volumeSliderToolbar setFloatValue:[volume floatValue]];
}
/************************************************************************************/
- (void) interface:(MplayerInterface *)mi timeUpdate:(NSNumber *)newTime
{
	float seconds = [newTime floatValue];
	
	if ([[playerController playingItem] length] > 0)
		[scrubbingBarToolbar setDoubleValue:seconds];
	else
		[scrubbingBarToolbar setDoubleValue:0];
	
	int iseconds = (int)seconds;
	[timeTextFieldToolbar setStringValue:[NSString stringWithFormat:@"%02d:%02d:%02d", iseconds/3600,(iseconds%3600)/60,iseconds%60]];
}
/************************************************************************************/
- (void)appShouldTerminate
{	
	// Save playlist
	NSMutableArray *playlist = [NSMutableArray array];
	
	for (MovieInfo *info in [tableData arrangedObjects])
		[playlist addObject:[info dictionaryRepresentation]];
	
	[PREFS setObject:playlist forKey:MPEPlaylist];
	
	[PREFS setBool:[playListWindow isVisible] forKey:MPEPlaylistOpen];
 }

- (void)windowWillClose:(NSNotification *)aNotification
{
	[playListWindow orderOut:nil];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	if ([self selectedItem])
		[[AppController sharedController] setMovieInfoProvider:self];
}

/*
	Toolbar
*/
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *newItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    NSToolbarItem *item=[toolbarItems objectForKey:itemIdentifier];
    
    [newItem setLabel:[item label]];
    [newItem setPaletteLabel:[item paletteLabel]];
    if ([item view]!=NULL)
    {
		[newItem setView:[item view]];
    }
    else
    {
		[newItem setImage:[item image]];
    }
    
	[newItem setToolTip:[item toolTip]];
    [newItem setTarget:[item target]];
    [newItem setAction:[item action]];
    [newItem setMenuFormRepresentation:[item menuFormRepresentation]];

    if ([newItem view]!=NULL)
    {
		[newItem setMinSize:[[item view] bounds].size];
		[newItem setMaxSize:[[item view] bounds].size];
    }

    return newItem;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:@"PlayerPlayTool",@"PlayerStopTool",NSToolbarFlexibleSpaceItemIdentifier,@"PlayerPrevTool",@"PlayerScrubTool",@"PlayerNextTool",NSToolbarFlexibleSpaceItemIdentifier, @"PlayerVolumeTool",nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [toolbarItems allKeys];
    //return [NSArray arrayWithObjects:@"PlayerPlayTool",@"PlayerStopTool",NSToolbarFlexibleSpaceItemIdentifier,@"PlayerPrevTool",@"PlayerScrubTool",@"PlayerNextTool",NSToolbarFlexibleSpaceItemIdentifier, @"PlayerVolumeTool",nil];
}

// throw away our toolbar items dictionary
- (void) dealloc
{
	[toolbarItems release];
	
	// release data
	[myData release];
	[playMode0Image release];
	[playMode1Image release];
	[playMode2Image release];
	[playImageOn release];
	[playImageOff release];
	[pauseImageOn release];
	[pauseImageOff release];
	
    [super dealloc];
}
@end


@implementation PlayListPlayingItemTransformer

+ (Class)transformedValueClass
{
    return [NSString self];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)beforeObject
{
	if (!beforeObject || ![beforeObject boolValue])
		return nil;
    
	NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    return [resourcePath stringByAppendingPathComponent:@"playing_state.png"];
}

@end