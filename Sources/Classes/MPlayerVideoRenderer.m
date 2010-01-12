/*  
 *  MPlayerVideoRenderer.m
 *  MPlayerOSX Extended
 *  
 *  Created on 10.01.2010
 *  
 *  Description:
 *	Class used to store attributes of a video file.
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

#include <sys/mman.h>
#import <OpenGL/gl.h>

#import "MPlayerVideoRenderer.h"

#import "Debug.h"
#import "CocoaAdditions.h"

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


@interface MPlayerVideoRenderer (PrivateMethods) <MPlayerOSXVOProto>
- (NSInvocation *)invocationForSelector:(SEL)selector;
- (void)callDelegateWithSelector:(SEL)selector andObject:(id)object;
- (void)threadMain;
- (void)renderOpenGL;
- (void)adaptSize;
@end



@implementation MPlayerVideoRenderer
@synthesize delegate;

/* Initialize class to render into openglContext and to communicate with MPlayer using
 * name for the NSConnection and shared memory.
 */
- (id)initWithContext:(NSOpenGLContext *)openglContext andConnectionName:(NSString *)name {
	
	if (!(self = [super init]))
		return nil;
	
	context = [openglContext retain];
	connectionName = [name retain];
	
	renderThread = [[NSThread alloc] initWithTarget:self 
										   selector:@selector(threadMain) 
											 object:nil];
	[renderThread start];
	
	return self;
}

- (void)dealloc {
	
	[context release];
	[connectionName release];
	[renderThread release];
	
	[super dealloc];
}

/* Update OpenGL context and and video frame to bounds (display frame) and 
 * frame (video frame).
 */
- (void)boundsDidChangeTo:(NSRect)bounds withVideoFrame:(NSRect)frame {
	
	CGLLockContext(ctx);
	textureFrame = frame;
	displayFrame = bounds;
	CGLUnlockContext(ctx);
	
	[self adaptSize];
}

/* Force a redraw of the current frame
 */
- (void)redraw {
	
	[self renderOpenGL];
}

@end



@implementation MPlayerVideoRenderer (PrivateMethods)

/* Helper method to get a NSInvocation for a method of the MPlayerVideoRenderereDelegateProtocol.
 */
- (NSInvocation *)invocationForSelector:(SEL)selector {
	
	Protocol *proto = @protocol(MPlayerVideoRenderereDelegateProtocol);
	NSMethodSignature *sig = [proto methodSignatureForSelector:selector
													isRequired:YES 
											  isInstanceMethod:YES];
	NSInvocation *invoc = [NSInvocation invocationWithMethodSignature:sig];
	[invoc setTarget:delegate];
	[invoc setSelector:selector];
	return invoc;
}

/* Helper method to call the delegate on the main thread.
 */
- (void)callDelegateWithSelector:(SEL)selector andObject:(id)object {
	
	if (!delegate)
		return;
	
	NSInvocation *invoc = [self invocationForSelector:selector];
	if (object) {
		[invoc setArgument:&object atIndex:2];
		[invoc retainArguments];
	}
	[invoc performSelectorOnMainThread:@selector(invoke) 
							withObject:nil
						 waitUntilDone:NO];
}

- (void)threadMain {
	
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	
	NSRunLoop* myRunLoop = [NSRunLoop currentRunLoop];
	
	GLint swapInterval = 1;
	
	[context makeCurrentContext];
	ctx = [context CGLContextObj];
	[context setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];
	
	//setup server connection for mplayer
	NSConnection *serverConnection = [NSConnection new];
    [serverConnection setRootObject:self];
    [serverConnection registerName:connectionName];
	
	[myRunLoop run];
	
	[serverConnection release];
	[pool release];
}

/* Method called by MPlayer when playback starts.
 */
