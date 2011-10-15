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

+(NSString*) findNextEpisodePathFrom:(NSString*)filepath inFormats:(NSSet*)exts;

@end
