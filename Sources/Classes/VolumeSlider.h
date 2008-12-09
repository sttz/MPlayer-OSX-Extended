/* VolumeSlider */

#import <Cocoa/Cocoa.h>

@interface VolumeSliderCell : NSSliderCell
{
	NSImage *knobOff;
	NSImage *knobOn;
	
	int knobOffset;
	
	BOOL isKnobSelected;
}
- (void)loadImages;
@end

@interface VolumeSlider : NSSlider
{
}
@end
