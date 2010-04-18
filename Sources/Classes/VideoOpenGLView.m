#import <Carbon/Carbon.h>
#import <Foundation/NSByteOrder.h>

// other controllers
#import "AppController.h"
#import "MenuController.h"

//Custom Class
#import "VideoOpenGLView.h"
#import "PlayerController.h"

#import "PreferencesController2.h"
#import "Preferences.h"

#import "CocoaAdditions.h"

static NSString *VVAnimationsDidEnd = @"VVAnimationsDidEnd";

static unsigned int videoViewId;

@implementation VideoOpenGLView

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [super initWithCoder:aDecoder]))
		return nil;
	
	zoomFactor = 1;
	
	// Choose buffer name and pass it on the way to mplayer
	buffer_name = [[NSString stringWithFormat:@"mplayerosx-%i-%u", 
					[[NSProcessInfo processInfo] processIdentifier], 
					videoViewId++] retain];
	
	return self;
}

- (void) awakeFromNib
{
	renderer = [[MPlayerVideoRenderer alloc] initWithContext:[self openGLContext] andConnectionName:buffer_name];
	[renderer setDelegate:self];
	
	ctx = [[self openGLContext] CGLContextObj];
	
	// Watch for aspect ratio changes
	[PREFS addObserver:self
			forKeyPath:MPEAspectRatio
			   options:0
			   context:nil];
	
	// Watch for scale mode changes
	[PREFS addObserver:self
			forKeyPath:MPEScaleMode
			   options:(NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew)
			   context:nil];
}

- (void) dealloc
{
	[buffer_name release];
	[renderer release];
	
	[super dealloc];
}

- (NSString *)bufferName
{
	return [[buffer_name retain] autorelease];
}

- (void)startRenderingWithSize:(NSValue *)sizeValue {
	
	video_size = [sizeValue sizeValue];
	video_aspect = org_video_aspect = video_size.width / video_size.height;
	
	// Aspect ratio
	[self setAspectRatioFromPreferences];
	
    if (isFullscreen) {
		
		[fullscreenWindow makeKeyAndOrderFront:nil];
		isFullscreen = YES;
		
	} else {
		
		[self resizeView];
	}
    
	//Play in fullscreen
	if ([PREFS integerForKey:MPEStartPlaybackDisplayType] == MPEStartPlaybackDisplayTypeFullscreen)
		[self toggleFullscreen];
}

/*
	Return if currently in fullscreen
 */
- (BOOL) isFullscreen
{
	return isFullscreen;
}

/*
	Toggle fullscreen on the gui side
 */
