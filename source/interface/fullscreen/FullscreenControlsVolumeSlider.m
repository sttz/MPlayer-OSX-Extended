/*  
 *  FullscreenControlsView.h
 *  MPlayerOSX Extended
 *  
 *  Created on 04.11.2008
 *  
 *  Description:
 *	Volume slider used in fullscreen controls
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

#import "FullscreenControlsVolumeSlider.h"


@implementation FullscreenControlsVolumeSliderCell
- (void)loadImages
{
	// knobOff/On are released in [super dealloc]
	knobOff = [[NSImage imageNamed:@"fc_aslider_knob"] retain];
	knobOn = [[NSImage imageNamed:@"fc_aslider_knob_on"] retain];
	knobOffset = -4;
	barImage = [[NSImage imageNamed:@"fc_aslider_bar"] retain];
}

- (void)dealloc
{
	[barImage release];
	[super dealloc];
}

- (void)drawBarInside:(NSRect)aRect flipped:(BOOL)flipped
{
	[barImage compositeToPoint: NSMakePoint(aRect.origin.x,aRect.origin.y+(aRect.size.height/2)) operation:NSCompositeSourceOver];
}

- (BOOL)_usesCustomTrackImage {
	return YES;
}
@end

@implementation FullscreenControlsVolumeSlider
- (void)awakeFromNib
{
	NSSliderCell* oldCell = [self cell];
	VolumeSliderCell *cell = [[[FullscreenControlsVolumeSliderCell alloc] init] retain];
	
	[cell setTag:[oldCell tag]];
	[cell setTarget:[oldCell target]];
	[cell setAction:[oldCell action]];
	[cell setControlSize:[oldCell controlSize]];
	[cell setMinValue:[oldCell minValue]];
	[cell setMaxValue:[oldCell maxValue]];
	[cell setDoubleValue:[oldCell doubleValue]];
	//[cell setNumberOfTickMarks:[oldCell numberOfTickMarks]];
	//[cell setTickMarkPosition:[oldCell tickMarkPosition]];
	
	[self setCell:cell];
	[self setNeedsDisplay:YES];
	
	[cell release];
}
@end