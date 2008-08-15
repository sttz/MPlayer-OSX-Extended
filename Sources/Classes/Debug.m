//
//  Debug.m
//  MPlayer OSX
//
//  Created by Adrian on 11.08.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "Debug.h"

static aslclient asc;
static aslmsg msg;

@implementation Debug

+ (void) init {
	
	// Create ASL connection
	aslclient asc = asl_open(dSender, dFacility, 0U);
	
	asl_set_filter(asc, ASL_FILTER_MASK_UPTO(dFilterUpto));
}

+ (void) logToFile:(NSString *)path {
	
	int fd = open([path cString], O_WRONLY | O_CREAT | O_APPEND, 0644);
	asl_add_log_file(asc, fd);
}

+ (void) log:(int)level withMessage:(NSString *)message, ... {
	
	va_list ap;
	NSString *pMessage;
	va_start(ap, message);
	
	pMessage = [[NSString alloc] initWithFormat:message arguments:ap];
	
	asl_log(asc, msg, level, [pMessage UTF8String]);
	
	[pMessage release];
	va_end(ap);
}

@end
