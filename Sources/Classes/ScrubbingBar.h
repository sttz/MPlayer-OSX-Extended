/*
 *  ScrubbingBar.h
 *  MPlayer OS X
 *
 *	Description:
 *		NSProgressIndicator subclass that implements posting of notification
 *	on clicking or dragging inside the progress bar bounds
 *		The notification info dictionary contains the value representing position of the mouse
 *	pointer while left mouse button was pressed for key "SBClickedValue"
 *	1.1 New GUI appearnce and new styles has been introduced
 *
 *  Created by Jan Volf on Mon Apr 14 2003.
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Notification
	//	@"SBBarClickedNotification"
// info dictionary key
	//	@"SBClickedValue"		NSNumber double

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_2
typedef enum _NSScrubbingBarStyle {
    NSScrubbingBarEmptyStyle = 0,
	NSScrubbingBarProgressStyle = 1,
	NSScrubbingBarPositionStyle = 2
} NSScrubbingBarStyle;
#endif

@interface ScrubbingBar:NSProgressIndicator
{
	NSScrubbingBarStyle	myStyle;
	
	NSImage *scrubBarEnds;
	NSImage *scrubBarRun;
	NSImage *scrubBarBadge;
	NSImage *scrubBarAnim;
	NSImage *scrubBarAnimFrame;
	float animFrame;
}
// event handlers
- (void) mouseDown:(NSEvent *)theEvent;
- (void) mouseDragged:(NSEvent *)theEvent;
// overriding event handlers
- (BOOL) mouseDownCanMoveWindow;
- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent;

// overriding drawing method
- (void) drawRect:(NSRect)aRect;
@end

// private
int postNotification (id self, NSEvent *theEvent);