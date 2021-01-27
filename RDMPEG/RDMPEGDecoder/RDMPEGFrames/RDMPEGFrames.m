//
//  RDMPEGFrames.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGFrames.h"



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGFrame ()

@property (nonatomic, assign) NSTimeInterval position;
@property (nonatomic, assign) NSTimeInterval duration;
@end

@implementation RDMPEGFrame

@end



@interface RDMPEGAudioFrame ()

@property (nonatomic, strong) NSData *samples;

@end

@implementation RDMPEGAudioFrame

- (RDMPEGFrameType)type {
    return RDMPEGFrameTypeAudio;
}

@end



@interface RDMPEGVideoFrame ()

@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, assign) NSUInteger height;

@end

@implementation RDMPEGVideoFrame

- (RDMPEGFrameType)type {
    return RDMPEGFrameTypeVideo;
}

@end



@interface RDMPEGVideoFrameBGRA ()

@property (nonatomic, assign) NSUInteger linesize;
@property (nonatomic, strong) NSData *bgra;

@end

@implementation RDMPEGVideoFrameBGRA

- (nullable UIImage *)asImage {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
        return nil;
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(self.bgra));
    
    CGImageRef imageRef = CGImageCreate(self.width,
                                        self.height,
                                        8,
                                        32,
                                        self.linesize,
                                        colorSpace,
                                        kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
                                        provider,
                                        NULL,
                                        YES,
                                        kCGRenderingIntentDefault);
    
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return image;
}

@end



@interface RDMPEGVideoFrameYUV ()

@property (nonatomic, strong) NSData *luma;
@property (nonatomic, strong) NSData *chromaB;
@property (nonatomic, strong) NSData *chromaR;

@end

@implementation RDMPEGVideoFrameYUV

@end



@interface RDMPEGArtworkFrame ()

@property (nonatomic, strong) NSData *picture;

@end

@implementation RDMPEGArtworkFrame

- (RDMPEGFrameType)type {
    return RDMPEGFrameTypeArtwork;
}

- (nullable UIImage *)asImage {
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(self.picture));
    
    CGImageRef imageRef = CGImageCreateWithJPEGDataProvider(provider,
                                                            NULL,
                                                            YES,
                                                            kCGRenderingIntentDefault);
    
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    
    return image;
    
}
@end



@interface RDMPEGSubtitleFrame ()

@property (nonatomic, strong) NSString *text;

@end

@implementation RDMPEGSubtitleFrame

- (RDMPEGFrameType)type {
    return RDMPEGFrameTypeSubtitle;
}

@end

NS_ASSUME_NONNULL_END
