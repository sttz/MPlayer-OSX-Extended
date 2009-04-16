//
//  FullscreenControlsScrubbingBar.m
//  MPlayer OSX
//
//  Created by Adrian on 04.11.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

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
