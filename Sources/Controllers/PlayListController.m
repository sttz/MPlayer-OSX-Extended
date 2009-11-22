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
#import "SettingsController.h"

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

/************************************************************************************/
-(void)awakeFromNib
{	    
	NSUserDefaults *defaults = [[AppController sharedController] preferences];
	
	//window
	[playListWindow setLevel:NSNormalWindowLevel];
	[playListWindow setHidesOnDeactivate:NO];
	[playListWindow setBackgroundColor: [NSColor colorWithDeviceRed:0.8 green: 0.8 blue: 0.8 alpha:1]];
	
	// configure playlist table
	[playListTable setTarget:self];
	[playListTable setDoubleAction:@selector(doubleClick:)];
	[playListTable setVerticalMotionCanBeginDrag:YES];
	
	// create preflight queue
	preflightQueue = [[NSMutableArray alloc] init];
	
    // register for dragged types
	[playListTable registerForDraggedTypes:[NSArray 
			arrayWithObjects:NSFilenamesPboardType,@"PlaylistSelectionEnumeratorType",nil]];

    // register for app launch finish
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appFinishedLaunching)
			name: NSApplicationDidFinishLaunchingNotification
			object:NSApp];
	// register for app termination notification
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(appTerminating)
			name: NSApplicationWillTerminateNotification
			object:NSApp];
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
	
	// register for end of preflight notification
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(processResultOfPreflight:) 
			name: @"MIFinishedParsing"
			object:[playerController preflightInterface]];
	
	// preset status column for displaying pictures
	[[playListTable tableColumnWithIdentifier:@"status"] setDataCell:[[[NSImageCell alloc] initImageCell:nil] autorelease]];
	
	// load images
	statusIcon = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"playing_state"
							ofType:@"png"]];
	playMode0Image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"play_mode_0"
							ofType:@"png"]];
	playMode1Image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"play_mode_1"
							ofType:@"png"]];
	playMode2Image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle]
							pathForResource:@"play_mode_2"
							ofType:@"png"]];

	// set play mode
	if ([defaults objectForKey:@"PlayMode"])
		myPlayMode = [[defaults objectForKey:@"PlayMode"] intValue];
	else
		myPlayMode = 0;
	
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
	
	//display if set in pref or if playlist was opened on last quit
	if ([defaults boolForKey:@"PlaylistOnStartup"] || [defaults boolForKey:@"PlaylistOpen"]) 
	{
		[self displayWindow:nil];
	}
}

- (IBAction) displayWindow:(id)sender
{	
	[self openWindow:!isOpen];
}

- (void) openWindow:(BOOL)display
{
	if(isOpen && !display)
	{
		[playListButton setState: NSOffState];
		[playListWindow orderOut:nil];
	}
	else if (!isOpen && display)
	{
		[playListButton setState: NSOnState];
		[playListWindow makeKeyAndOrderFront:nil];
		[playerController updatePlaylistWindow];
	}
	
	isOpen = display;
	[self updateView];
	[[NSApp mainWindow] update];
}

/************************************************************************************
 INTERFACE
 ************************************************************************************/