- (void) toggleFullscreen
{
	// wait until finished before switching again
	if (switchingInProgress)
		return;
	switchingInProgress = YES;
	
	if(!isFullscreen) {
		switchingToFullscreen = YES;
	} else {
		switchingToFullscreen = NO;
		isFullscreen = NO;
	}
	
	int fullscreenId = [playerController fullscreenDeviceId];
	NSRect screen_frame = [[[NSScreen screens] objectAtIndex:fullscreenId] frame];
	/*screen_frame.origin.x = 500;
	screen_frame.origin.y = 500;
	screen_frame.size.width = 200;
	screen_frame.size.height = 200;*/
	
	if (switchingToFullscreen) {
		
		// hide menu and dock if on same screen
		if (fullscreenId == 0)
			SetSystemUIMode( kUIModeAllSuppressed, 0);
		
		// place fswin above video in player window
		NSRect rect = [self frame];
		rect.origin = [[playerController playerWindow] convertBaseToScreen:rect.origin];
		[fullscreenWindow setFrame:rect display:NO animate:NO];
		
		[playerController syncWindows:YES];
		[fullscreenWindow makeKeyAndOrderFront:nil];
		[self updateOntop];
		
		[fullscreenWindow setFullscreen:YES];
		
		// Save current frame for back transition
		old_view_frame = [self frame];
		// save window size for back transition
		old_win_size = [[playerController playerWindow] frame].size;
		
		// move view to fswin and redraw to avoid flicker
		[fullscreenWindow setContentView:self];
		[self drawRect:rect];
		
		[self setFrame:screen_frame onWindow:fullscreenWindow blocking:NO];
		
		NSRect frame = [[playerController playerWindow] frame];
		frame.size = [[playerController playerWindow] contentMinSize];
		frame = [[playerController playerWindow] frameRectForContentRect:frame];
		
		[self setFrame:frame onWindow:[playerController playerWindow] blocking:NO];
		
		if ([PREFS boolForKey:MPEBlackOutOtherScreensInFullscreen])
			[self blackScreensExcept:fullscreenId];
		
		// wait for animation to finish
		if ([[AppController sharedController] animateInterface]) {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishToggleFullscreen) 
														 name:VVAnimationsDidEnd object:self];
		} else
			[self finishToggleFullscreen];
	
	} else {
		
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:NSWindowDidMoveNotification
													  object:fullscreenWindow];
		
		// unhide player window
		if (![[playerController playerWindow] isVisible])
			[[playerController playerWindow] orderWindow:NSWindowBelow
											  relativeTo:[fullscreenWindow windowNumber]];
		
		NSRect win_frame = [[playerController playerWindow] frame];
		win_frame.size = old_win_size;
		
		[self setFrame:win_frame onWindow:[playerController playerWindow] blocking:NO];
		
		// move player window below fullscreen window
		[playerController syncWindows:NO];
		[[playerController playerWindow] orderWindow:NSWindowBelow relativeTo:[fullscreenWindow windowNumber]];
		[[playerController playerWindow] makeKeyWindow];
		
		[fullscreenWindow setFullscreen:NO];
		[fullscreenWindow stopMouseTracking];
		
		// resize fullscreen window back onto video view
		NSRect rect = old_view_frame;
		rect.origin = [[playerController playerWindow] convertBaseToScreen:rect.origin];
		
		[self setFrame:rect onWindow:fullscreenWindow blocking:NO];
		
		[self unblackScreens];
		
		// wait for animation to finish
		if ([[AppController sharedController] animateInterface]) {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishToggleFullscreen) 
														 name:VVAnimationsDidEnd object:self];
		} else
			[self finishToggleFullscreen];
	}
}

- (void) fullscreenWindowMoved:(NSNotification *)notification
{
	// triggered when fullscreen window changes spaces
	int fullscreenId = [playerController fullscreenDeviceId];
	NSRect screen_frame = [[[NSScreen screens] objectAtIndex:fullscreenId] frame];
	[fullscreenWindow setFrame:screen_frame display:YES animate:NO];
}

- (void) finishToggleFullscreen
{
	
	if (switchingToFullscreen) {
		
		// hide player window
		if ([[playerController playerWindow] screen] == [fullscreenWindow screen])
			[[playerController playerWindow] orderOut:self];
		
		[fullscreenWindow startMouseTracking];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(fullscreenWindowMoved:)
													 name:NSWindowDidMoveNotification
												   object:fullscreenWindow];
		
	} else {
		
		[fullscreenWindow orderOut:nil];
		
		// move view back, place and redraw
		[[[playerController playerWindow] contentView] addSubview:self];
		[self setFrame:old_view_frame];
		[self drawRect:old_view_frame];
		
		//exit kiosk mode
		SetSystemUIMode( kUIModeNormal, 0);
		
		// reset drag point
		dragStartPoint = NSZeroPoint;
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:VVAnimationsDidEnd object:nil];
	
	if (switchingToFullscreen)
		isFullscreen = YES;
	
	[self reshape];
	switchingInProgress = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MIFullscreenSwitchDone"
														object:self
													  userInfo:nil];
}

/*
	Black out all screens except fullscreen screen
 */
- (void) blackScreensExcept:(int)fullscreenId
{
	[blackingWindows release];
	blackingWindows = [[NSMutableArray alloc] initWithCapacity:[[NSScreen screens] count]];
	
	unsigned int i;
	NSWindow *win;
	NSRect fs_rect;
	for (i = 0; i < [[NSScreen screens] count]; i++) { 
		// don't black fullscreen screen
		if (i == fullscreenId)
			continue;
		// when blacking the main screen, hide the menu bar and dock
		if (i == 0)
			SetSystemUIMode( kUIModeAllSuppressed, 0);
		
		fs_rect = [[[NSScreen screens] objectAtIndex:i] frame];
		fs_rect.origin = NSZeroPoint;
		win = [[NSWindow alloc] initWithContentRect:fs_rect styleMask:NSBorderlessWindowMask 
											backing:NSBackingStoreBuffered defer:NO screen:[[NSScreen screens] objectAtIndex:i]];
		[win setBackgroundColor:[NSColor blackColor]];
		if ([PREFS boolForKey:MPEFullscreenBlockOthers])
			[win setLevel:NSScreenSaverWindowLevel];
		else
			[win setLevel:NSModalPanelWindowLevel];
		[win orderFront:nil];
		
		if ([[AppController sharedController] animateInterface])
			[self fadeWindow:win withEffect:NSViewAnimationFadeInEffect];
		
		[blackingWindows addObject:win];
		[win release];
	}
	
}

