//
//  RDMPEGStream.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/23/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGStream.h"
#import <libavformat/avformat.h>
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGStream ()

@property (nonatomic, assign) AVStream *stream;
@property (nonatomic, assign) NSUInteger streamIndex;
@property (nonatomic, assign, nullable) AVCodec *codec;
@property (nonatomic, assign, nullable) AVCodecContext *codecContext;
@property (nonatomic, strong, nullable) NSString *subtitleEncoding;

@end



@implementation RDMPEGStream

@synthesize languageCode = _languageCode;
@synthesize info = _info;

#pragma mark - Overridden Class Methods

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGStream"];
}

#pragma mark - Lifecycle

- (void)dealloc {
    if (_codecContext) {
        avcodec_free_context(&_codecContext);
    }
}

#pragma mark - Public Accessors

- (nullable NSString *)languageCode {
    if (_languageCode) {
        return _languageCode;
    }
    
    AVDictionaryEntry *language = av_dict_get(self.stream->metadata, "language", NULL, 0);
    if (language && language->value) {
        _languageCode = [NSString stringWithCString:language->value encoding:NSUTF8StringEncoding];
    }
    
    return _languageCode;
}

- (nullable NSString *)info {
    if (_info) {
        return _info;
    }
    
    if (self.codecContext == nil) {
        return nil;
    }
    
    char buffer[256];
    avcodec_string(buffer, sizeof(buffer), self.codecContext, 1);
    
    NSString *streamInfo = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    
    NSArray<NSString *> *prefixesToRemove = @[@"Video: ", @"Audio: ", @"Subtitle: "];
    for (NSString *prefixToRemove in prefixesToRemove) {
        if ([streamInfo hasPrefix:prefixToRemove]) {
            streamInfo = [streamInfo stringByReplacingOccurrencesOfString:prefixToRemove withString:@""];
            break;
        }
    }
    
    _info = streamInfo;
    return _info;
}

- (BOOL)isCanBeDecoded {
    return (self.codec != nil);
}

@end

NS_ASSUME_NONNULL_END
