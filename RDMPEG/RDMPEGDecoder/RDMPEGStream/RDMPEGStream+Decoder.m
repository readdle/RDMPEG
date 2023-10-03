//
//  RDMPEGStream+Decoder.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/23/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGStream+Decoder.h"
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@implementation RDMPEGStream (Decoder)

@dynamic stream;
@dynamic streamIndex;
@dynamic codec;
@dynamic codecContext;
@dynamic subtitleEncoding;

#pragma mark - Lifecycle

- (instancetype)initWithStream:(AVStream *)stream atIndex:(NSUInteger)streamIndex {
    self = [super init];
    if (self) {
        self.stream = stream;
        self.streamIndex = streamIndex;
        
        const AVCodec *codec = avcodec_find_decoder(self.stream->codecpar->codec_id);
        if (codec) {
            AVCodecContext *codecContext = avcodec_alloc_context3(self.codec);
            if (codecContext) {
                int parametersToContextStatus = avcodec_parameters_to_context(codecContext, self.stream->codecpar);
                if (parametersToContextStatus >= 0) {
                    codecContext->pkt_timebase = self.stream->time_base;
                    self.codec = codec;
                    self.codecContext = codecContext;
                }
                else {
                    log4Error(@"Parameters to context error: %s", av_err2str(parametersToContextStatus));
                    avcodec_free_context(&codecContext);
                }
            }
            else {
                log4Error(@"Unable to allocate codec context");
            }
        }
    }
    return self;
}

#pragma mark - Public Methods

- (BOOL)openCodec {
    if (self.codec == nil || self.codecContext == nil) {
        return NO;
    }
    
    if (self.subtitleEncoding.length > 0) {
        if (self.codecContext->sub_charenc) {
            free(self.codecContext->sub_charenc);
        }
        
        char *encoding = malloc(self.subtitleEncoding.length + 1);
        strcpy(encoding, [self.subtitleEncoding cStringUsingEncoding:NSUTF8StringEncoding]);
        self.codecContext->sub_charenc = encoding;
    }
    
    int codecOpenStatus = avcodec_open2(self.codecContext, self.codec, NULL);
    if (codecOpenStatus < 0) {
        log4Error(@"Codec open error: %s", av_err2str(codecOpenStatus));
        return NO;
    }
    
    return YES;
}

- (void)closeCodec {
    if (self.codecContext) {
        if (self.codecContext->sub_charenc) {
            free(self.codecContext->sub_charenc);
            self.codecContext->sub_charenc = NULL;
        }
        
        avcodec_close(self.codecContext);
    }
}

@end

NS_ASSUME_NONNULL_END
