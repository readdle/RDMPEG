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
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGTextureSamplerYUV ()

@property (nonatomic, strong, nullable) id<MTLTexture> yTexture;
@property (nonatomic, strong, nullable) id<MTLTexture> uTexture;
@property (nonatomic, strong, nullable) id<MTLTexture> vTexture;

@end



@implementation RDMPEGTextureSamplerYUV

#pragma mark - RDMPEGTextureSampler

- (id<MTLFunction>)newSamplingFunctionFromLibrary:(id<MTLLibrary>)library {
    return [library newFunctionWithName:@"samplingShaderYUV"];
}

- (void)setupTexturesWithDevice:(id<MTLDevice>)device
                     frameWidth:(NSUInteger)frameWidth
                    frameHeight:(NSUInteger)frameHeight
{
    if (self.yTexture || self.uTexture || self.vTexture) {
        NSAssert(NO, @"Textures are already created");
        return;
    }
    
    MTLTextureDescriptor * const yTextureDescriptor = [[MTLTextureDescriptor alloc] init];
    yTextureDescriptor.pixelFormat = MTLPixelFormatR8Unorm;
    yTextureDescriptor.width = frameWidth;
    yTextureDescriptor.height = frameHeight;
    
    MTLTextureDescriptor * const uvTextureDescriptor = [[MTLTextureDescriptor alloc] init];
    uvTextureDescriptor.pixelFormat = MTLPixelFormatR8Unorm;
    uvTextureDescriptor.width = frameWidth / 2;
    uvTextureDescriptor.height = frameHeight / 2;
    
    self.yTexture = [device newTextureWithDescriptor:yTextureDescriptor];
    self.uTexture = [device newTextureWithDescriptor:uvTextureDescriptor];
    self.vTexture = [device newTextureWithDescriptor:uvTextureDescriptor];
}

- (void)updateTexturesWithFrame:(RDMPEGVideoFrame *)videoFrame
                  renderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder
{
    if (nil == self.yTexture || nil == self.uTexture || nil == self.vTexture) {
        NSAssert(NO, @"'%@' must be called before updating textures",
                 NSStringFromSelector(@selector(setupTexturesWithDevice:frameWidth:frameHeight:)));
        return;
    }
    
    if (nil == videoFrame) {
        NSParameterAssert(NO);
        return;
    }
    
    if (NO == [videoFrame isKindOfClass:[RDMPEGVideoFrameYUV class]]) {
        NSParameterAssert(NO);
        return;
    }
    
    if (self.yTexture.width != videoFrame.width ||
        self.yTexture.height != videoFrame.height ||
        self.uTexture.width != videoFrame.width / 2 ||
        self.uTexture.height != videoFrame.height / 2 ||
        self.vTexture.width != videoFrame.width / 2 ||
        self.vTexture.height != videoFrame.height / 2)
    {
        log4Assert(NO, @"Video frame size (%ld %ld) does not correspond to texture sizes Y(%ld %ld) U(%ld %ld) V(%ld %ld)",
                   videoFrame.width,
                   videoFrame.height,
                   self.yTexture.width,
                   self.yTexture.height,
                   self.uTexture.width,
                   self.uTexture.height,
                   self.vTexture.width,
                   self.vTexture.height);
        return;
    }
    
    RDMPEGVideoFrameYUV * const yuvFrame = (RDMPEGVideoFrameYUV *)videoFrame;
    
    MTLRegion yRegion;
    yRegion.origin = MTLOriginMake(0, 0, 0);
    yRegion.size = MTLSizeMake(videoFrame.width, videoFrame.height, 1);
    
    MTLRegion uvRegion;
    uvRegion.origin = MTLOriginMake(0, 0, 0);
    uvRegion.size = MTLSizeMake(videoFrame.width / 2, videoFrame.height / 2, 1);
    
    [self.yTexture
     replaceRegion:yRegion
     mipmapLevel:0
     withBytes:yuvFrame.luma.bytes
     bytesPerRow:videoFrame.width];
    
    [self.uTexture
     replaceRegion:uvRegion
     mipmapLevel:0
     withBytes:yuvFrame.chromaB.bytes
     bytesPerRow:videoFrame.width / 2];
    
    [self.vTexture
     replaceRegion:uvRegion
     mipmapLevel:0
     withBytes:yuvFrame.chromaR.bytes
     bytesPerRow:videoFrame.width / 2];
    
    [renderEncoder setFragmentTexture:self.yTexture atIndex:RDMPEGTextureIndexY];
    [renderEncoder setFragmentTexture:self.uTexture atIndex:RDMPEGTextureIndexU];
    [renderEncoder setFragmentTexture:self.vTexture atIndex:RDMPEGTextureIndexV];
}

@end

NS_ASSUME_NONNULL_END
