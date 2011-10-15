/*  
 *  MovieMethods.h
 *  MPlayerOSX Extended
 *  
 *  Created by Bilal Syed Hussain on  2011-10-15
 *  
 */

#import <Foundation/Foundation.h>


@interface MovieMethods : NSObject {
@private
    
}

// Return the filepath of the next episode based on filepath
// returns nil if not found.
+(NSString*) findNextEpisodePathFrom:(NSString*)filepath inFormats:(NSSet*)exts;

@end
