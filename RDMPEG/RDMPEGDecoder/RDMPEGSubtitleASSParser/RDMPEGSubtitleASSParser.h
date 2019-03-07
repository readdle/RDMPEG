//
//  RDMPEGSubtitleASSParser.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGSubtitleASSParser : NSObject

+ (nullable NSArray<NSString *> *)parseEvents:(NSString *)events;
+ (nullable NSArray<NSString *> *)parseDialogue:(NSString *)dialogue numFields:(NSUInteger)numFields;
+ (NSString *)removeCommandsFromEventText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
