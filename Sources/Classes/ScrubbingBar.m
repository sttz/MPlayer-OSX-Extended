/*
 *  ScrubbingBar.h
 *  MPlayer OS X
 *
 *  Created by Jan Volf on Mon Apr 14 2003.
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "ScrubbingBar.h"


@implementation ScrubbingBar:NSProgressIndicator
- (void)awakeFromNib
{
	myStyle = NSScrubbingBarEmptyStyle;
	// load images that forms th scrubbing bar
	scrubBarEnds = [[NSImage alloc] initWithContentsOfFile:
			[[NSBundle mainBundle] pathForResource:@"scrub_bar_ends" ofType:@"tif"]];
	scrubBarRun = [[NSImage alloc] initWithContentsOfFile:
			[[NSBundle mainBundle] pathForResource:@"scrub_bar_run" ofType:@"tif"]];
	scrubBarBadge = [[NSImage alloc] initWithContentsOfFile:
			[[NSBundle mainBundle] pathForResource:@"scrub_bar_badge" ofType:@"tif"]];
	
	//load image for progressbar
	NSSize animSize = NSMakeSize([self bounds].size.width+10,[self bounds].size.height);
	scrubBarAnim = [[NSImage alloc] initWithSize:animSize];
	scrubBarAnimFrame = [[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource:@"scrub_bar_anim" ofType:@"png"]];
			
	[scrubBarAnim lockFocus];
	int numFrames = round([scrubBarAnim size].width/10);
	int i = 0;
	for (i = 0; i < numFrames; i++)
	{
        [scrubBarAnimFrame compositeToPoint:NSMakePoint(i * 10, 0) operation:NSCompositeCopy];
    }
	[scrubBarAnim unlockFocus];
	animFrame = 0;
	
	[self display];
}

- (void) dealloc
{
	if (scrubBarEnds) [scrubBarEnds release];
	if (scrubBarRun) [scrubBarRun release];
	if (scrubBarBadge) [scrubBarBadge release];
	[scrubBarAnimFrame release];
	[scrubBarAnim release];
	
	[super dealloc];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if ([self style] == NSScrubbingBarPositionStyle)
		postNotification(self, theEvent);
}
- (void)mouseDragged:(NSEvent *)theEvent
{
	if ([self style] == NSScrubbingBarPositionStyle)
		postNotification(self, theEvent);
}
- (BOOL)mouseDownCanMoveWindow
{
	if ([self style] == NSScrubbingBarPositionStyle)
		return NO;
	return YES;
}
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	if ([self style] == NSScrubbingBarPositionStyle)
		return YES;
	return NO;
}

- (BOOL)isFlipped
{	
	return NO;
}

- (void)drawRect:(NSRect)aRect
{
	float runLength = [self bounds].size.width - [scrubBarEnds size].width;
	float endWidth = [scrubBarEnds size].width / 2;		// each half of the picture is one end
	float yOrigin = [self bounds].origin.y + 1;
	double theValue = [self doubleValue] / ([self maxValue] - [self minValue]);
	
	//resize bar animation
	//load image for progressbar
	NSSize animSize = NSMakeSize([self bounds].size.width+10,[self bounds].size.height);
	scrubBarAnim = [[NSImage alloc] initWithSize:animSize];
	//scrubBarAnimFrame = [[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource:@"scrub_bar_anim" ofType:@"png"]];
			
	[scrubBarAnim lockFocus];
	int numFrames = round([scrubBarAnim size].width/10);
	int i = 0;
	for (i = 0; i < numFrames; i++)
	{
        [scrubBarAnimFrame compositeToPoint:NSMakePoint(i * 10, 0) operation:NSCompositeCopy];
    }
	[scrubBarAnim unlockFocus];
	
	//draw bar end left and right
	[scrubBarEnds compositeToPoint:NSMakePoint([self bounds].origin.x, yOrigin) fromRect:NSMakeRect(0,0,endWidth,[scrubBarEnds size].height) operation:NSCompositeSourceOver];
	[scrubBarEnds compositeToPoint:NSMakePoint(NSMaxX([self bounds]) - endWidth,yOrigin) fromRect:NSMakeRect(endWidth,0,endWidth,[scrubBarEnds size].height) operation:NSCompositeSourceOver];
		
	// resize the bar run frame if needed
	if ([scrubBarRun size].width != runLength)
	{
		[scrubBarRun setScalesWhenResized:YES];
		[scrubBarRun setSize:NSMakeSize(runLength, [scrubBarRun size].height)];
		[scrubBarRun recache];
	}

	[scrubBarRun compositeToPoint:NSMakePoint(endWidth,yOrigin) operation:NSCompositeSourceOver];
			
	switch ([self style])
	{
		case NSScrubbingBarPositionStyle :
			//draw position badge
			[scrubBarBadge compositeToPoint: NSMakePoint(endWidth + (runLength - [scrubBarBadge size].width) * theValue, yOrigin) operation:NSCompositeSourceOver];
			break;
		case NSScrubbingBarProgressStyle :
			animFrame += 0.1;
			if(animFrame>1) animFrame=0;
			[scrubBarAnim compositeToPoint: NSMakePoint(-10+(animFrame*10), yOrigin) operation:NSCompositeSourceOver];
			break;
		default :
			break;
	}
}

- (NSScrubbingBarStyle)style
{
	return myStyle;
}
- (void)setStyle:(NSScrubbingBarStyle)style
{
	myStyle = style;
	if (style == NSScrubbingBarProgressStyle)
	{
		[self startAnimation:self];
	}
	else
		[self stopAnimation:nil];
	[self display];
}
- (void)incrementBy:(double)delta
{
	[super incrementBy:delta];
	[self display];
}
- (void)setDoubleValue:(double)doubleValue
{
	[super setDoubleValue:doubleValue];
	[self display];
}
- (void)setIndeterminate:(BOOL)flag
{
	[super setIndeterminate:flag];
	[self display];
}
- (void)setMaxValue:(double)newMaximum
{
	[super setMaxValue:newMaximum];
	[self display];
}
- (void)setMinValue:(double)newMinimum
{
	[super setMinValue:newMinimum];
	[self display];
}
@end

int postNotification (id self, NSEvent *theEvent)
{
	NSPoint thePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	double theValue;
	float minX = [self bounds].origin.x + 5,
		maxX = NSMaxX([self bounds]) - 7,
		minY = 2,
		maxY = 12;
	// set the value
	if (thePoint.y >= minY && thePoint.y < maxY) {
			if (thePoint.x < minX)
				theValue = [self minValue];
			else if (thePoint.x >= maxX)
				theValue = [self maxValue];
			else
				theValue = [self minValue] + (([self maxValue] - [self minValue]) *
						(thePoint.x - minX) / (maxX - minX));
		
		[[NSNotificationCenter defaultCenter]
				postNotificationName:@"SBBarClickedNotification"
				object:self
				userInfo:[NSDictionary 
						dictionaryWithObject:[NSNumber numberWithDouble:theValue]
						forKey:@"SBClickedValue"]];
		return 1;
	}
	
	return 0;
}