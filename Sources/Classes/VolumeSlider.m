#import "VolumeSlider.h"
#import "Debug.h"

@implementation VolumeSliderCell
- (id)init
{
	self = [super init];
	if (self) {
		[self loadImages];
		isKnobSelected = NO;
	}
	return self;
}

- (void) dealloc
{
	[knobOff release];
	[knobOn release];
	
	[super dealloc];
}

- (void)loadImages
{
	knobOff = [[NSImage imageNamed:@"volumeKnobOff"] retain];
	knobOn = [[NSImage imageNamed:@"volumeKnobOn"] retain];
	knobOffset = -2;
}

- (void)drawKnob:(NSRect)knobRect
{
	NSImage *knob;
	
	if(isKnobSelected)
		knob = knobOn;
	else
		knob = knobOff;

	[knob compositeToPoint: NSMakePoint(knobRect.origin.x,knobRect.origin.y+knobRect.size.height+knobOffset) operation:NSCompositeSourceOver];
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
	[self setNeedsDisplay:YES];
	
	[cell release];
}
@end
