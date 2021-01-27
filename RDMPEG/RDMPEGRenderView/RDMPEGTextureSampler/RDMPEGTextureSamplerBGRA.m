//
//  RDMPEGTextureSamplerBGRA.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 06.01.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "RDMPEGTextureSamplerBGRA.h"
#import "RDMPEGFrames.h"
#import "RDMPEGShaderTypes.h"
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGTextureSamplerBGRA ()

@property (nonatomic, strong, nullable) id<MTLTexture> bgraTexture;

@end



@implementation RDMPEGTextureSamplerBGRA

#pragma mark - RDMPEGTextureSampler

- (id<MTLFunction>)newSamplingFunctionFromLibrary:(id<MTLLibrary>)library {
    return [library newFunctionWithName:@"samplingShaderBGRA"];
}

- (void)setupTexturesWithDevice:(id<MTLDevice>)device
                     frameWidth:(NSUInteger)frameWidth
                    frameHeight:(NSUInteger)frameHeight
{
    if (self.bgraTexture) {
        NSAssert(NO, @"Texture is already created");
        return;
    }
    
    MTLTextureDescriptor * const textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    textureDescriptor.width = frameWidth;
    textureDescriptor.height = frameHeight;
    
    self.bgraTexture = [device newTextureWithDescriptor:textureDescriptor];
}

- (void)updateTexturesWithFrame:(RDMPEGVideoFrame *)videoFrame
                  renderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder
{
    if (nil == self.bgraTexture) {
        NSAssert(NO, @"'%@' must be called before updating textures",
                 NSStringFromSelector(@selector(setupTexturesWithDevice:frameWidth:frameHeight:)));
        return;
    }
    
    if (nil == videoFrame) {
        NSParameterAssert(NO);
        return;
    }
    
    if (NO == [videoFrame isKindOfClass:[RDMPEGVideoFrameBGRA class]]) {
        NSParameterAssert(NO);
        return;
    }
    
    if (self.bgraTexture.width != videoFrame.width ||
        self.bgraTexture.height != videoFrame.height)
    {
        log4Assert(NO, @"Video frame size (%ld %ld) does not equal to texture size (%ld %ld)",
                   videoFrame.width,
                   videoFrame.height,
                   self.bgraTexture.width,
                   self.bgraTexture.height);
        return;
    }
    
    RDMPEGVideoFrameBGRA * const bgraFrame = (RDMPEGVideoFrameBGRA *)videoFrame;
    
    MTLRegion region;
    region.origin = MTLOriginMake(0, 0, 0);
    region.size = MTLSizeMake(videoFrame.width, videoFrame.height, 1);
    
    [self.bgraTexture
     replaceRegion:region
     mipmapLevel:0
     withBytes:bgraFrame.bgra.bytes
     bytesPerRow:(4 * videoFrame.width)];
    
    [renderEncoder setFragmentTexture:self.bgraTexture atIndex:RDMPEGTextureIndexBGRABaseColor];
}

@end

NS_ASSUME_NONNULL_END
