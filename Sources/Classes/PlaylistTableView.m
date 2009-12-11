/*
 PlaylistTableView.m

 Author: MCF, with help from PW, augmented by JaVol
 
 */

#import "PlaylistTableView.h"

#include <Carbon/Carbon.h>

@implementation PlaylistTableView

/************************************************************************************
 ACTION IMPLEMENTATION
 ************************************************************************************/
- (void)keyDown:(NSEvent *)theEvent
{
	if ([self selectedRow] >= 0) {
		unichar pressedKey = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
		// delete item with backspace or delete
		if ((pressedKey == NSDeleteFunctionKey || [theEvent keyCode] == kVK_Delete))
			[playListController deleteSelection];
		// play item with return or enter
		else if ([theEvent keyCode] == kVK_Return || [theEvent keyCode] == kVK_ANSI_KeypadEnter)
			[playListController playItemAtIndex:[self selectedRow]];
	} else
		[super keyDown:theEvent];
}
/************************************************************************************/
- (void)delete:(id)sender
{
	[playListController deleteSelection];
}

/************************************************************************************
 DELEGATE METHODS
 ************************************************************************************/
- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	BOOL	result = NO;
	// clear menu item
	if ([anItem action] == @selector(delete:)) {
		if ([self selectedRow] >= 0)
			result = YES;
		else
			result = NO;
	}
	
	// select all menu item
	if ([anItem action] == @selector(selectAll:)) {
		if ([self numberOfRows] > 0)
			result = YES;
		else
			result = NO;
	}
	
	return result;
}

@end
