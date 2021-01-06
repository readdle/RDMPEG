//
//  RDMPEGRendererRGB.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 06.01.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "RDMPEGRendererRGB.h"
#import "RDMPEGFrames.h"
#import "RDMPEGShaderTypes.h"



NS_ASSUME_NONNULL_BEGIN

@implementation RDMPEGRendererRGB

#pragma mark - RDMPEGRenderer

- (id<MTLFunction>)newSamplingFunctionFromLibrary:(id<MTLLibrary>)library {
    return [library newFunctionWithName:@"samplingShaderRGB"];
}

- (void)updateTexturesWithFrame:(RDMPEGVideoFrame *)videoFrame
                         device:(id<MTLDevice>)device
                  renderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder
{
    if (nil == videoFrame) {
        NSParameterAssert(NO);
        return;
    }
    
    if (NO == [videoFrame isKindOfClass:[RDMPEGVideoFrameRGB class]]) {
        NSParameterAssert(NO);
        return;
    }
    
    RDMPEGVideoFrameRGB * const rgbFrame = (RDMPEGVideoFrameRGB *)videoFrame;
    
    id<MTLTexture> texture = [self textureFromFrame:rgbFrame device:device];
    
    [renderEncoder setFragmentTexture:texture
                              atIndex:RDMPEGTextureIndexRGBBaseColor];
}

#pragma mark - Private Methods

- (id<MTLTexture>)textureFromFrame:(RDMPEGVideoFrameRGB *)videoFrame
                            device:(id<MTLDevice>)device
{
    NSParameterAssert(videoFrame);
    
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    
    // Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
    // an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
    textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    // Set the pixel dimensions of the texture
    textureDescriptor.width = videoFrame.width;
    textureDescriptor.height = videoFrame.height;
    
    // Create the texture from the device by using the descriptor
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    
    // Calculate the number of bytes per row in the image.
    NSUInteger bytesPerRow = 4 * videoFrame.width;
    
    MTLRegion region = {
        { 0, 0, 0 },                   // MTLOrigin
        {videoFrame.width, videoFrame.height, 1} // MTLSize
    };
    
    // Copy the bytes from the data object into the texture
    [texture replaceRegion:region
               mipmapLevel:0
                 withBytes:[videoFrame rgb].bytes
               bytesPerRow:bytesPerRow];
    
    return texture;
}

@end

NS_ASSUME_NONNULL_END
