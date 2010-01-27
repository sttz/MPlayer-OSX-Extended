/*  
 *  KeyRedirectButton.m
 *  MPlayerOSX Extended
 *  
 *  Created on 25.01.2010
 *  
 *  Description:
 *	Borderless window used to go into and display video in fullscreen.
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

#import "KeyRedirectButton.h"

#import "PlayerController.h"
#import "PlayerWindow.h"

@implementation KeyRedirectButton

- (void)keyDown:(NSEvent *)theEvent
{
	if (![[(PlayerWindow *)[self window] playerController] handleKeyEvent:theEvent])
		[super keyDown:theEvent];
}

- (BOOL)acceptsFirstResponder
{
	return NO;
}

- (BOOL)refusesFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	return NO;
}

@end


@implementation KeyRedirectPopUpButton

- (void)keyDown:(NSEvent *)theEvent
{
	if (![[(PlayerWindow *)[self window] playerController] handleKeyEvent:theEvent])
		[super keyDown:theEvent];
}

- (BOOL)acceptsFirstResponder
{
	return NO;
}

- (BOOL)refusesFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	return NO;
}

@end
