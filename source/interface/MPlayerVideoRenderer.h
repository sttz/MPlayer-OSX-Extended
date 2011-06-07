/*  
 *  MPlayerVideoRenderer.h
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

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@protocol MPlayerVideoRenderereDelegateProtocol <NSObject>
- (void)startRenderingWithSize:(NSValue *)size;
@end


@interface MPlayerVideoRenderer : NSObject
{
	
@private
	NSThread *renderThread;
	NSOpenGLContext *context;
	CGLContextObj ctx;
	NSString *connectionName;
	
	id<MPlayerVideoRenderereDelegateProtocol> delegate;
	
	BOOL isRendering;
	
	//shared memory
	int shm_fd;
	
	//CoreVideo
	CVPixelBufferRef currentFrameBuffer;
	CVOpenGLTextureCacheRef textureCache;
	NSRect textureFrame;
	NSRect displayFrame;
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
}

@property (retain) id<MPlayerVideoRenderereDelegateProtocol> delegate;

- (id)initWithContext:(NSOpenGLContext *)ctx andConnectionName:(NSString *)name;

- (void)boundsDidChangeTo:(NSRect)bounds withVideoFrame:(NSRect)frame;
- (void)redraw;

@end
