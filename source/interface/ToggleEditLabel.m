/*  
 *  KeyRedirectButton.m
 *  MPlayerOSX Extended
 *  
 *  Created on 12.06.11
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

#import "ToggleEditLabel.h"


@implementation ToggleEditLabel

- (void)updateStyle
{
    // Set style for label/text field
    [self setSelectable:[self isEditable]];
    [self setBordered:[self isEditable]];
    [self setBezeled:[self isEditable]];
    [self setDrawsBackground:[self isEditable]];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Let the cell establish the bezel size
    [self setEditable:YES];
    [self setEditable:NO];
}

- (void)setEditable:(BOOL)flag 
{
    [super setEditable:flag];
    
    [self updateStyle];
    
    if (!flag) {
        // Stop editing ([window setFirstResponder:window] did not work)
        [[self window] endEditingFor:self];
    } else {
        // Give field focus right away
        [[self window] makeFirstResponder:self];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
    [super mouseDown:theEvent];

    if ([theEvent clickCount] == 2 && [self isEnabled]) {
        [self setEditable:YES];
    }
}

- (void)textDidEndEditing:(NSNotification *)notification
{
    [super textDidEndEditing:notification];
    [self setEditable:NO];
}

- (void)setEnabled:(BOOL)flag
{
    [super setEnabled:flag];
    
    if (!flag) {
        [self setEditable:NO];
    }
}

- (void)dealloc
{
    [super dealloc];
}

@end



@implementation ToggleEditLabelCell

- (void)setBezeled:(BOOL)flag
{
    [super setBezeled:flag];
    if (flag) {
        cellRectOffset = [self titleRectForBounds:NSMakeRect(0.0, 0.0, 0.0, 0.0)];
    }
}

- (void)offsetCell:(NSRect*)cellFrame
{
    if ([self isBezeled] == NO) {
        cellFrame->origin.x += cellRectOffset.origin.x;
        cellFrame->origin.y += cellRectOffset.origin.y;
        cellFrame->size.width += cellRectOffset.size.width;
        cellFrame->size.height += cellRectOffset.size.height;
    }
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [self offsetCell:&cellFrame];
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end