- (NSMutableDictionary *) itemAtIndex:(int) aIndex
{
	if (aIndex >= 0 || aIndex < [myData count])
		return [myData objectAtIndex:aIndex];
	else
		return nil;
}
/************************************************************************************/
- (void) selectItemAtIndex:(int) aIndex
{
	[playListTable selectRow:aIndex byExtendingSelection:NO];
}
/************************************************************************************/
- (NSMutableDictionary *) selectedItem
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
- (int) indexOfItem:(NSDictionary *)anItem
{
	if ([myData count] > 0 && anItem) {
		NSUInteger aIndex = [myData indexOfObjectIdenticalTo:anItem];
		if (aIndex != NSNotFound)
			return aIndex;
	}
	return -1;
}
/************************************************************************************/
- (int) itemCount
{
	return [myData count];
}
/************************************************************************************/
- (void) appendItem:(NSMutableDictionary *)anItem
{
	if (anItem) {
		
		[preflightQueue addObject:anItem];
		[self startPreflight];
	}

}
/************************************************************************************/
- (void) insertItem:(NSMutableDictionary *)anItem atIndex:(int) aIndex
{
	if (anItem && aIndex >= 0 && aIndex <= [myData count])
		[myData insertObject:anItem atIndex:aIndex];
			[playListTable reloadData];


}
/************************************************************************************/
- (void) removeItemAtIndex:(unsigned int)index
{
	if ([myData objectAtIndex:index]) {
		
		// Remove object
		[myData removeObjectAtIndex:index];
	}
}
/************************************************************************************/
- (void)deleteSelection
{
	id myObject;
	// get and sort enumerator in descending order
	NSEnumerator *selectedItemsEnum = [[[[playListTable selectedRowEnumerator] allObjects]
			sortedArrayUsingSelector:@selector(compare:)] reverseObjectEnumerator];
	
	// remove object in descending order
	myObject = [selectedItemsEnum nextObject];
	while (myObject) {
		[self removeItemAtIndex:[myObject intValue]];
		myObject = [selectedItemsEnum nextObject];
	}
	[playListTable deselectAll:nil];
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
	
	if ([playListTable selectedRow] < 0 || [playListTable numberOfSelectedRows] > 1 ||
			[settingsController isVisible]) {
		[settingsButton setEnabled:NO];
	}
	else {
		[settingsButton setEnabled:YES];
	}
	
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
	for(i=0; i<[myData count]; i++)
	{
		if ([[MovieInfo fromDictionary:[myData objectAtIndex:i]] length] > 0)
		{
			totalTime += [[MovieInfo fromDictionary:[myData objectAtIndex:i]] length];
		}
	}
	
	if([self itemCount] == 1)
		[playListCount setStringValue:[NSString stringWithFormat:@"%d item, %01d:%02d:%02d",[self itemCount],totalTime/3600,(totalTime%3600)/60,totalTime%60]];
	else
		[playListCount setStringValue:[NSString stringWithFormat:@"%d items, %01d:%02d:%02d",[self itemCount],totalTime/3600,(totalTime%3600)/60,totalTime%60]];
	
	// update menu items
	[playNextMenuItem setEnabled:[playerController isPlaying]];
	[playPreviousMenuItem setEnabled:[playerController isPlaying]];
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
- (void) finishedPlayingItem:(NSDictionary *)playingItem
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
	if (theIndex >= 0)
		[playerController playFromPlaylist:[self itemAtIndex:theIndex]];
	else
		[playerController stopFromPlaylist];
}
/************************************************************************************
 ACTIONS
 ************************************************************************************/
- (IBAction)displayItemSettings:(id)sender
{
	// if there is no info records for the item ged it first
	if (![[self selectedItem] objectForKey:@"MovieInfo"]) {
		[preflightQueue addObject:[self selectedItem]];
		[self startPreflight];
	}
		
	//NSMutableDictionary *myItem = [NSMutableDictionary dictionaryWithDictionary:[self selectedItem]];
	//[settingsController displayForItem:myItem];
	[settingsController displayForItem:[self selectedItem]];
	[settingsButton setEnabled:NO];
}
/************************************************************************************/
- (IBAction)changePlayMode:(id)sender
{
	myPlayMode++;
	if (myPlayMode > 2)
		myPlayMode = 0;
	[self updateView];
}
/************************************************************************************/
- (IBAction)cancelPreflight:(id)sender
{
	[NSApp abortModal];
}
/************************************************************************************
 MISC METHODS
 ************************************************************************************/
/************************************************************************************
 DATA SOURCE METHODS
 ************************************************************************************/
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{	
	return [myData count];
}

