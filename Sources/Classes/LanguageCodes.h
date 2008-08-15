//
//  LanguageCodes.h
//  MPlayer OSX
//
//  Created by Adrian on 02.08.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Debug.h"

@interface LanguageCodes : NSObject {
	
}

+ (BOOL)loadCodes;

+ (NSString *)resolveCode:(NSString *)code;

@end
