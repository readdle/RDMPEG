//
//  RDMPEGTextureSampler.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 06.01.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <Metal/Metal.h>

@class RDMPEGVideoFrame;



NS_ASSUME_NONNULL_BEGIN

@protocol RDMPEGTextureSampler <NSObject>

- (id<MTLFunction>)newSamplingFunctionFromLibrary:(id<MTLLibrary>)library;

- (void)setupTexturesWithDevice:(id<MTLDevice>)device
                     frameWidth:(NSUInteger)frameWidth
                    frameHeight:(NSUInteger)frameHeight;

- (void)updateTexturesWithFrame:(RDMPEGVideoFrame *)videoFrame
                  renderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder;

@end

NS_ASSUME_NONNULL_END
