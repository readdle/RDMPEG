//
//  RDMPEGTextureSamplerYUV.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 06.01.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "RDMPEGTextureSamplerYUV.h"
#import "RDMPEGFrames.h"
#import "RDMPEGShaderTypes.h"



NS_ASSUME_NONNULL_BEGIN

@implementation RDMPEGTextureSamplerYUV

#pragma mark - RDMPEGTextureSampler

- (id<MTLFunction>)newSamplingFunctionFromLibrary:(id<MTLLibrary>)library {
    return [library newFunctionWithName:@"samplingShaderYUV"];
}

- (void)updateTexturesWithFrame:(RDMPEGVideoFrame *)videoFrame
                         device:(id<MTLDevice>)device
                  renderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder
{
    if (nil == videoFrame) {
        NSParameterAssert(NO);
        return;
    }
    
    if (NO == [videoFrame isKindOfClass:[RDMPEGVideoFrameYUV class]]) {
        NSParameterAssert(NO);
        return;
    }
    
    RDMPEGVideoFrameYUV * const yuvFrame = (RDMPEGVideoFrameYUV *)videoFrame;
    
    id<MTLTexture> yTexture = [self yTextureFromFrame:yuvFrame device:device];
    id<MTLTexture> uTexture = [self uTextureFromFrame:yuvFrame device:device];
    id<MTLTexture> vTexture = [self vTextureFromFrame:yuvFrame device:device];
    
    [renderEncoder setFragmentTexture:yTexture atIndex:RDMPEGTextureIndexY];
    [renderEncoder setFragmentTexture:uTexture atIndex:RDMPEGTextureIndexU];
    [renderEncoder setFragmentTexture:vTexture atIndex:RDMPEGTextureIndexV];
}

#pragma mark - Private Methods

- (id<MTLTexture>)yTextureFromFrame:(RDMPEGVideoFrameYUV *)videoFrame
                             device:(id<MTLDevice>)device
{
    return
    [self
     textureFromData:videoFrame.luma
     device:device
     width:videoFrame.width
     height:videoFrame.height
     bytesPerRow:videoFrame.width];
}

- (id<MTLTexture>)uTextureFromFrame:(RDMPEGVideoFrameYUV *)videoFrame
                             device:(id<MTLDevice>)device
{
    return
    [self
     textureFromData:videoFrame.chromaB
     device:device
     width:(videoFrame.width / 2)
     height:(videoFrame.height / 2)
     bytesPerRow:(videoFrame.width / 2)];
}

- (id<MTLTexture>)vTextureFromFrame:(RDMPEGVideoFrameYUV *)videoFrame
                             device:(id<MTLDevice>)device
{
    return
    [self
     textureFromData:videoFrame.chromaR
     device:device
     width:(videoFrame.width / 2)
     height:(videoFrame.height / 2)
     bytesPerRow:(videoFrame.width / 2)];
}

#pragma mark - Private Methods

- (id<MTLTexture>)textureFromData:(NSData *)textureData
                           device:(id<MTLDevice>)device
                            width:(NSUInteger)width
                           height:(NSUInteger)height
                      bytesPerRow:(NSUInteger)bytesPerRow
{
    MTLTextureDescriptor * const textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatR8Unorm;
    textureDescriptor.width = width;
    textureDescriptor.height = height;
    
    id<MTLTexture> const texture = [device newTextureWithDescriptor:textureDescriptor];
    
    MTLRegion region;
    region.origin = MTLOriginMake(0, 0, 0);
    region.size = MTLSizeMake(width, height, 1);
    
    [texture
     replaceRegion:region
     mipmapLevel:0
     withBytes:textureData.bytes
     bytesPerRow:bytesPerRow];
    
    return texture;
}

@end

NS_ASSUME_NONNULL_END