/************************************************************************************/
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{    
	// movie title column
	if ([[tableColumn identifier] isEqualToString:@"movie"]) {
		if ([[myData objectAtIndex:row] objectForKey:@"ItemTitle"])
			return [[myData objectAtIndex:row] objectForKey:@"ItemTitle"];
		else
			return [[[myData objectAtIndex:row] objectForKey:@"MovieFile"] lastPathComponent];
	}
	// movie length column
	if ([[tableColumn identifier] isEqualToString:@"time"]) {
		if ([[MovieInfo fromDictionary:[myData objectAtIndex:row]] length] > 0) {
			int seconds = [[MovieInfo fromDictionary:[myData objectAtIndex:row]] length];
			return [NSString stringWithFormat:@"%01d:%02d:%02d",
					seconds/3600,(seconds%3600)/60,seconds%60];
		}
		else
			return @"--:--:--";
	}
	// movie status Column
	if ([[tableColumn identifier] isEqualToString:@"status"])
	{
		if ([myData indexOfObjectIdenticalTo:[playerController playingItem]] == row)
			return statusIcon;
	}
	return nil;
}
/************************************************************************************/
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
- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op
{
    NSPasteboard *myPasteboard=[info draggingPasteboard];
	// check if one of allowed types is avialable in pasteboard
    NSString *availableType=[myPasteboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType,@"PlaylistSelectionEnumeratorType",nil]];
	// get data from the pasteboard
	NSArray *propertyList=[myPasteboard propertyListForType:availableType];		
	
	// reset selection
	[tv deselectAll:nil];
	
	if ([availableType isEqualToString:@"PlaylistSelectionEnumeratorType"])
	{
		NSMutableArray *itemsStore = [NSMutableArray array];
		int i, removeIndex, insertIndex = row;
		
		// store dragged objects
		for (i=0;i<[propertyList count];i++)
		{
			[itemsStore addObject:[myData objectAtIndex:[[propertyList objectAtIndex:i] intValue]]];
		}
		
		// remove selected objects
		for (i=0;i<[itemsStore count];i++)
		{
			removeIndex = [myData indexOfObjectIdenticalTo:[itemsStore objectAtIndex:i]];
			// remove object
			[myData removeObjectAtIndex:removeIndex];
			// deal with poibility that insertion point might change too
			if (removeIndex < insertIndex)	// if insertion point was affected by remove
				insertIndex--;				// then decrement it
		}
		// isert objects back to the list
		for (i=0;i<[itemsStore count];i++)
		{
			// insert object
			[myData insertObject:[itemsStore objectAtIndex:i] atIndex:insertIndex];
			// manage selection
			if ([tv selectedRow] == -1)
				[tv selectRow:insertIndex byExtendingSelection:NO];
			else
				[tv selectRow:insertIndex byExtendingSelection:YES];
			insertIndex++;
		}
	}
	
	if([availableType isEqualToString:NSFilenamesPboardType])
	{
		int i, insertIndex = row;
		NSMutableArray *movieList = [NSMutableArray array];
		NSMutableArray *subtitlesList = [NSMutableArray array];
		NSMutableArray *audioList = [NSMutableArray array];
		//beta
		NSMutableArray *audioExportList = [NSMutableArray array];
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

		if (op == NSTableViewDropOn && [subtitlesList count] > 0)
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
				NSMutableDictionary *myItem = [NSMutableDictionary dictionary];
				if ([movieList count] > 0)
				{
					// if movies are dropped
					[myItem setObject:[movieList objectAtIndex:i] forKey:@"MovieFile"];
					if (i < [subtitlesList count])
						[myItem setObject:[subtitlesList objectAtIndex:i] forKey:@"SubtitlesFile"];
					if (i < [audioList count])
						[myItem setObject:[audioList objectAtIndex:i] forKey:@"AudioFile"];
					//audioexportlist BETA
					if (i < [audioExportList count])
						[myItem setObject:[audioList objectAtIndex:i] forKey:@"AudioExportFile"];
				}
				else
					[myItem setObject:[audioList objectAtIndex:i] forKey:@"MovieFile"];
				
				// if progress was created for this
				if (progressSession != 0)
				{
					if ([NSApp runModalSession:progressSession] != NSRunContinuesResponse)
						break;
					
					[filenameBox setStringValue:[[insertList objectAtIndex:i] lastPathComponent]];
					[progressBar setDoubleValue:(i+1)];
				}
				
				// save insert row
				[myItem	setObject:[NSNumber numberWithInt:insertIndex] forKey:@"InsertIndex"];
				
				// add to queue
				[preflightQueue addObject:myItem];
				
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
	
	// start to preflight items
	[self startPreflight];
	
	[self updateView];
	return YES;
}

- (void) startPreflight {
	
	if ([preflightQueue count] > 0) {
		[playerController preflightItem:[preflightQueue objectAtIndex:0]];
		[preflightBusy setMaxValue:[preflightQueue count]];
		[preflightBusy setDoubleValue:0];
		[preflightBusy setHidden:NO];
	}
}