/*
	Remove black out windows
 */
- (void) unblackScreens
{
	if (!blackingWindows)
		return;
	
	unsigned int i;
	for (i = 0; i < [blackingWindows count]; i++) {
		if (![[AppController sharedController] animateInterface])
			[[blackingWindows objectAtIndex:i] close];
		else
			[self fadeWindow:[blackingWindows objectAtIndex:i] withEffect:NSViewAnimationFadeOutEffect];
	}
	
	[blackingWindows release];
	blackingWindows = nil;
}

/*
	Resize OpenGL view to fit movie
*/
- (void) resizeView
{
	if (isFullscreen)
		return;
	
	if (video_size.width == 0 || video_size.height == 0)
		return;
	
	NSRect win_frame = [[self window] frame];
	NSRect mov_frame = [self bounds];
	NSSize minSize = [[self window]contentMinSize];
	NSSize screen_size;
	float fitFactor;
	
	// Determine maximal scale factor to fit screen
	screen_size = [[[playerController playerWindow] screen] visibleFrame].size;
	
	if (screen_size.width / screen_size.height > video_aspect)
		fitFactor = screen_size.height / video_size.height;
	else
		fitFactor = screen_size.width / video_size.width;
	
	// Fit to specific width
	if (windowSizeMode == WSM_FIT_WIDTH)
		zoomFactor = fitWidth / video_size.width;
	
	// Limit factor
	if (windowSizeMode == WSM_FIT_SCREEN || zoomFactor > fitFactor)
		zoomFactor = fitFactor;
	
	// Apply size
	win_frame.size.height += (video_size.height*zoomFactor) - mov_frame.size.height;
	
	if(video_size.height*video_aspect*zoomFactor < minSize.width)
		win_frame.size.width = minSize.width;
	else
		win_frame.size.width += video_size.height*video_aspect*zoomFactor - mov_frame.size.width;
	
	[[self window] setFrame:win_frame display:YES animate:[[AppController sharedController] animateInterface]];
	
	// remove fullscreen callback
	[[NSNotificationCenter defaultCenter] removeObserver:self
		name: @"MIFullscreenSwitchDone"
		object: self];
}

/*
	Calculate bounds for video
*/
- (NSRect) videoFrame
{
	NSRect displayFrame = [self bounds];
	NSRect videoFrame = displayFrame;
	
	// Display frame is video frame for stretch to fill
	if (videoScaleMode == MPEScaleModeStertchToFill)
		return videoFrame;
	
	// Video is taller than display frame if aspect is smaller -> Fit height
	BOOL fitHeight = (video_aspect < (displayFrame.size.width / displayFrame.size.height));
	
	// Reverse for zoom to fill
	if (videoScaleMode == MPEScaleModeZoomToFill)
		fitHeight = !fitHeight;
	
	if (fitHeight)
		videoFrame.size.width = videoFrame.size.height * video_aspect;
	else
		videoFrame.size.height = videoFrame.size.width * (1 / video_aspect);
	
	// Center video
	videoFrame.origin.x = (displayFrame.size.width - videoFrame.size.width) / 2;
	videoFrame.origin.y = (displayFrame.size.height - videoFrame.size.height) / 2;
	
	return videoFrame;
}

/*
	Reshape and then resize View
*/
- (void) reshapeAndResize
{
	[self reshape];
	[self resizeView];
}

/*
	Close OpenGL view
*/
- (void) close
{
	// exit fullscreen and close with callback
	if (isFullscreen) {
		
		[self toggleFullscreen];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(finishClosing) 
			name: @"MIFullscreenSwitchDone"
			object: self];
		
		return;
	}
	
	// not fullscreen: close immediately
	[self finishClosing];
}

