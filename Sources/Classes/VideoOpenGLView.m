#import <Carbon/Carbon.h>
#import <Foundation/NSByteOrder.h>
// other controllers
#import "AppController.h"
#import "PlayListController.h"

//Custom Class
#import "VideoOpenGLView.h"
#import "PlayerController.h"

@implementation VideoOpenGLView

- (void) awakeFromNib
{
	isFullscreen = NO;
	isOntop = NO;
	keepAspect = YES;
	panScan = NO;
	isPlaying = NO;
	
	zoomFactor = 1;
	
	port1 = [NSPort port];
	port2 = [NSPort port];
	
	// Choose buffer name and pass it on the way to mplayer
	buffer_name = [[NSString stringWithFormat:@"mplayerosx-%i", [[NSProcessInfo processInfo] processIdentifier]] retain];
	[Debug log:ASL_LEVEL_ERR withMessage:@"Set buffer name: %@",buffer_name];
	
	[NSThread detachNewThreadSelector:@selector(threadMain:) toTarget:self withObject:[NSArray arrayWithObjects:port1, port2, nil]];
}

/*
	Callback from render thread after server has been created
 */
- (void) connectToServer:(NSArray *)ports
{
	
	NSConnection *client = [NSConnection connectionWithReceivePort:[ports objectAtIndex:1] sendPort:[ports objectAtIndex:0]];
	threadProxy = [[client rootProxy] retain];
	[threadProxy setProtocolForProxy:@protocol(VOGLVThreadProto)];
	threadProto = (id <VOGLVThreadProto>)threadProxy;
}

/*
 
 METHODS IN SEPARATE THREAD
 
 */

- (void)threadMain:(NSArray *)ports
{
	
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	
	NSRunLoop* myRunLoop = [NSRunLoop currentRunLoop];
	
	long swapInterval = 1;
	
	[[self openGLContext] setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];
	
	//setup server connection for mplayer
	NSConnection *serverConnection=[NSConnection defaultConnection];
    [serverConnection setRootObject:self];
    [serverConnection registerName:buffer_name];
	
	// setup server connection for thread communication
	NSConnection *otherConnection = [[NSConnection alloc] initWithReceivePort:[ports objectAtIndex:0] sendPort:[ports objectAtIndex:1]];
	[otherConnection enableMultipleThreads];
	[otherConnection setRootObject:self];
	
	// let client connect
	[self performSelectorOnMainThread:@selector(connectToServer:) withObject:ports waitUntilDone:NO];
	
	[myRunLoop run];
	
	[pool release];
}

/*
	Initialize playback with size, depth and aspect
 */