- (int) startWithWidth:(int)width withHeight:(int)height withBytes:(int)bytes withAspect:(int)aspect {
	
	CVReturn error = kCVReturnSuccess;
	
	image_width = width;
	image_height = height;
	image_bytes = bytes;
	image_aspect = aspect;
	image_aspect = image_aspect/100;
	org_image_aspect = image_aspect;
	
	shm_fd = shm_open([connectionName UTF8String], O_RDONLY, S_IRUSR);
	if (shm_fd == -1)
	{
		[Debug log:ASL_LEVEL_ERR withMessage:@"mplayergui: shm_open failed"];
		return 0;
	}
	
	image_data = mmap(NULL, image_width*image_height*image_bytes,
					  PROT_READ, MAP_SHARED, shm_fd, 0);
	
	if (image_data == MAP_FAILED)
	{
		[Debug log:ASL_LEVEL_ERR withMessage:@"mplayergui: mmap failed"];
		return 0;
	}
	
	image_buffer = malloc(image_width*image_height*image_bytes);
	
	CGLLockContext(ctx);
	
	// Setup gl
	glEnable(GL_BLEND); 
	glDisable(GL_DEPTH_TEST);
	glDepthMask(GL_FALSE);
	glDisable(GL_CULL_FACE);
	
	// Setup CoreVideo Texture
	error = CVPixelBufferCreateWithBytes( NULL, image_width, image_height, kYUVSPixelFormat, image_buffer, image_width*image_bytes, NULL, NULL, NULL, &currentFrameBuffer);
	if(error != kCVReturnSuccess)
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to create Pixel Buffer (%d)", error];
	
	error = CVOpenGLTextureCacheCreate(NULL, 0, ctx, CGLGetPixelFormat(ctx), 0, &textureCache);
	if(error != kCVReturnSuccess)
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to create OpenGL texture Cache (%d)", error];
	
	CGLUnlockContext(ctx);
	
	// Start OpenGLView in GUI
	[self callDelegateWithSelector:@selector(startRenderingWithSize:)
						 andObject:[NSValue valueWithSize:NSMakeSize(image_width, image_height)]];
						 /*andObject:[NSArray arrayWithObjects:
									[NSNumber numberWithUnsignedInt:(image_height*image_aspect)],
									[NSNumber numberWithUnsignedInt:image_height],
									nil]];*/
	
	isRendering = YES;
	
	return 1;
}

/* Method called by MPlayer when playback stops.
 */
- (void) stop {
	
	isRendering = NO;
	
	//make sure we destroy the shared buffer
	if (munmap(image_data, image_width*image_height*image_bytes) == -1)
		[Debug log:ASL_LEVEL_ERR withMessage:@"munmap failed"];
	
	close(shm_fd);
	
	CGLLockContext(ctx);
	
	CVOpenGLTextureCacheRelease(textureCache);
	CVPixelBufferRelease(currentFrameBuffer);
	
	CGLUnlockContext(ctx);
	
	free(image_buffer);
}

/* Method called by MPlayer when a frame is ready and can be copied.
 */
- (void) render {
	
	memcpy(image_buffer, image_data, image_width*image_height*image_bytes);
	[self renderOpenGL];
}

- (void)renderOpenGL {
	
	CGLLockContext(ctx);
	
	CVReturn error = kCVReturnSuccess;
	CVOpenGLTextureRef texture;
	
	glClear(GL_COLOR_BUFFER_BIT);
	
	if (isRendering)
		error = CVOpenGLTextureCacheCreateTextureFromImage (NULL, textureCache,  currentFrameBuffer,  0, &texture);
	
	if (error == kCVReturnSuccess && isRendering) {
		
		//Render Video Texture
		CVOpenGLTextureGetCleanTexCoords(texture, lowerLeft, lowerRight, upperRight, upperLeft);
		
		glEnable(CVOpenGLTextureGetTarget(texture));
		glBindTexture(CVOpenGLTextureGetTarget(texture), CVOpenGLTextureGetName(texture));
		
		glColor3f(1,1,1);
		glBegin(GL_QUADS);
		glTexCoord2f(upperLeft[0], upperLeft[1]); glVertex2i(	textureFrame.origin.x,		textureFrame.origin.y);
		glTexCoord2f(lowerLeft[0], lowerLeft[1]); glVertex2i(	textureFrame.origin.x,		NSMaxY(textureFrame));
		glTexCoord2f(lowerRight[0], lowerRight[1]); glVertex2i(	NSMaxX(textureFrame),		NSMaxY(textureFrame));
		glTexCoord2f(upperRight[0], upperRight[1]); glVertex2i(	NSMaxX(textureFrame),		textureFrame.origin.y);
		glEnd();
		glDisable(CVOpenGLTextureGetTarget(texture));
		
		glFlush();
		
		CVOpenGLTextureRelease(texture);
		
	} else {
		glClearColor(0,0,0,0);
		glFlush();
	}
	
	CGLUnlockContext(ctx);
}

- (void)adaptSize {
	
	CGLLockContext(ctx);
	
	//Setup OpenGL Viewport
	glViewport(0, 0, displayFrame.size.width, displayFrame.size.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0, displayFrame.size.width, displayFrame.size.height, 0, -1.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	CGLUnlockContext(ctx);
}

/* Handled completely by MPE: Ignored */
- (void) toggleFullscreen { }
- (void) ontop { }

@end