- (void) processResultOfPreflight:(NSNotification *)notification {
	
	// process item
	if ([notification userInfo] && [[notification userInfo] objectForKey:@"MovieInfo"] && [[notification userInfo] objectForKey:@"MovieFile"]) {
		
		// find item in queue
		int i, queueIndex = -1;
		for (i = 0; i < [preflightQueue count]; i++) {
			if ([[preflightQueue objectAtIndex:i] objectForKey:@"MovieFile"] == [[notification userInfo] objectForKey:@"MovieFile"]) {
				queueIndex = i;
				break;
			}
		}
		
		// extract movieinfo
		MovieInfo *info = [MovieInfo fromDictionary:[notification userInfo]];
		
		// check if found and if preflight was successful
		if (queueIndex > -1 && [info containsInfo]) {
			
			// save MovieInfo
			[[preflightQueue objectAtIndex:queueIndex] setObject:info forKey:@"MovieInfo"];
			
			int insertIndex;
			if ([[preflightQueue objectAtIndex:queueIndex] objectForKey:@"InsertIndex"]) {
				insertIndex = [[[preflightQueue objectAtIndex:queueIndex] objectForKey:@"InsertIndex"] intValue];
				[[preflightQueue objectAtIndex:queueIndex] removeObjectForKey:@"InsertIndex"];
			} else
				insertIndex = [myData count];
			
			// insert item in to playlist
			[myData insertObject:[preflightQueue objectAtIndex:queueIndex] atIndex:insertIndex];
			// manage selection
			if ([playListTable selectedRow] == -1)
				[playListTable selectRow:insertIndex byExtendingSelection:NO];
			else
				[playListTable selectRow:insertIndex byExtendingSelection:YES];
			
		}
		
		// remove item from queue
		if (queueIndex > -1)
			[preflightQueue removeObjectAtIndex:queueIndex];
	}
	
	// process next item
	if ([preflightQueue count] > 0) {
		[playerController preflightItem:[preflightQueue objectAtIndex:0]];
		[preflightBusy setDoubleValue:([preflightBusy maxValue] - [preflightQueue count] + 1)];
	} else {
		[preflightBusy setHidden:YES];
	}
	
	[self updateView];
}
/************************************************************************************/
// handle drags inside the table
- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pasteboard
{
	pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	// prepare pasteboard
	[pasteboard declareTypes:[NSArray arrayWithObject:@"PlaylistSelectionEnumeratorType"]
			owner:nil];
	
	// put data to the pasteboard
	if ([pasteboard setPropertyList:rows
				forType:@"PlaylistSelectionEnumeratorType"])
		return YES;
	return NO;
}

/************************************************************************************
 DELEGATE METHODS
 ************************************************************************************/
- (BOOL) validateMenuItem:(NSMenuItem *)aMenuItem
{
	if ([[aMenuItem title] isEqualToString:NSLocalizedString(@"Show Info",nil)]) {
		if ([playListTable numberOfSelectedRows] == 1 && ![settingsController isVisible])
			return YES;
	}
	return NO;
}
/************************************************************************************/
- (IBAction)doubleClick:(id)sender
{
	[playerController playFromPlaylist:[myData objectAtIndex:[playListTable clickedRow]]];
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
		[playerController playFromPlaylist:[myData objectAtIndex:itemIdx]];
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
		[playerController playFromPlaylist:[myData objectAtIndex:itemIdx]];
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
	[playerController playFromPlaylist:[myData objectAtIndex:index]];
}

/************************************************************************************/
// Stop the table's rows from being editable when we double-click on them
- (BOOL)tableView:(NSTableView *)tableView
		shouldEditTableColumn:(NSTableColumn *)tableColumn 
		row:(int)row
{    
	return NO;
}
/************************************************************************************
 NOTIFICATION HANDLERS
 ************************************************************************************/
- (void) appFinishedLaunching
{
	// load playlist from preferences
	NSArray *savedPlaylist = [[[AppController sharedController] preferences] objectForKey:@"PlayList"];
	
	if (savedPlaylist)
	{
		int i;
		myData = [[NSMutableArray alloc] init];
		
		//make item mutable
		for(i=0; i<[savedPlaylist count]; i++)
		{
			// add to preflight queue
			[preflightQueue addObject:[[[savedPlaylist objectAtIndex:i] mutableCopy] autorelease]];
		}
		
		// start preflight
		[self startPreflight];
	}
	else
	{
		// if no playilist found
		myData = [[NSMutableArray alloc] init];	// create new one
	}
	
	[self applyPrefs];
}
/************************************************************************************/
- (void) appShouldTerminate
{
	// save values to prefs
	[[[AppController sharedController] preferences] setObject:[NSNumber numberWithInt:myPlayMode] forKey:@"PlayMode"];
}
/************************************************************************************/
- (void)appTerminating
{	
	NSUserDefaults *defaults = [[AppController sharedController] preferences];
	
	// save current playlist window state
	[defaults setBool:[playListWindow isVisible] forKey:@"PlaylistOpen"];
	
	// Remove MovieInfo from items
	int i;
	for (i = 0; i < [myData count]; i++) {
		[[myData objectAtIndex:i] removeObjectForKey:@"MovieInfo"];
	}
	
	// save playlist to prefs
	[defaults setObject:myData forKey:@"PlayList"];
 }

- (void)windowWillClose:(NSNotification *)aNotification
{
	[playListWindow setFrameAutosaveName:@"PlayListWindow"];
	
	[playListButton setState: NSOffState];
	[playListWindow orderOut:nil];
		
	isOpen = NO;
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
    [preflightQueue release];
	[toolbarItems release];
	
	// release data
	[myData release];
	[statusIcon release];
	[playMode0Image release];
	[playMode1Image release];
	[playMode2Image release];
	
    [super dealloc];
}
@end
