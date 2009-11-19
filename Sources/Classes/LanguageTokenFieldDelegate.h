//
//  LanguageTokenFieldDelegate.h
//  MPlayer OSX Extended
//
//  Created by Adrian on 17.11.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LanguageTokenFieldDelegate : NSObject {
	
	IBOutlet NSTokenField *audioLanguageField;
	IBOutlet NSTokenField *subtitleLanguageField;
}

@end
