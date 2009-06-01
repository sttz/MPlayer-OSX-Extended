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

static aslclient asc;

@implementation Debug

/** Initialize Debug class.
 *  Create ASL connection and apply message filter.
 */
+ (void) init {
	
	// Create ASL connection
	aslclient asc = asl_open(dSender, dFacility, 0U);
	
	asl_set_filter(asc, ASL_FILTER_MASK_UPTO(dFilterUpto));
}

/** Uninitialize Debug class.
 */
+ (void) uninit {
	
	asl_close(asc);
}

/** Add a file to log to.
 *  Add a new file to log all Debug messages to.
 *  \param path Path to the log file (will be created or appended to)
 */
+ (void) logToFile:(NSString *)path {
	
	int fd = open([path cString], O_WRONLY | O_CREAT | O_APPEND, 0644);
	asl_add_log_file(asc, fd);
	// leak file descriptor. It is open until the program exits and will be closed then anyway.
}

/** Log a new debug message.
 *  \param level ASL log message level (ASL_LEVEL_* as defined in asl.h)
 *  \param message Log message (as format template, see [NSString initWithFormat:])
 */
+ (void) log:(int)level withMessage:(NSString *)message, ... {
	
	va_list ap;
	NSString *pMessage;
	va_start(ap, message);
	
	pMessage = [[NSString alloc] initWithFormat:message arguments:ap];
	
	asl_log(asc, NULL, level, [pMessage UTF8String]);
	
	[pMessage release];
	va_end(ap);
}

@end