- (void) finishClosing
{
	video_size = NSZeroSize;
	video_aspect = org_video_aspect = 0;
	
	// close video view
	NSRect frame = [[self window] frame];
	frame.size = [[playerController playerWindow] contentMinSize];
	frame = [[playerController playerWindow] frameRectForContentRect:frame];
	[[self window] setFrame:frame display:YES animate:[[AppController sharedController] animateInterface]];
	
	// remove fullscreen callback
	[[NSNotificationCenter defaultCenter] removeObserver:self
		name: @"MIFullscreenSwitchDone"
		object: self];
	
	// post view closed notification
	[[NSNotificationCenter defaultCenter]
		postNotificationName:@"MIVideoViewClosed"
		object:self
		userInfo:nil];
}

/*
 Resize Window with given options
 */
- (void) setWindowSizeMode:(int)mode withValue:(float)val
{
	windowSizeMode = mode;
	
	if (windowSizeMode == WSM_SCALE)
		zoomFactor = val;
	else if (windowSizeMode == WSM_FIT_WIDTH)
		fitWidth = val;
	
	// do not apply if not playing
	if (video_size.width == 0)
		return;
	
	// exit fullscreen first and finish with callback
	if (isFullscreen) {
		
		[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(resizeView) 
			name: @"MIFullscreenSwitchDone"
			object: self];
		
	} else
		// not in fullscreen: resize now
		[self resizeView];
}

/*
	Set Ontop (sent by PlayerController)
*/
- (void) setOntop:(BOOL)ontop
{
	isOntop = ontop;
	[self updateOntop];
}

/*
	Update window level based on ontop status
*/
- (void) updateOntop
{
	if ([fullscreenWindow isVisible] && (isOntop || [PREFS boolForKey:MPEFullscreenBlockOthers])) {
		NSInteger level = NSModalPanelWindowLevel;
		if ([PREFS boolForKey:MPEFullscreenBlockOthers])
			level = NSScreenSaverWindowLevel;
		
		[fullscreenWindow setLevel:level];
		[fcControlWindow  setLevel:level];
		
		[fullscreenWindow orderWindow:NSWindowBelow relativeTo:[fcControlWindow windowNumber]];
		[[playerController playerWindow] orderWindow:NSWindowBelow relativeTo:[fullscreenWindow windowNumber]];
	} else {
		[fullscreenWindow setLevel:NSNormalWindowLevel];
		[fcControlWindow  setLevel:NSNormalWindowLevel];
	}
}

/*
	View changed: synchronized call to the renderer
 */
- (void) reshape
{
	[renderer boundsDidChangeTo:[self bounds] withVideoFrame:[self videoFrame]];
}

- (void) update
{
	CGLLockContext([[self openGLContext] CGLContextObj]);
	[[self openGLContext] update];
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

- (void) drawRect: (NSRect) bounds
{
	[renderer redraw];
}

/*
	Set video scale mode
*/
- (void) setVideoScaleMode:(MPEVideoScaleMode)scaleMode
{
	MenuController *menuController = [[AppController sharedController] menuController];
	[menuController->zoomToFitMenuItem     setState:(scaleMode == MPEScaleModeZoomToFit)];
	[menuController->zoomToFillMenuItem	   setState:(scaleMode == MPEScaleModeZoomToFill)];
	[menuController->stretchToFillMenuItem setState:(scaleMode == MPEScaleModeStertchToFill)];
	
	videoScaleMode = scaleMode;
	
	[self reshape];
}

/*
	Set aspect ratio by parsing the menu item title
*/
- (void)setAspectRatioFromPreferences
{
	if ([PREFS objectForKey:MPEAspectRatio]) {
		float aspectValue;
		
		if (![[PREFS stringForKey:MPEAspectRatio] isEqualToString:@"Custom"])
			aspectValue = [PreferencesController2 parseAspectRatio:[PREFS stringForKey:MPEAspectRatio]];
		else
			aspectValue = [[[PREFS objectForKey:MPECustomAspectRatio] objectForKey:MPECustomAspectRatioValueKey] floatValue];
		
		if (aspectValue <= 0)
			[Debug log:ASL_LEVEL_ERR withMessage:@"Couldn't parse aspect ratio from preferences: %@ %@",
			 [PREFS stringForKey:MPEAspectRatio],[PREFS stringForKey:MPECustomAspectRatio]];
		else
			[self setAspectRatio:aspectValue];
	} else
		[self setAspectRatio:org_video_aspect];
}

/*
	Watch for preferences changes
*/
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:MPEAspectRatio])
		[self setAspectRatioFromPreferences];
	else if ([keyPath isEqualToString:MPEScaleMode])
		[self setVideoScaleMode:[change integerForKey:NSKeyValueChangeNewKey]];
}

