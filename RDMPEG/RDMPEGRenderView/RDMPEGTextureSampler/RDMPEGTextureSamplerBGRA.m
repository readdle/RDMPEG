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



NS_ASSUME_NONNULL_BEGIN

@implementation RDMPEGTextureSamplerBGRA

#pragma mark - RDMPEGTextureSampler

- (id<MTLFunction>)newSamplingFunctionFromLibrary:(id<MTLLibrary>)library {
    return [library newFunctionWithName:@"samplingShaderBGRA"];
}

- (void)updateTexturesWithFrame:(RDMPEGVideoFrame *)videoFrame
                         device:(id<MTLDevice>)device
                  renderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder
{
    if (nil == videoFrame) {
        NSParameterAssert(NO);
        return;
    }
    
    if (NO == [videoFrame isKindOfClass:[RDMPEGVideoFrameBGRA class]]) {
        NSParameterAssert(NO);
        return;
    }
    
    RDMPEGVideoFrameBGRA * const bgraFrame = (RDMPEGVideoFrameBGRA *)videoFrame;
    
    id<MTLTexture> texture = [self textureFromFrame:bgraFrame device:device];
    
    [renderEncoder setFragmentTexture:texture
                              atIndex:RDMPEGTextureIndexBGRABaseColor];
}

#pragma mark - Private Methods

- (id<MTLTexture>)textureFromFrame:(RDMPEGVideoFrameBGRA *)videoFrame
                            device:(id<MTLDevice>)device
{
    NSParameterAssert(videoFrame);
    
    MTLTextureDescriptor * const textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    textureDescriptor.width = videoFrame.width;
    textureDescriptor.height = videoFrame.height;
    
    id<MTLTexture> const texture = [device newTextureWithDescriptor:textureDescriptor];
    
    MTLRegion region;
    region.origin = MTLOriginMake(0, 0, 0);
    region.size = MTLSizeMake(width, height, 1);
    
    [texture
     replaceRegion:region
     mipmapLevel:0
     withBytes:videoFrame.bgra.bytes
     bytesPerRow:(4 * videoFrame.width)];
    
    return texture;
}

@end

NS_ASSUME_NONNULL_END
