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

#import "Debug.h"

// MPlayer OS X VO Protocol
@protocol MPlayerOSXVOProto
- (int) startWithWidth: (bycopy int)width
            withHeight: (bycopy int)height
             withBytes: (bycopy int)bytes
            withAspect: (bycopy int)aspect;
- (void) stop;
- (void) render;
- (void) toggleFullscreen;
- (void) ontop;
@end

// Inter-Thread Protocol
@protocol VOGLVThreadProto
- (void) toggleFullscreen;
- (void) finishToggleFullscreen;
- (void) adaptSize;
- (void) updateInThread;
- (void) drawRectInThread;
@end

#define		WSM_SCALE		1
#define		WSM_FIT_SCREEN	2
#define		WSM_FIT_WIDTH	3

@interface VideoOpenGLView : NSOpenGLView <MPlayerOSXVOProto>
{
	bool isFullscreen;
	bool switchingToFullscreen;
	bool switchingInProgress;
	bool isClosing;
	bool useFullscreen;
	bool isOntop;
	bool isPlaying;
	bool keepAspect;
	bool panScan;
	NSString *buffer_name;
	
	//CoreVideo
	CVPixelBufferRef currentFrameBuffer;
	CVOpenGLTextureCacheRef textureCache;
	CVOpenGLTextureRef texture;
	NSRect textureFrame;
    GLfloat	lowerLeft[2]; 
    GLfloat lowerRight[2]; 
    GLfloat upperRight[2];
    GLfloat upperLeft[2];
	
	//video texture
	unsigned char *image_data;
	unsigned char *image_buffer;
	uint32_t image_width;
	uint32_t image_height;
	uint32_t image_bytes;
	float image_aspect;
	float org_image_aspect;
	
	// video size mode
	int videoSizeMode;
	// zoom factor
	float zoomFactor;
	// fit width
	int fitWidth;
	
	//shared memory
	int shm_fd;
	
	// fullscreen switching
	NSSize old_win_size;
	NSRect old_view_frame;
	
	//struct shmid_ds shm_desc;
	
	//Movie menu outlets
	IBOutlet id HalfSizeMenuItem;
	IBOutlet id NormalSizeMenuItem;
	IBOutlet id DoubleSizeMenuItem;
	//IBOutlet id FullScreenMenuItem;
	IBOutlet id KeepAspectMenuItem;
	IBOutlet id PanScanMenuItem;
	IBOutlet id OriginalAspectMenuItem;
	IBOutlet id Aspect4to3MenuItem;
	IBOutlet id Aspect3to2MenuItem;
	IBOutlet id Aspect5to3MenuItem;
	IBOutlet id Aspect16to9MenuItem;
	IBOutlet id Aspect185to1MenuItem;
	IBOutlet id Aspect239to1MenuItem;
	IBOutlet id CustomAspectMenuItem;
	
	// other controllers outlets
	IBOutlet id	playListController;
	IBOutlet id appController;
	IBOutlet id preferencesController;
	IBOutlet id settingsController;
	IBOutlet id playerController;
	
	IBOutlet PlayerFullscreenWindow* fullscreenWindow;
	
	// Inter-thread communication
	NSPort *port1;
	NSPort *port2;
	NSDistantObject *threadProxy;
	id <VOGLVThreadProto> threadProto;
}

- (void) connectToServer:(NSArray *)ports;

// Render Thread methods
- (void)threadMain:(NSArray *)ports;
- (void)prepareOpenGL;
- (int) startWithWidth: (int)width withHeight: (int)height withBytes: (int)bytes withAspect: (int)aspect;
- (void) stop;
- (void) render;
- (void) doRender;
- (void) clear;
- (void) adaptSize;
- (void) toggleFullscreen;
- (void) finishToggleFullscreen;
- (void) updateInThread;
- (void) drawRectInThread;

// Main Thread methods
- (NSString *)bufferName;
- (void) startOpenGLView;
- (BOOL) isFullscreen;
- (void) toggleFullscreenWindow;
- (void) toggleFullscreenWindowContinued;
- (void) toggleFullscreenEnded;
- (void) reshape;
- (void) resizeView;
- (void) close;
- (void) finishClosing;
- (void) setWindowSizeMode:(int)mode withValue:(float)val;
- (void) ontop;

//Action
- (IBAction)MovieMenuAction:(id)sender;
//Event
- (void) mouseDown: (NSEvent *) theEvent;

// Helper methods
- (void) setFrame:(NSRect)frame onWindow:(NSWindow *)window blocking:(BOOL)blocking;

@end
