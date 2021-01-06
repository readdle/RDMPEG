//
//  RDMPEGRenderer.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 06.01.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <Metal/Metal.h>

@class RDMPEGVideoFrame;



NS_ASSUME_NONNULL_BEGIN

@protocol RDMPEGRenderer <NSObject>

- (id<MTLFunction>)newSamplingFunctionFromLibrary:(id<MTLLibrary>)library;

- (void)updateTexturesWithFrame:(RDMPEGVideoFrame *)videoFrame
                         device:(id<MTLDevice>)device
                  renderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder;

@end

NS_ASSUME_NONNULL_END
