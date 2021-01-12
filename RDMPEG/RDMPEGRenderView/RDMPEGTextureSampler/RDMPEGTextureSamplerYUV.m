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
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    
    // Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
    // an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
    textureDescriptor.pixelFormat = MTLPixelFormatR8Unorm;
    
    // Set the pixel dimensions of the texture
    textureDescriptor.width = videoFrame.width;
    textureDescriptor.height = videoFrame.height;
    
    // Create the texture from the device by using the descriptor
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    
    // Calculate the number of bytes per row in the image.
    NSUInteger bytesPerRow = videoFrame.width;
    
    MTLRegion region = {
        { 0, 0, 0 },                   // MTLOrigin
        {videoFrame.width, videoFrame.height, 1} // MTLSize
    };
    
    // Copy the bytes from the data object into the texture
    [texture replaceRegion:region
                mipmapLevel:0
                  withBytes:[videoFrame luma].bytes
                bytesPerRow:bytesPerRow];
    return texture;
}

- (id<MTLTexture>)uTextureFromFrame:(RDMPEGVideoFrameYUV *)videoFrame
                             device:(id<MTLDevice>)device
{
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    
    // Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
    // an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
    textureDescriptor.pixelFormat = MTLPixelFormatR8Unorm;
    
    // Set the pixel dimensions of the texture
    textureDescriptor.width = videoFrame.width / 2;
    textureDescriptor.height = videoFrame.height / 2;
    
    // Create the texture from the device by using the descriptor
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    
    // Calculate the number of bytes per row in the image.
    NSUInteger bytesPerRow = videoFrame.width / 2;
    
    MTLRegion region = {
        { 0, 0, 0 },                   // MTLOrigin
        {videoFrame.width / 2, videoFrame.height / 2, 1} // MTLSize
    };
    
    // Copy the bytes from the data object into the texture
    [texture replaceRegion:region
                mipmapLevel:0
                  withBytes:[videoFrame chromaB].bytes
                bytesPerRow:bytesPerRow];
    return texture;
}

- (id<MTLTexture>)vTextureFromFrame:(RDMPEGVideoFrameYUV *)videoFrame
                             device:(id<MTLDevice>)device
{
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    
    // Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
    // an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
    textureDescriptor.pixelFormat = MTLPixelFormatR8Unorm;
    
    // Set the pixel dimensions of the texture
    textureDescriptor.width = videoFrame.width / 2;
    textureDescriptor.height = videoFrame.height / 2;
    
    // Create the texture from the device by using the descriptor
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    
    // Calculate the number of bytes per row in the image.
    NSUInteger bytesPerRow = videoFrame.width / 2;
    
    MTLRegion region = {
        { 0, 0, 0 },                   // MTLOrigin
        {videoFrame.width / 2, videoFrame.height / 2, 1} // MTLSize
    };
    
    // Copy the bytes from the data object into the texture
    [texture replaceRegion:region
                mipmapLevel:0
                  withBytes:[videoFrame chromaR].bytes
                bytesPerRow:bytesPerRow];
    return texture;
}

@end

NS_ASSUME_NONNULL_END
