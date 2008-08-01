#import "VolumeSlider.h"

@implementation VolumeSliderCell
- (id)init
{
	knobOff = [[NSImage imageNamed:@"volumeKnobOff"] retain];
	knobOn = [[NSImage imageNamed:@"volumeKnobOn"] retain];
	isKnobSelected = NO;
	return [super init];
}

- (void)drawKnob:(NSRect)knobRect
{
	NSImage *knob;
	
	if(isKnobSelected)
		knob = knobOn;
	else
		knob = knobOff;

	[[self controlView] lockFocus];
	[knob compositeToPoint: NSMakePoint(knobRect.origin.x,knobRect.origin.y+knobRect.size.height-2) operation:NSCompositeSourceOver];
	[[self controlView] unlockFocus];
}

- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
	isKnobSelected = YES;
	return [super startTrackingAt:startPoint inView:controlView];
}

- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
	isKnobSelected = NO;
	[super stopTracking:lastPoint at:stopPoint inView:controlView mouseIsUp:flag];
}
@end

@implementation VolumeSlider
- (void)awakeFromNib
{
	NSSliderCell* oldCell = [self cell];
	VolumeSliderCell *cell = [[[VolumeSliderCell alloc] init] retain];

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
	[self display];
	
	[cell release];
}
@end
