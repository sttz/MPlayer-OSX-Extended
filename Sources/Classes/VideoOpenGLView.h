/* MyOpenGLView */

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <QuartzCore/QuartzCore.h>

//include for shared memory
#include <sys/shm.h>

//custom class
#import "PlayerWindow.h"
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

@interface VideoOpenGLView : NSOpenGLView <MPlayerOSXVOProto>
{
	NSRect screen_frame;
	bool isFullscreen;
	bool useFullscreen;
	bool isOntop;
	bool isPlaying;
	bool keepAspect;
	bool panScan;
	bool hideMouse;
	
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
	
	//shared memory
	int shm_id;
	struct shmid_ds shm_desc;
	
	//Movie menu outlets
	IBOutlet id HalfSizeMenuItem;
	IBOutlet id NormalSizeMenuItem;
	IBOutlet id DoubleSizeMenuItem;
	//IBOutlet id FullScreenMenuItem;
	IBOutlet id KeepAspectMenuItem;
	IBOutlet id PanScanMenuItem;
	IBOutlet id OriginalAspectMenuItem;
	IBOutlet id FullAspectMenuItem;
	IBOutlet id WideAspectMenuItem;
	//IBOutlet id CustomAspectMenuItem;
	
	// other controllers outlets
	IBOutlet id	playListController;
	IBOutlet id appController;
	IBOutlet id preferencesController;
	IBOutlet id settingsController;
	IBOutlet id playerController;
	
	IBOutlet id fullscreenWindow;
}

- (void)prepareOpenGL;
- (NSEvent *) readNextEvent;
- (int) startWithWidth: (int)width withHeight: (int)height withBytes: (int)bytes withAspect: (int)aspect;
- (void) stop;
- (void) close;
- (void) render;
- (void) doRender;
- (void) clear;
- (void) reshape;
- (void) resizeToMovie;
- (void) setWindowSizeMult: (float)zoom;
- (void) toggleFullscreen;
- (void) ontop;

//Action
- (IBAction)MovieMenuAction:(id)sender;

//Event
- (void) mouseDown: (NSEvent *) theEvent;

@end