/*
	Set aspect ratio
*/
- (void)setAspectRatio:(float)aspect
{
	if (aspect > 0)
		video_aspect = aspect;
	else
		video_aspect = org_video_aspect;
	
	[self reshapeAndResize];
}
		 
/*
	Mouse down handler for fullscreen and dragging
*/
- (void) mouseDown: (NSEvent *) theEvent
{
	if ([theEvent clickCount] == 2) {
		[playerController switchFullscreen: self];
	
	} else {
		// save start for dragging window
		NSRect windowFrame = [[self window] frame];
		dragStartPoint = [[self window] convertBaseToScreen:[theEvent locationInWindow]];
		dragStartPoint.x -= windowFrame.origin.x;
		dragStartPoint.y -= windowFrame.origin.y;
	}
}

/*
	Show contextual menu
 */
- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	return [playerController contextMenu];
}

/*
	Allow the window to be dragged with this view
*/
- (void)mouseDragged:(NSEvent *)theEvent
{
	// don't allow dragging when fullscreen or while switching
	if (isFullscreen || switchingInProgress)
		return;
	
	if (dragStartPoint.x == 0 && dragStartPoint.y == 0)
		return;
	
	NSPoint currentDragPoint;
	NSPoint newOrigin;
	
    currentDragPoint = [[self window] convertBaseToScreen:[[self window] mouseLocationOutsideOfEventStream]];
    newOrigin.x = currentDragPoint.x - dragStartPoint.x;
    newOrigin.y = currentDragPoint.y - dragStartPoint.y;
    
    [[self window] setFrameOrigin:newOrigin];
}

/*
	Make drag operation start even if window is intially in the back
*/
- (BOOL)mouseDownCanMoveWindow
{
    return YES;
}

/*
	Animate frame change on window with additional blocking option
*/
- (void) setFrame:(NSRect)frame onWindow:(NSWindow *)window blocking:(BOOL)blocking
{
	// apply directly if animations are disabled
	if (![[AppController sharedController] animateInterface]) {
		[window setFrame:frame display:YES];
		return;
	}/* else {
		[window setFrame:frame display:YES animate:YES];
		return;
	}*/
	
	NSViewAnimation *anim;
	NSMutableDictionary *animInfo;
	
	animInfo = [NSMutableDictionary dictionaryWithCapacity:3];
	[animInfo setObject:window forKey:NSViewAnimationTargetKey];
	[animInfo setObject:[NSValue valueWithRect:[window frame]] forKey:NSViewAnimationStartFrameKey];
	[animInfo setObject:[NSValue valueWithRect:frame] forKey:NSViewAnimationEndFrameKey];
	
	anim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animInfo]];
	[anim setDelegate:self];
	
	[anim setDuration:[window animationResizeTime:frame]];
	if (!blocking)
		[anim setAnimationBlockingMode:NSAnimationNonblocking];
	else
		[anim setAnimationBlockingMode:NSAnimationBlocking];
	
	[anim startAnimation];
	[anim release];
	
	runningAnimations++;
}

/*
	Animate window fading in/out
*/
- (void) fadeWindow:(NSWindow *)window withEffect:(NSString *)effect
{
	
	NSViewAnimation *anim;
	NSMutableDictionary *animInfo;
	
	animInfo = [NSMutableDictionary dictionaryWithCapacity:2];
	[animInfo setObject:window forKey:NSViewAnimationTargetKey];
	[animInfo setObject:effect forKey:NSViewAnimationEffectKey];
	
	anim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animInfo]];
	[anim setAnimationBlockingMode:NSAnimationNonblockingThreaded];
	[anim setAnimationCurve:NSAnimationEaseIn];
	[anim setDuration:0.3];
	
	[anim startAnimation];
	[anim release];
}

/*
	Handle animations ending
*/
- (void)animationDidEnd:(NSAnimation *)animation {
	
	runningAnimations--;
	
	if (runningAnimations == 0)
		[[NSNotificationCenter defaultCenter] postNotificationName:VVAnimationsDidEnd object:self]; 
}

@end
