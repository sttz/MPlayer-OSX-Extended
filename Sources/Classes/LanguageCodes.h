/*  
 *  LanguageCodes.h
 *  MPlayerOSX Extended
 *  
 *  Created on 02.08.2008
 *  
 *  Description:
 *	Class used to read iso-639-3 language codes from a tab file and to provide 
 *  a mean to resolve those codes to languages names.
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
#import "Debug.h"

@interface LanguageCodes : NSObject {
	
	NSDictionary *codes_2;
	NSDictionary *codes_3;
	NSDictionary *codes_2_to_3;
}

+ (LanguageCodes *)sharedInstance;

- (NSString *)resolveCode:(NSString *)code;
- (NSString *)threeLetterCodeForToken:(NSString *)token;
- (NSString *)mplayerArgumentFromArray:(NSArray *)codes;
- (NSString *)nameForCode:(NSString *)code;

@end
