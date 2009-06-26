/*  
 *  Debug.m
 *  MPlayerOSX Extended
 *  
 *  Created on 11.08.2008
 *  
 *  Description:
 *	Wrapper class around ASL
 *  
 *  This program is free software; you can redistribute it and/or 
 *  modify it under the terms of the GNU General Public License 
 *  as published by the Free Software Foundation; either version 3 
 *  of the License, or (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful, 
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of 
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License 
 *  along with this program; if not, see <http://www.gnu.org/licenses/>. 
 */

#import "Debug.h"

/// Shared debugger singleton instance
static Debug *sharedInstance;
/// Switch if the shared instance is initialized with stderr as output
static BOOL sharedInstanceConnectsStderr = NO;

/// Internal methods
@interface Debug ()
- (void) createConnectionWithOptions:(uint32_t)options;
- (void) turnLogIfNecessary;
- (void) log:(int)level withMessage:(NSString *)message andParams:(va_list)ap;
@end

@implementation Debug

/** Sets if the shared instance connects stderr as an output
 *  Sets if the shared instance adds stderr as an output for the log messages.
 *  This message needs to be sent before the shared instance in initialized.
 *  \param connect Connect stderr for the shared Debug instance
 */
+ (void) setSharedDebuggerConnectsStderr:(BOOL)connect {
	
	if (!sharedInstance)
		sharedInstanceConnectsStderr = connect;
	else
		[Debug log:ASL_LEVEL_ERR withMessage:@"Cannot set sharedInstanceConnectsStderr: Shared instance already initialized."];
}

/** Return the shared singleton Debug instance.
 *  Returns the singleton instance and creates one if none exists.
 */
+ (Debug *) sharedDebugger {
	
	if (!sharedInstance) {
		if (sharedInstanceConnectsStderr)
			sharedInstance = [[Debug alloc] initWithStderr];
		else
			sharedInstance = [[Debug alloc] init];
	}
	return sharedInstance;
}

/** Convenience method to log a new message.
 *  Logs a new message through the sharedDebugger instance.
 *  \param level ASL log message level (ASL_LEVEL_* as defined in asl.h)
 *  \param message Log message (as format template, see [NSString initWithFormat:])
 *  \param comma separated list of format arguments substitute into message
 */
+ (void) log:(int)level withMessage:(NSString *)message, ... {
	
	va_list ap;
	va_start(ap, message);
	
	[sharedInstance log:level withMessage:message andParams:ap];
	
	va_end(ap);
}

/** Initialize Debug class.
 *  Create ASL connection and apply message filter.
 */
- (Debug *) init {
	
	self = [super init];
	
	if (self)
		[self createConnectionWithOptions:0U];
	
	return self;
}

/** Initialize Debug class with stderr as output.
 *  Create ASL connection, apply message filter and add stderr as output.
 */
- (Debug *) initWithStderr {
	
	self = [super init];
	
	if (self)
		[self createConnectionWithOptions:ASL_OPT_STDERR];
	
	return self; 
}

/** Initialize Debug class with specific sdl_open options.
 */
- (void) createConnectionWithOptions:(uint32_t)options {
	
	// Create ASL connection
	asc = asl_open(dSender, dFacility, options);
	// Only show message above level set in dFilterUpto
	asl_set_filter(asc, ASL_FILTER_MASK_UPTO(dFilterUpto));
}

/** Uninitialize Debug class.
 */
- (void) uninit {
	
	asl_close(asc);
	[logFiles release];
}

/** Add a file to log to.
 *  Add a new file to log all Debug messages to.
 *  \param path Path to the log file (will be created or appended to)
 */
- (void) logToFile:(NSString *)path {
	
	if (!logFiles)
		logFiles = [[NSMutableDictionary alloc] init];
	
	int fd = open([path cString], O_WRONLY | O_CREAT | O_APPEND, 0644);
	
	if (fd == -1)
		return [self log:ASL_LEVEL_ERR withMessage:@"Failed to open file for logging: %@", path];
		
	asl_add_log_file(asc, fd);
	
	NSFileHandle *fh = [[[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES] autorelease];
	[logFiles setObject:fh forKey:path];
}

/** Log a new debug message.
 *  \param level ASL log message level (ASL_LEVEL_* as defined in asl.h)
 *  \param message Log message (as format template, see [NSString initWithFormat:])
 *  \param comma separated list of format arguments to substitute into message
 */
- (void) log:(int)level withMessage:(NSString *)message, ... {
	
	va_list ap;
	va_start(ap, message);
	
	[self log:level withMessage:message andParams:ap];
	
	va_end(ap);
}

/** Check log file length and turn them over if necessary.
 */
- (void) turnLogIfNecessary {
	
	// check if it's time to check sizes
	if (lastSizeCheck != 0 
			&& [NSDate timeIntervalSinceReferenceDate] + dSizeCheckInterval < lastSizeCheck)
		return;
	else
		lastSizeCheck = [NSDate timeIntervalSinceReferenceDate];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSEnumerator *files = [logFiles keyEnumerator];
	NSString *file;
	
	while (file = [files nextObject]) {
		unsigned long long size = [[fm fileAttributesAtPath:file traverseLink:YES] fileSize];
		if (size > dLogMaxSize) {
			
			// remove old log file and remove FileHanlde to close fd
			asl_remove_log_file(asc, [[logFiles objectForKey:file] fileDescriptor]);
			[logFiles removeObjectForKey:file];
			
			NSString *oldLog = [[file stringByDeletingPathExtension] stringByAppendingFormat:@"-old.%@",[file pathExtension]];
			BOOL isDirectory;
			BOOL continueMove = YES;
			
			// Check if file exists at old log path and try to remove it
			if ([fm fileExistsAtPath:oldLog isDirectory:&isDirectory]) {
				if (isDirectory) {
					continueMove = NO;
					[Debug log:ASL_LEVEL_ERR withMessage:@"Cannot move old log: '%@' is a directory.", oldLog];
				} else if (![fm removeFileAtPath:file handler:nil]) {
					continueMove = NO;
					[Debug log:ASL_LEVEL_ERR withMessage:@"Cannot remove old log at '%@'.", oldLog];
				}
			}
			// Move file only if there's no file or directory in the way
			if (!continueMove || ![fm movePath:file toPath:oldLog handler:nil])
				[Debug log:ASL_LEVEL_ERR withMessage:@"Failed to move old olg to '%@'.", oldLog];
			
			// Re-open existing log and truncate if move failed
			int fd = open([file cString], O_WRONLY | O_CREAT | O_TRUNC, 0644);
			
			if (fd == -1)
				[self log:ASL_LEVEL_ERR withMessage:@"Failed turn over log file: %@", file];
			else {
				asl_add_log_file(asc, fd);
				
				NSFileHandle *fh = [[[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES] autorelease];
				[logFiles setObject:fh forKey:file];
			}
		}
	}
	
}

/** Log a new debug message (internal).
 */
- (void) log:(int)level withMessage:(NSString *)message andParams:(va_list)ap {
	
	@synchronized (self) {
		
		[self turnLogIfNecessary];
		
		NSString *pMessage;
		pMessage = [[NSString alloc] initWithFormat:message arguments:ap];
		
		asl_log(asc, NULL, level, [pMessage UTF8String]);
		
		[pMessage release];
		
	}
}

@end

