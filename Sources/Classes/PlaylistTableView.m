/*
 PlaylistTableView.m

 Author: MCF, with help from PW, augmented by JaVol
 
 */

#import "PlaylistTableView.h"

@implementation PlaylistTableView

/************************************************************************************
 ACTION IMPLEMENTATION
 ************************************************************************************/
- (void)keyDown:(NSEvent *)theEvent
{
	unichar pressedKey;
	
	// check if the backspace is pressed
	pressedKey = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
	if ((pressedKey == NSDeleteFunctionKey || pressedKey == 127) && [self selectedRow] >= 0)
		[playListController deleteSelection];
	else
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
