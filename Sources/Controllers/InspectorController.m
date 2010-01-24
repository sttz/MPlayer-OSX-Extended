/*  
 *  InspectorController.m
 *  MPlayer OSX Extended
 *  
 *  Created on 01.01.2010
 *  
 *  Description:
 *	Controller for the inspector pane.
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


#import "InspectorController.h"

#import "AppController.h"
#import "MovieInfo.h"
#import "MPlayerInterface.h"

#import "Preferences.h"
#import "CocoaAdditions.h"

static const float const firstSectionTopOffset  = 40.0f;

static const float const collapsedSectionHeight = 20.0f;

@implementation InspectorController
@synthesize window;

- (void)awakeFromNib
{
	views = [[NSDictionary alloc] initWithObjectsAndKeys:
			 fileAttributesSection,		@"fileAttributes",
			 playbackSettingsSection,	@"playbackSettings",
			 statisticsSection,			@"statistics",
			 nil];
	
	triangles = [[NSDictionary alloc] initWithObjectsAndKeys:
				 fileAttributesTriangle,	@"fileAttributes",
				 playbackSettingsTriangle,	@"playbackSettings",
				 statisticsTriangle,		@"statistics",
				 nil];
	
	sectionOrder = [[NSArray alloc] initWithObjects:
					@"fileAttributes",
					@"playbackSettings",
					@"statistics",
					nil];
	
	NSArray *expanded = [PREFS arrayForKey:MPEExpandedInspectorSections];
	expandedHeights = [NSMutableDictionary new];
	
	for (NSString *name in sectionOrder) {
		NSView *section = [views objectForKey:name];
		
		[expandedHeights setObject:[NSNumber numberWithFloat:[section frame].size.height]
							forKey:name];
		
		[section setPostsFrameChangedNotifications:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(sectionDidResize:)
													 name:NSViewFrameDidChangeNotification
												   object:section];
		
		[container addSubview:section];
		
		BOOL isExpanded = (expanded && [expanded containsObject:name]);
		float width = [section frame].size.width;
		float height;
		if (isExpanded)
			height = [[expandedHeights objectForKey:name] floatValue];
		else
			height = collapsedSectionHeight;
		
		[section setFrameSize:NSMakeSize(width, height)];
		
		[[triangles objectForKey:name] setState:isExpanded];
	}
	
	[self positionSections:nil];
	
	statsExpanded = [expanded containsObject:@"statistics"];
	
	// Observe provider changes to enable/disable statistics capturing
	[[AppController sharedController] addObserver:self
									   forKeyPath:@"movieInfoProvider.currentMovieInfo"
										  options:(NSKeyValueObservingOptionNew|
												   NSKeyValueObservingOptionOld)
										  context:nil];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"movieInfoProvider.currentMovieInfo"]) {
		if (![window isVisible] || !statsExpanded)
			return;
		MovieInfo *old = [change objectForKey:NSKeyValueChangeOldKey];
		MovieInfo *new = [change objectForKey:NSKeyValueChangeNewKey];
		if (old != new) {
			if (![old isKindOfClass:[NSNull class]])
				[old setCaptureStats:NO];
			if (![new isKindOfClass:[NSNull class]])
				[new setCaptureStats:YES];
		}
	}
}

- (void) windowDidBecomeKey:(NSNotification *)notification
{
	if (statsExpanded)
		[[[[AppController sharedController] movieInfoProvider] currentMovieInfo] setCaptureStats:YES];
	
	[PREFS setBool:YES forKey:MPEInspectorOpen];
}

- (void) windowWillClose:(NSNotification *)notification
{
	if (statsExpanded)
		[[[[AppController sharedController] movieInfoProvider] currentMovieInfo] setCaptureStats:NO];
	
	[PREFS setBool:NO forKey:MPEInspectorOpen];
}

- (void) sectionDidResize:(NSNotification *)notification
{
	if (!isResizing)
		[self positionSections:[notification object]];
}

- (void) positionSections:(id)sender
{
	isResizing = YES;
	
	float viewHeight = [container frame].size.height;
	
	float topOffset = firstSectionTopOffset;
	
	for (NSString *name in sectionOrder) {
		NSView *section = [views objectForKey:name];
		float height = [section frame].size.height;
		float width  = [section frame].size.width;
		
		[section setFrame:NSMakeRect(0, viewHeight - topOffset - height, 
									 width, height)];
		
		if (section == sender) {
			float newOriginY = [[scroller contentView] bounds].origin.y + (height - lastSectionHeight);
			[[scroller contentView] scrollToPoint:NSMakePoint(0, newOriginY)];
			lastSectionHeight = height;
		}
		
		topOffset += height;
	}
	
	NSSize contentSize = NSMakeSize([container frame].size.width, topOffset);
	
	NSRect viewRect;
	viewRect.size = contentSize;
	viewRect.origin = [container frame].origin;
	
	NSRect windowRect;
	windowRect.size = NSMakeSize([window frame].size.width, topOffset);
	windowRect = [window frameRectForContentRect:windowRect];
	windowRect.origin = [window frame].origin;
	windowRect.origin.y += [window frame].size.height - windowRect.size.height;
	
	[container setFrame:viewRect];
	
	if ([window frame].size.height >= [window maxSize].height)
		[window setFrame:windowRect display:YES];
	[window setMaxSize:windowRect.size];
	
	isResizing = NO;
}

- (IBAction)toggleSection:(id)sender
{
	NSString *name = [[views allKeysForObject:[sender superview]] objectAtIndex:0];
	NSView *section = [views objectForKey:name];
	NSMutableArray *expanded = [[PREFS arrayForKey:MPEExpandedInspectorSections] mutableCopy];
	
	if (!expanded)
		expanded = [NSMutableArray array];
	
	float height;
	if (![expanded containsObject:name]) {
		[expanded addObject:name];
		height = [[expandedHeights objectForKey:name] floatValue];
	} else {
		[expanded removeObject:name];
		height = collapsedSectionHeight;
	}
	
	if (![sender isKindOfClass:[NSButton class]] || [sender bezelStyle] != NSDisclosureBezelStyle)
		[[triangles objectForKey:name] setState:[expanded containsObject:name]];
	
	lastSectionHeight = [section frame].size.height;
	
	float width = [window frame].size.width;
	[[section animator] setFrameSize:NSMakeSize(width, height)];
	
	[PREFS setObject:expanded forKey:MPEExpandedInspectorSections];
	
	if ([name isEqualToString:@"statistics"]) {
		statsExpanded = [expanded containsObject:name];
		[[[[AppController sharedController] movieInfoProvider] currentMovieInfo] setCaptureStats:statsExpanded];
	}
}

- (IBAction)resetPlaybackSpeed:(id)sender
{
	[playbackSpeed setDoubleValue:100];
	[playbackSpeed performClick:self];
}

- (IBAction)resetAudioDelay:(id)sender
{
	[audioDelay setDoubleValue:0];
	[audioDelay performClick:self];
}

- (IBAction)resetSubtitleDelay:(id)sender
{
	[subtitleDelay setDoubleValue:0];
	[subtitleDelay performClick:self];
}

- (IBAction)resetAudioBoost:(id)sender
{
	[audioBoost setDoubleValue:1.0];
	[audioBoost performClick:self];
}

- (IBAction)resetSubtitleScale:(id)sender
{
	[subtitleScale setDoubleValue:1.0];
	[subtitleScale performClick:self];
}

- (void)dealloc
{
	[views release];
	[triangles release];
	[expandedHeights release];
	[sectionOrder release];
	
	[super dealloc];
}

@end



@implementation MultiplicatorTransformer100Fold

+ (Class)transformedValueClass
{
	return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue:(id)value
{
	NSNumber *speedNumber = value;
	
	if (!speedNumber || ![value isKindOfClass:[NSNumber class]])
		return nil;
	
	float speed = [speedNumber floatValue];
	
	if (speed <= 1.0)
		return [NSNumber numberWithFloat:(speed*self.scale)];
	else
		return [NSNumber numberWithFloat:(speed+(self.scale-1))];

}

- (id)reverseTransformedValue:(id)value
{
	NSNumber *sliderNumber = value;
	
	if (!sliderNumber || ![value isKindOfClass:[NSNumber class]])
		return nil;
	
	float sliderValue = [sliderNumber floatValue];
	
	if (sliderValue <= self.scale)
		return [NSNumber numberWithFloat:(sliderValue/self.scale)];
	else
		return [NSNumber numberWithFloat:(sliderValue-(self.scale-1))];
}

- (float)scale {
	return 100.0;
}

@end
