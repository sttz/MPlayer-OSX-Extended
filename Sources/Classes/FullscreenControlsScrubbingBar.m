/*  
 *  LanguageCodes.m
 *  MPlayerOSX Extended
 *  
 *  Created on 04.11.2008
 *  
 *  Description:
 *	Custom scrubbing bar for the fullscreen controls.
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

#import "FullscreenControlsScrubbingBar.h"


@implementation FullscreenControlsScrubbingBar
- (void) loadImages
{	
	// These will be release in [super dealloc]
	scrubBarEnds = [[NSImage imageNamed:@"fc_scrub_ends"] retain];
	scrubBarRun = [[NSImage imageNamed:@"fc_scrub_run"] retain];
	scrubBarBadge = [[NSImage imageNamed:@"fc_scrub_badge"] retain];
	scrubBarAnimFrame = [[NSImage imageNamed:@"fc_scrub_anim"] retain];
	
	yBadgeOffset = 1;
	xBadgeOffset = 6.5;
	rightClip = 1;
	[self setFrameSize:NSMakeSize([self frame].size.width,[scrubBarEnds size].height)];
	
	
}
@end
