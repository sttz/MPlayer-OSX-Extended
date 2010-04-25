/* MyOpenGLView */

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <QuartzCore/QuartzCore.h>

//include for shared memory
#include <sys/mman.h>

//custom class
#import "PlayerWindow.h"
#import "PlayerFullscreenWindow.h"
#import "PlayListController.h"

#import "MPlayerVideoRenderer.h"

#import "Debug.h"

#define		WSM_SCALE		1
#define		WSM_FIT_SCREEN	2
#define		WSM_FIT_WIDTH	3

enum {
	MPEScaleModeZoomToFit,
	MPEScaleModeZoomToFill,
	MPEScaleModeStertchToFill
};
typedef NSUInteger MPEVideoScaleMode;

@class PlayerController;

@interface VideoOpenGLView : NSOpenGLView <MPlayerVideoRenderereDelegateProtocol>
{
	MPlayerVideoRenderer *renderer;
	
	BOOL isFullscreen;
	BOOL switchingToFullscreen;
	BOOL switchingInProgress;
	BOOL isOntop;
	NSString *buffer_name;
	
	CGLContextObj ctx;
	
	//video texture
	NSSize video_size;
	float video_aspect;
	float org_video_aspect;
	
	// video size mode
	int windowSizeMode;
	MPEVideoScaleMode videoScaleMode;
	// zoom factor
	float zoomFactor;
	// fit width
	int fitWidth;
	
	// fullscreen switching
	NSSize old_win_size;
	NSRect old_view_frame;
	
	// screen blacking
	NSMutableArray *blackingWindows;
	
	// window dragging
	NSPoint dragStartPoint;
	
	// animations
	unsigned int runningAnimations;
	
	//Movie menu outlets
	IBOutlet NSMenuItem* KeepAspectMenuItem;
	IBOutlet NSMenuItem* PanScanMenuItem;	
	// other controllers outlets
	IBOutlet PlayerController *playerController;
	
	IBOutlet NSWindow *fcControlWindow;
	IBOutlet PlayerFullscreenWindow* fullscreenWindow;
}

// Render Thread methods
- (void) toggleFullscreen;
- (void) finishToggleFullscreen;

// Main Thread methods
- (NSString *)bufferName;
- (BOOL) isFullscreen;
- (void) blackScreensExcept:(int)fullscreenId;
- (void) unblackScreens;
- (NSRect) videoFrame;
- (void) reshape;
- (void) resizeView;
- (void) reshapeAndResize;
- (void) close;
- (void) finishClosing;
- (void) setWindowSizeMode:(int)mode withValue:(float)val;
- (void) setOntop:(BOOL)ontop;
- (void) updateOntop;
- (void) setAspectRatio:(float)aspect;
- (void) setAspectRatioFromPreferences;
- (void) setVideoScaleMode:(MPEVideoScaleMode)scaleMode;
- (void) fullscreenWindowMoved:(NSNotification *)notification;

// Event
- (void) mouseDown: (NSEvent *) theEvent;

// Helper methods
- (void) setFrame:(NSRect)frame onWindow:(NSWindow *)window blocking:(BOOL)blocking;
- (void) fadeWindow:(NSWindow *)window withEffect:(NSString *)effect;

@end