- (int) startWithWidth: (int)width withHeight: (int)height withBytes: (int)bytes withAspect: (int)aspect
{
	
	CVReturn error = kCVReturnSuccess;

	image_width = width;
	image_height = height;
	image_bytes = bytes;
	image_aspect = aspect;
	image_aspect = image_aspect/100;
	org_image_aspect = image_aspect;
	
	isPlaying = YES;
	
	shm_fd = shm_open([buffer_name cString], O_RDONLY, S_IRUSR);
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
	
	//Setup CoreVideo Texture
	error = CVPixelBufferCreateWithBytes( NULL, image_width, image_height, kYUVSPixelFormat, image_buffer, image_width*image_bytes, NULL, NULL, NULL, &currentFrameBuffer);
	if(error != kCVReturnSuccess)
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to create Pixel Buffer (%d)", error];
	
	error = CVOpenGLTextureCacheCreate(NULL, 0, [[self openGLContext] CGLContextObj], [[self pixelFormat] CGLPixelFormatObj], 0, &textureCache);
	if(error != kCVReturnSuccess)
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to create OpenGL texture Cache (%d)", error];
	
	error = CVOpenGLTextureCacheCreateTextureFromImage(	NULL, textureCache, currentFrameBuffer, 0, &texture);
	if(error != kCVReturnSuccess)
		[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to create OpenGL texture (%d)", error];
	
	// Start OpenGLView in GUI
	[self performSelectorOnMainThread:@selector(startOpenGLView) withObject:nil waitUntilDone:NO];
	
	[self adaptSize];
	
	if(isFullscreen)
		[[self openGLContext] setView:[fullscreenWindow contentView]];
	
	return 1;
}

/* 
	Stop Playback
 */
- (void) stop;
{
	isPlaying = NO;
	
	//make sure we destroy the shared buffer
	if (munmap(image_data, image_width*image_height*image_bytes) == -1)
		[Debug log:ASL_LEVEL_ERR withMessage:@"munmap failed"];
	
	free(image_buffer);
}

/*
	Toggle Between Windowed & Fullscreen Mode
	1: Let the main thread switch the gui
	2: Main thread calls back to adapt opengl context
 */
- (void) toggleFullscreen
{
	
	// wait until finished before switching again
	if (switchingInProgress)
		return;
	switchingInProgress = YES;
	
	// Keep state in two variables to animate rect properly
	if(!isFullscreen)
	{
		switchingToFullscreen = YES;
	}
	else
	{
		switchingToFullscreen = NO;
		isFullscreen = NO;
		//[self clear];
	}
	
	[self performSelectorOnMainThread:@selector(toggleFullscreenWindow) withObject:nil waitUntilDone:NO];
}

- (void) finishToggleFullscreen
{
	
	if(switchingToFullscreen)
	{
		isFullscreen = YES;
	}
	else
	{
		[[self openGLContext] setView:self];
	}
	
	[self adaptSize];
	switchingInProgress = NO;
	
	// Message the main thread that switching is done
	[self performSelectorOnMainThread:@selector(toggleFullscreenEnded) withObject:nil waitUntilDone:NO];
}

/*
	Setup OpenGL
*/
- (void)prepareOpenGL
{
	//setup gl
	glEnable(GL_BLEND); 
	glDisable(GL_DEPTH_TEST);
	glDepthMask(GL_FALSE);
	glDisable(GL_CULL_FACE);

	[self adaptSize];
}

/*
	Update frame buffer and render
*/ 
- (void) render
{
	memcpy(image_buffer, image_data, image_width*image_height*image_bytes);
	[self doRender];
}

/*
	Render buffered frame
*/ 
- (void) doRender
{
	CVReturn error = kCVReturnSuccess;
	glClear(GL_COLOR_BUFFER_BIT);
	
	if(isPlaying)
	{
		error = CVOpenGLTextureCacheCreateTextureFromImage (NULL, textureCache,  currentFrameBuffer,  0, &texture);
		
		//If there is no texture, clear
		if((error != kCVReturnSuccess) || !isPlaying)
		{
			glClearColor(0,0,0,0);
			glFlush();
		}
		else
		{
			//Render Video Texture
			CVOpenGLTextureGetCleanTexCoords(texture, lowerLeft, lowerRight, upperRight, upperLeft);
			
			glEnable(CVOpenGLTextureGetTarget(texture));
			glBindTexture(CVOpenGLTextureGetTarget(texture), CVOpenGLTextureGetName(texture));
		
			glColor3f(1,1,1);
			glBegin(GL_QUADS);
			glTexCoord2f(upperLeft[0], upperLeft[1]); glVertex2i(	textureFrame.origin.x,		textureFrame.origin.y);
			glTexCoord2f(lowerLeft[0], lowerLeft[1]); glVertex2i(	textureFrame.origin.x,		textureFrame.size.height);
			glTexCoord2f(lowerRight[0], lowerRight[1]); glVertex2i(	textureFrame.size.width,	textureFrame.size.height);
			glTexCoord2f(upperRight[0], upperRight[1]); glVertex2i(	textureFrame.size.width,	textureFrame.origin.y);
			glEnd();
			glDisable(CVOpenGLTextureGetTarget(texture));
		
			glFlush();
		}
	}
	else
	{
		glClearColor(0,0,0,0);
		glFlush();
	}
}

/*
	clear background
*/
- (void) clear
{
	glClear(GL_COLOR_BUFFER_BIT);
	glClearColor(0,0,0,0);
	glFlush();
	[[self openGLContext] flushBuffer];
}

/*
	reshape OpenGL viewport
*/ 
- (void)adaptSize
{
	
	//asl_log(NULL, NULL, ASL_LEVEL_ERR, "adaptSizeT");
	NSRect frame;
	uint32_t d_width;
	uint32_t d_height;
	float aspectX;
	float aspectY;
	int padding = 0;
	
	if(isFullscreen)
		//frame = screen_frame;
		frame = [[fullscreenWindow contentView] bounds];
	else
		frame = [self bounds];
	
	if(panScan)
	{
		d_width = frame.size.height*image_aspect;
		d_height = frame.size.height;
	}
	else
	{
		d_width = image_height*image_aspect;
		d_height = image_height;
	}
	
	//Setup OpenGL Viewport
	glViewport(0, 0, frame.size.width, frame.size.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0, frame.size.width, frame.size.height, 0, -1.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	if(keepAspect)
	{
		//set video frame coordinate
		aspectX = (float)((float)frame.size.width/(float)d_width);
		aspectY = (float)((float)(frame.size.height)/(float)d_height);
		
		if( ((d_height*aspectX)>(frame.size.height)) || panScan)
		{
			padding = (frame.size.width - d_width*aspectY)/2;
			textureFrame = NSMakeRect(padding, 0, d_width*aspectY+padding, d_height*aspectY);
		}
		else
		{
			padding = ((frame.size.height) - d_height*aspectX)/2;
			textureFrame = NSMakeRect(0, padding, d_width*aspectX, d_height*aspectX+padding);
		}
	}
	else
	{
		textureFrame =  frame;
	}
}

/*
	Update method, called in main thread and forwareded to render thread
 */
- (void) updateInThread
{
	[[self openGLContext] update];
}

/*
	DrawRect method, called in main thread and forwareded to render thread
 */
- (void) drawRectInThread
{
	[self doRender];
}

/*
 
 METHODS IN MAIN THREAD
 
 */

- (NSString *)bufferName
{
	return [[buffer_name retain] autorelease];
}

/*
	Start OpenGL view
*/
- (void) startOpenGLView
{
	//Bring window to front
	//[[self window] makeKeyAndOrderFront:nil];
	
    if(isFullscreen)
	{
		[fullscreenWindow makeKeyAndOrderFront:nil];
		//[[self window] orderOut:nil];
		
		isFullscreen = YES;
	} else {
		
		[self resizeToMovie];
	}
    
	//Play in fullscreen
	if ([playerController startInFullscreen])
		[threadProto toggleFullscreen];
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
- (void) toggleFullscreenWindow
{
	
	static NSRect old_win_frame;
	static NSRect old_view_frame;
	NSWindow *window = [playerController playerWindow];
    NSRect fsRect;
    
	int fullscreenId = [playerController fullscreenDeviceId];
	screen_frame = [[[NSScreen screens] objectAtIndex:fullscreenId] frame];
	
    fsRect = screen_frame;
    fsRect.origin.x = 0;
	fsRect.origin.y = 0;
	
	if(switchingToFullscreen)
	{
		//enter kiosk mode
		SetSystemUIMode( kUIModeAllHidden, kUIOptionAutoShowMenuBar);
		[(PlayerFullscreenWindow*)fullscreenWindow setFullscreen:YES];
		
		// place fswin above video
		NSRect rect = [self frame];
		rect.origin = [window convertBaseToScreen:rect.origin];
		[fullscreenWindow setFrame:rect display:NO animate:NO];
		
		// save positions for back transition
		old_win_frame = rect;
		old_view_frame = [self frame];
		
		// move to ontop level if needed
		if ([playerController isOntop])
			[fullscreenWindow setLevel:NSScreenSaverWindowLevel];
		else
			[fullscreenWindow setLevel:NSNormalWindowLevel];
		
		[fullscreenWindow makeKeyAndOrderFront:nil];
		
		// move view to fswin and redraw to avoid flicker
		[fullscreenWindow setContentView:self];
		[self drawRect:rect];
		
		//resize window	
		[fullscreenWindow setFrame:screen_frame display:YES animate:YES];
		
		[window orderOut:nil];
		
		[threadProto finishToggleFullscreen];
		
	}
	else
	{
		[window orderWindow:NSWindowBelow relativeTo:[fullscreenWindow windowNumber]];
		[window makeKeyWindow];
		
		[(PlayerFullscreenWindow*)fullscreenWindow setFullscreen:NO];
		
		[fullscreenWindow setFrame:old_win_frame display:YES animate:YES];
		
		[fullscreenWindow orderOut:nil];
		
		// move view back, place and redraw
		[[window contentView] addSubview:self];
		[self setFrame:old_view_frame];
		[self drawRect:old_view_frame];
		
		//exit kiosk mode
		SetSystemUIMode( kUIModeNormal, 0);
		
		[threadProto finishToggleFullscreen];
		
	}
	
	
}

/*
 Switching Fullscreen has ended
 */
- (void) toggleFullscreenEnded
{
	
	[[NSNotificationCenter defaultCenter]
		postNotificationName:@"MIFullscreenSwitchDone"
		object:self
		userInfo:nil];
}

/*
 Resize OpenGL view to fit movie
 */
- (void) resizeToMovie
{
	NSRect win_frame = [[self window] frame];
	NSRect mov_frame = [self bounds];
	NSSize minSize = [[self window]contentMinSize];
	
	//if movie is smaller then the UI use min size
	if( (image_height*image_aspect) < minSize.width)
		win_frame.size.width = minSize.width;
	else
		win_frame.size.width += (image_height*image_aspect - mov_frame.size.width);
	
	win_frame.size.height += (image_height - mov_frame.size.height);
	[[self window] setFrame:win_frame display:YES animate:YES];
}

/*
	Close OpenGL view
*/
- (void) close
{
	// exit fullscreen and close with callback
	if(isFullscreen) {
		
		[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(finishClosing) 
			name: @"MIFullscreenSwitchDone"
			object: self];
		
		[threadProto toggleFullscreen];
		
		return;
	}
	
	// not fullscreen: close immediately
	[self finishClosing];
}

- (void) finishClosing
{
	image_width = 0;
	image_height = 0;
	image_bytes = 0;
	image_aspect = 0;
	
	//resize window
	NSRect frame = [[self window] frame];
	NSSize minSize = [[self window]contentMinSize];
	frame.size.width = minSize.width;
	frame.size.height = minSize.height+20; //+title bar height
	[[self window] setFrame:frame display:YES animate:YES];
	
	// remove fullscreen callback
	[[NSNotificationCenter defaultCenter] removeObserver:self
		name: @"MIFullscreenSwitchDone"
		object: self];
}

/*
	Resize Window with given zoom factor
*/
- (void) setWindowSizeMult: (float)zoom
{
	zoomFactor = zoom;
	
	// exit fullscreen first and finish with callback
	if(isFullscreen) {
		
		[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(finishWindowSizeMult) 
			name: @"MIFullscreenSwitchDone"
			object: self];
		
		[threadProto toggleFullscreen];
		
		return;
	}
	
	// not fullscreen: resize now
	[self finishWindowSizeMult];
}

- (void) finishWindowSizeMult
{
	//resize window
	NSRect win_frame = [[self window] frame];
	NSRect mov_frame = [self bounds];
	NSSize minSize = [[self window]contentMinSize];
	
	win_frame.size.height += ((image_height*zoomFactor) - mov_frame.size.height);
	
	if( ((image_height*image_aspect)*zoomFactor) < minSize.width)
		win_frame.size.width = minSize.width;
	else
		win_frame.size.width += (((image_height*image_aspect)*zoomFactor) - mov_frame.size.width);
	
	[[self window] setFrame:win_frame display:YES animate:YES];
	
	// remove fullscreen callback
	[[NSNotificationCenter defaultCenter] removeObserver:self
		name: @"MIFullscreenSwitchDone"
		object: self];
}

/*
	Toggle ontop
*/
- (void) ontop
{
	isOntop = !isOntop;
	if(isOntop) {
		[[self window] setLevel:NSScreenSaverWindowLevel];
		[fullscreenWindow setLevel:NSScreenSaverWindowLevel];
	}
	else {
		[[self window] setLevel:NSNormalWindowLevel];
		[fullscreenWindow setLevel:NSNormalWindowLevel];
	}
}

/*
	View changed: synchronized call to the render thread
 */
- (void) reshape
{
	[threadProto adaptSize];
}

- (void) update
{
	[threadProto updateInThread];
}

- (void) drawRect: (NSRect *) bounds
{
	[threadProto drawRectInThread];
}

/*
	Menu Actions
*/
- (IBAction)MovieMenuAction:(id)sender
{
	if(isPlaying) 
	{
		//Zoom
		if(sender == HalfSizeMenuItem)
			[self setWindowSizeMult: 0.5];
		if(sender == NormalSizeMenuItem)
			[self setWindowSizeMult: 1];
		if(sender == DoubleSizeMenuItem)
			[self setWindowSizeMult: 2];
			
		//Aspect
		if(sender == KeepAspectMenuItem)
		{
			keepAspect = !keepAspect;
			
			if(keepAspect)
				[KeepAspectMenuItem setState:NSOnState];
			else
				[KeepAspectMenuItem setState:NSOffState];
				
			[self reshape];
		}
			
		if(sender == PanScanMenuItem)
		{
			panScan = !panScan;
			
			if(panScan)
				[PanScanMenuItem setState:NSOnState];
			else
				[PanScanMenuItem setState:NSOffState];
				
			[self reshape];
		}
			
		if(sender == OriginalAspectMenuItem)
		{
			image_aspect = org_image_aspect;
			[self reshape];
		}	
		
		if(sender == Aspect4to3MenuItem)
		{
			image_aspect = 4.0f/3.0f;
			[self reshape];
		}
		
		if(sender == Aspect3to2MenuItem)
		{
			image_aspect = 3.0f/2.0f;
			[self reshape];
		}
		
		if(sender == Aspect5to3MenuItem)
		{
			image_aspect = 5.0f/3.0f;
			[self reshape];
		}
		
		if(sender == Aspect16to9MenuItem)
		{
			image_aspect = 16.0f/9.0f;
			[self reshape];
		}
		
		if(sender == Aspect185to1MenuItem)
		{
			image_aspect = 1.85f/1.0f;
			[self reshape];
		}
		
		if(sender == Aspect239to1MenuItem)
		{
			image_aspect = 2.39f/1.0f;
			[self reshape];
		}
	}
}

- (void) mouseDown: (NSEvent *) theEvent
{
	if ([theEvent clickCount] == 2)
		[playerController switchFullscreen: self];
}

@end
