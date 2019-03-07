//
//  RDMPEGSubtitleASSParser.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGSubtitleASSParser.h"



NS_ASSUME_NONNULL_BEGIN

@implementation RDMPEGSubtitleASSParser

+ (nullable NSArray<NSString *> *)parseEvents:(NSString *)events {
    NSRange range = [events rangeOfString:@"[Events]"];
    if (range.location != NSNotFound) {
        NSUInteger position = range.location + range.length;
        
        range = [events rangeOfString:@"Format:"
                          options:0
                            range:NSMakeRange(position, events.length - position)];
        
        if (range.location != NSNotFound) {
            position = range.location + range.length;
            range = [events rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                        options:0
                                          range:NSMakeRange(position, events.length - position)];
            
            if (range.location != NSNotFound) {
                NSString *format = [events substringWithRange:NSMakeRange(position, range.location - position)];
                NSArray *fields = [format componentsSeparatedByString:@","];
                
                if (fields.count > 0) {
                    NSMutableArray *events = [NSMutableArray array];
                    for (NSString *field in fields) {
                        [events addObject:[field stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                    }
                    return events;
                }
            }
        }
    }
    
    return nil;
}

+ (nullable NSArray<NSString *> *)parseDialogue:(NSString *)dialogue numFields:(NSUInteger)numFields {
    if ([dialogue hasPrefix:@"Dialogue:"]) {
        NSMutableArray *fields = [NSMutableArray array];
        
        NSRange range = NSMakeRange(@"Dialogue:".length, 0);
        NSUInteger currentField = 0;
        
        while (range.location != NSNotFound && currentField < numFields) {
            const NSUInteger position = range.location + range.length;
            
            range = [dialogue rangeOfString:@","
                                    options:0
                                      range:NSMakeRange(position, dialogue.length - position)];
            
            const NSUInteger length = (range.location == NSNotFound || currentField == numFields - 1) ? (dialogue.length - position) : (range.location - position);
            
            NSString *field = [dialogue substringWithRange:NSMakeRange(position, length)];
            field = [field stringByReplacingOccurrencesOfString:@"\\N" withString:@"\n"];
            [fields addObject:field];
            
            currentField++;
        }
        
        return fields;
    }
    
    return nil;
}

+ (NSString *)removeCommandsFromEventText:(NSString *)text {
    NSMutableString *result = [NSMutableString string];
    
    NSScanner *scanner = [NSScanner scannerWithString:text];
    while (scanner.isAtEnd == NO) {
        NSString *s;
        if ([scanner scanUpToString:@"{\\" intoString:&s]) {
            [result appendString:s];
        }
        
        if (!([scanner scanString:@"{\\" intoString:nil] &&
              [scanner scanUpToString:@"}" intoString:nil] &&
              [scanner scanString:@"}" intoString:nil])) {
            break;
        }
    }
    
    return result;
}

@end

NS_ASSUME_NONNULL_END
