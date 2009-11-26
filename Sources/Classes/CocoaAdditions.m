/*  
 *  CocoaAdditions.m
 *  MPlayerOSX Extended
 *  
 *  Created on 26.11.2009
 *  
 *  Description:
 *	Additions to Cocoa classes
 *  
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#import "CocoaAdditions.h"
#import <AppKit/NSView.h>

@implementation NSView (MPEAdditions)

- (void) resizeAndArrangeSubviewsVerticallyWithPadding:(float)padding
{
	// calculate total height
	float totalHeight, maxWidth;
	for (NSView *view in [self subviews]) {
		totalHeight += [view frame].size.height;
		if ([view frame].size.width > maxWidth)
			maxWidth = [view frame].size.width;
	}
	
	totalHeight += 2*padding;
	maxWidth += 2*padding;
	
	[self setFrame:NSMakeRect(0, 0, maxWidth, totalHeight)];
	
	// arrange views from top to bottom
	for (NSView *view in [self subviews]) {
		NSRect viewframe = [view frame];
		viewframe.origin.y = totalHeight - viewframe.size.height - padding;
		viewframe.origin.x = padding;
		totalHeight -= viewframe.size.height;
		[view setFrame:viewframe];
	}
}

@end