/*
 *  ScrubbingBar.h
 *  MPlayer OS X
 *
 *  Created by Jan Volf on Mon Apr 14 2003.
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "ScrubbingBar.h"
#import "Debug.h"

@implementation ScrubbingBar:NSProgressIndicator
- (void)awakeFromNib
{
	myStyle = NSScrubbingBarEmptyStyle;
	// load images that forms th scrubbing bar
	[self loadImages];
	
	// Register for notification to check when we need to redraw the animation image
	[self setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self 
		selector:@selector(redrawAnim) name:NSViewFrameDidChangeNotification object:nil];
	[self redrawAnim];
	
	[self setNeedsDisplay:YES];
}

- (void)redrawAnim
{
	int frameWidth = [scrubBarAnimFrame size].width;
	
	// Only redraw if current image is too small
	if ([scrubBarAnim size].width > [self frame].size.width + frameWidth)
		return;
	
	NSSize animSize = NSMakeSize([self frame].size.width+(frameWidth*3),[self frame].size.height);
	[scrubBarAnim release];
	scrubBarAnim = [[NSImage alloc] initWithSize:animSize];
	
	[scrubBarAnim lockFocus];
	int numFrames = round([scrubBarAnim size].width/frameWidth);
	int i = 0;
	for (i = 0; i < numFrames; i++)
	{
        [scrubBarAnimFrame compositeToPoint:NSMakePoint(i * frameWidth, 0) operation:NSCompositeCopy];
    }
	[scrubBarAnim unlockFocus];
}

- (void) loadImages
{
	scrubBarEnds = [[NSImage alloc] initWithContentsOfFile:
					[[NSBundle mainBundle] pathForResource:@"scrub_bar_ends" ofType:@"tif"]];
	scrubBarRun = [[NSImage alloc] initWithContentsOfFile:
				   [[NSBundle mainBundle] pathForResource:@"scrub_bar_run" ofType:@"tif"]];
	scrubBarBadge = [[NSImage alloc] initWithContentsOfFile:
					 [[NSBundle mainBundle] pathForResource:@"scrub_bar_badge" ofType:@"tif"]];
	scrubBarAnimFrame = [[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource:@"scrub_bar_anim" ofType:@"png"]];
	
	badgeOffset = 0;
	rightClip = 1;
}

- (void) dealloc
{
	[scrubBarEnds release];
	[scrubBarRun release];
	[scrubBarBadge release];
	[scrubBarAnimFrame release];
	[scrubBarAnim release];
	
	if (animationTimer) {
		[animationTimer invalidate];
		[animationTimer release];
	}
	
	[super dealloc];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if ([self style] == NSScrubbingBarPositionStyle)
		postNotification(self, theEvent, [scrubBarBadge size]);
}
- (void)mouseDragged:(NSEvent *)theEvent
{
	if ([self style] == NSScrubbingBarPositionStyle)
		postNotification(self, theEvent, [scrubBarBadge size]);
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
	
	float runLength = [self frame].size.width - [scrubBarEnds size].width;
	float endWidth = [scrubBarEnds size].width / 2;		// each half of the picture is one end
	float yOrigin = 1;
	double theValue = [self doubleValue] / ([self maxValue] - [self minValue]);	
	
	//draw bar end left and right
	[scrubBarEnds compositeToPoint:NSMakePoint(0, yOrigin) fromRect:NSMakeRect(0,0,endWidth,[scrubBarEnds size].height) operation:NSCompositeSourceOver];
	[scrubBarEnds compositeToPoint:NSMakePoint([self frame].size.width - endWidth,yOrigin) fromRect:NSMakeRect(endWidth,0,endWidth,[scrubBarEnds size].height) operation:NSCompositeSourceOver];
	
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
			[scrubBarBadge compositeToPoint: NSMakePoint(endWidth + (runLength - [scrubBarBadge size].width) * theValue, yOrigin + badgeOffset) operation:NSCompositeSourceOver];
			break;
		case NSScrubbingBarProgressStyle :
			[scrubBarAnim 
				drawInRect:NSMakeRect(0, yOrigin, [self frame].size.width - rightClip, [self frame].size.height) 
				fromRect:NSMakeRect((1.0 - animFrame) * [scrubBarAnimFrame size].width, 0, [self frame].size.width - rightClip, [scrubBarAnim size].height) 
				operation:NSCompositeSourceAtop fraction:1.0];
			break;
		default :
			break;
	}
}

- (void)animate:(NSTimer *)aTimer
{
	if ([[self window] isVisible]) {
		animFrame += 0.1;
		if(animFrame>1) animFrame=0;
		[self setNeedsDisplay:YES];
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
		[self startMyAnimation];
	else
		[self stopMyAnimation];
	[self setNeedsDisplay:YES];
}

- (void)startMyAnimation
{
	[self startAnimation:self];
	if (animationTimer == NULL) {
		animationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.05 
								target:self selector:@selector(animate:) 
								userInfo:nil repeats:YES] retain];
		
	}
}

- (void)stopMyAnimation
{
	[self stopAnimation:self];
	if (animationTimer) {
		[animationTimer invalidate];
		[animationTimer release];
		animationTimer = NULL;		
	}
}

- (void)incrementBy:(double)delta
{
	[super incrementBy:delta];
	[self setNeedsDisplay:YES];
}

- (void)setDoubleValue:(double)doubleValue
{
	[super setDoubleValue:doubleValue];
	[self setNeedsDisplay:YES];
}

- (void)setIndeterminate:(BOOL)flag
{
	[super setIndeterminate:flag];
	[self setNeedsDisplay:YES];
}

- (void)setMaxValue:(double)newMaximum
{
	[super setMaxValue:newMaximum];
	[self setNeedsDisplay:YES];
}

- (void)setMinValue:(double)newMinimum
{
	[super setMinValue:newMinimum];
	[self setNeedsDisplay:YES];
}

@end

int postNotification (id self, NSEvent *theEvent, NSSize badgeSize)
{
	NSPoint thePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	double theValue;
	float imageHalf = badgeSize.width / 2;
	float minX = NSMinX([self bounds]) + imageHalf,
		maxX = NSMaxX([self bounds]) - imageHalf;
	
	// set the value
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