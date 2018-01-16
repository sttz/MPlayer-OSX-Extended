/* VolumeSlider */

#import <Cocoa/Cocoa.h>

@interface VolumeSliderCell : NSSliderCell
{
	NSImage *knobOff;
	NSImage *knobOn;
	
	int knobOffsetX;
	int knobOffsetY;
	
	BOOL isKnobSelected;
}
- (void)loadImages;
@end

@interface VolumeSlider : NSSlider
{
}
@end
