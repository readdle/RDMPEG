//
//  RDMPEGRenderView.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 03.12.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "RDMPEGRenderView.h"
#import <Metal/Metal.h>
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRenderView ()

@property (nonatomic, readonly) NSUInteger frameWidth;
@property (nonatomic, readonly) NSUInteger frameHeight;
@property (nonatomic, readonly) CAMetalLayer *metalLayer;
@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLBuffer> vertexBuffer;
@property (nonatomic, readonly) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, readonly) id<MTLCommandQueue> commandQueue;

@end



@implementation RDMPEGRenderView

#pragma mark - Overridden Class Methods

+ (Class)layerClass {
    return [CAMetalLayer class];
}

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGRenderView"];
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
                   frameWidth:(NSUInteger)frameWidth
                  frameHeight:(NSUInteger)frameHeight {
    self = [super initWithFrame:frame];
    
    if (nil == self) {
        return nil;
    }
    
    self.contentMode = UIViewContentModeScaleAspectFit;
    
    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    
    _device = MTLCreateSystemDefaultDevice();
    
    self.metalLayer.device = self.device;
    self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalLayer.framebufferOnly = YES;
    
    const float bytes[] = {
        0.0,  1.0, 0.0,
        -1.0, -1.0, 0.0,
        1.0, -1.0, 0.0
    };
    const NSUInteger length = sizeof(bytes) * sizeof(bytes[0]);
    _vertexBuffer = [self.device newBufferWithBytes:bytes length:length options:0];
    
    id<MTLLibrary> const defaultLibrary = [self.device newDefaultLibrary];
    
    MTLRenderPipelineDescriptor * const pipelineStateDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineStateDescriptor.vertexFunction = [defaultLibrary newFunctionWithName:@"basic_vertex"];
    pipelineStateDescriptor.fragmentFunction = [defaultLibrary newFunctionWithName:@"basic_fragment"];
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    // TODO: SA CHECK - handle errors
    _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:nil];
    
    _commandQueue = [self.device newCommandQueue];
    
    return self;
}

#pragma mark - Overridden

- (void)layoutSubviews {
    [super layoutSubviews];
    
//    [self updateVertices];
}

#pragma mark - Public Accessors

- (CAMetalLayer *)metalLayer {
    return (CAMetalLayer *)self.layer;
}

- (CGRect)videoFrame {
    return self.isAspectFillMode ? self.bounds : self.aspectFitVideoFrame;
}

- (void)setAspectFillMode:(BOOL)aspectFillMode {
    if (_aspectFillMode == aspectFillMode) {
        return;
    }
    
    _aspectFillMode = aspectFillMode;
    
    [self updateView];
}

- (void)updateView{
//    [self updateVertices];
//    if (self.renderer.isValid) {
//        [self render:nil];
//    }
}

#pragma mark - Public Methods

- (void)render:(nullable RDMPEGVideoFrame *)videoFrame {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }
    
    id<CAMetalDrawable> const drawable = self.metalLayer.nextDrawable;
    
    if (nil == drawable) {
        return;
    }
    
    MTLRenderPassDescriptor * const renderPassDescriptor = [MTLRenderPassDescriptor new];
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.4, 0.2, 1.0);
    
    id<MTLCommandBuffer> const commandBuffer = [self.commandQueue commandBuffer];
    
    id<MTLRenderCommandEncoder> const renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setRenderPipelineState:self.pipelineState];
    [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3 instanceCount:1];
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

@end

NS_ASSUME_NONNULL_END
