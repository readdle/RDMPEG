//
//  RDMPEGFrames+Decoder.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGFrames+Decoder.h"



NS_ASSUME_NONNULL_BEGIN

@implementation RDMPEGFrame (Decoder)

@dynamic position;
@dynamic duration;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration {
    self = [super init];
    if (self) {
        self.position = position;
        self.duration = duration;
    }
    return self;
}

@end



@implementation RDMPEGAudioFrame (Decoder)

@dynamic samples;

- (instancetype)initWithPosition:(NSTimeInterval)position duration:(NSTimeInterval)duration samples:(NSData *)samples {
    self = [super initWithPosition:position duration:duration];
    if (self) {
        self.samples = samples;
    }
    return self;
}

@end



@implementation RDMPEGVideoFrame (Decoder)

@dynamic width;
@dynamic height;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration
                           width:(NSUInteger)width
                          height:(NSUInteger)height {
    self = [super initWithPosition:position duration:duration];
    if (self) {
        self.width = width;
        self.height = height;
    }
    return self;
}

@end



@implementation RDMPEGVideoFrameBGRA (Decoder)

@dynamic bgra;
@dynamic linesize;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration
                           width:(NSUInteger)width
                          height:(NSUInteger)height
                            bgra:(NSData *)bgra
                        linesize:(NSUInteger)linesize {
    self = [super initWithPosition:position duration:duration width:width height:height];
    if (self) {
        self.bgra = bgra;
        self.linesize = linesize;
    }
    return self;
}

@end



@implementation RDMPEGVideoFrameYUV (Decoder)

@dynamic luma;
@dynamic chromaB;
@dynamic chromaR;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration
                           width:(NSUInteger)width
                          height:(NSUInteger)height
                            luma:(NSData *)luma
                         chromaB:(NSData *)chromaB
                         chromaR:(NSData *)chromaR {
    self = [super initWithPosition:position duration:duration width:width height:height];
    if (self) {
        self.luma = luma;
        self.chromaB = chromaB;
        self.chromaR = chromaR;
    }
    return self;
}

@end



@implementation RDMPEGArtworkFrame (Decoder)

@dynamic picture;

- (instancetype)initWithPicture:(NSData *)picture {
    self = [super init];
    if (self) {
        self.picture = picture;
    }
    return self;
}

@end



@implementation RDMPEGSubtitleFrame (Decoder)

@dynamic text;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration
                            text:(NSString *)text {
    self = [super initWithPosition:position duration:duration];
    if (self) {
        self.text = text;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
