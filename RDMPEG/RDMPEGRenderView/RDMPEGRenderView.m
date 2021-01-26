//
//  RDMPEGRenderView.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 03.12.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "RDMPEGRenderView.h"
#import "RDMPEGTextureSampler.h"
#import "RDMPEGShaderTypes.h"
#import "RDMPEGFrames.h"
#import <Metal/Metal.h>
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRenderView ()

@property (nonatomic, readonly) BOOL isAbleToRender;
@property (nonatomic, readonly) NSUInteger frameWidth;
@property (nonatomic, readonly) NSUInteger frameHeight;
@property (nonatomic, readonly) id<RDMPEGTextureSampler> textureSampler;
@property (nonatomic, readonly) id<MTLBuffer> vertexBuffer;
@property (nonatomic, readonly) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, readonly) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong, nullable) RDMPEGVideoFrame *currentFrame;

@end



@implementation RDMPEGRenderView

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGRenderView"];
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
               textureSampler:(id<RDMPEGTextureSampler>)textureSampler
                   frameWidth:(NSUInteger)frameWidth
                  frameHeight:(NSUInteger)frameHeight
{
    self = [super initWithFrame:frame device:MTLCreateSystemDefaultDevice()];
    
    if (nil == self) {
        return nil;
    }
    
    self.contentMode = UIViewContentModeScaleAspectFit;
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.framebufferOnly = YES;
    
    // Fix:
    // https://readdle-j.atlassian.net/browse/DOC-5892
    // https://readdle-j.atlassian.net/browse/DOC-5899
    // https://readdle-j.atlassian.net/browse/DOC-5912
    self.paused = YES;
    self.enableSetNeedsDisplay = NO;
    
    _textureSampler = textureSampler;
    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    
    if (self.isAbleToRender) {
        [self setupRenderingPipeline];
    }
    
    return self;
}

#pragma mark - Overridden

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.drawableSize =
    CGSizeMake(CGRectGetWidth(self.bounds) * self.contentScaleFactor,
               CGRectGetHeight(self.bounds) * self.contentScaleFactor);
    
    [self updateVertices];
}

#pragma mark - Public Accessors

- (CGRect)videoFrame {
    return self.isAspectFillMode ? self.bounds : self.aspectFitVideoFrame;
}

- (void)setAspectFillMode:(BOOL)aspectFillMode {
    if (_aspectFillMode == aspectFillMode) {
        return;
    }
    
    _aspectFillMode = aspectFillMode;
    
    [self updateVertices];
    [self render:self.currentFrame];
}

#pragma mark - Private Accessors

- (BOOL)isAbleToRender {
    return self.frameWidth > 0 && self.frameHeight > 0;
}

#pragma mark - Public Methods

- (void)render:(nullable RDMPEGVideoFrame *)videoFrame {
    if (NO == self.isAbleToRender) {
        log4Assert(nil == videoFrame, @"Attempt to render frame in invalid state");
        return;
    }
    
    self.currentFrame = videoFrame;
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }
    
    id<CAMetalDrawable> const drawable = self.currentDrawable;
    
    if (nil == drawable) {
        return;
    }
    
    id<MTLCommandBuffer> const commandBuffer = [self.commandQueue commandBuffer];
    
    MTLRenderPassDescriptor * const renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    id<MTLRenderCommandEncoder> renderEncoder =
    [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    MTLViewport viewport;
    viewport.originX = 0.0;
    viewport.originY = 0.0;
    viewport.width = self.drawableSize.width;
    viewport.height = self.drawableSize.height;
    viewport.znear = -1.0;
    viewport.zfar = 1.0;
    
    vector_uint2 viewportSize;
    viewportSize.x = (unsigned int)viewport.width;
    viewportSize.y = (unsigned int)viewport.height;
    
    [renderEncoder setViewport:viewport];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:RDMPEGVertexInputIndexVertices];
    [renderEncoder setVertexBytes:&viewportSize length:sizeof(viewportSize) atIndex:RDMPEGVertexInputIndexViewportSize];
    
    if (videoFrame) {
        [self.textureSampler
         updateTexturesWithFrame:videoFrame
         renderEncoder:renderEncoder];
    }
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
    
    [self draw];
}

#pragma mark - Private Methods

- (void)setupRenderingPipeline {
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.framebufferOnly = YES;
    
    id<MTLLibrary> const defaultLibrary = [self.device newDefaultLibrary];
    
    MTLRenderPipelineDescriptor * const pipelineStateDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineStateDescriptor.vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    pipelineStateDescriptor.fragmentFunction = [self.textureSampler newSamplingFunctionFromLibrary:defaultLibrary];
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    [self.textureSampler
     setupTexturesWithDevice:self.device
     frameWidth:self.frameWidth
     frameHeight:self.frameHeight];
    
    NSError *renderPipelineError = nil;
    _pipelineState =
    [self.device
     newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
     error:&renderPipelineError];
    log4Assert(nil == renderPipelineError, @"Unable to create render pipeline: %@", renderPipelineError);
    
    _commandQueue = [self.device newCommandQueue];
    
    [self updateVertices];
    [self listenNotifications];
}

- (void)listenNotifications {
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(applicationDidBecomeActiveNotification:)
     name:UIApplicationDidBecomeActiveNotification
     object:nil];
}

- (void)updateVertices {
    if (NO == self.isAbleToRender) {
        return;
    }
    
    const double xScale = self.drawableSize.width / self.frameWidth;
    const double yScale = self.drawableSize.height / self.frameHeight;
    const double minScale = MIN(xScale, yScale);
    const double maxScale = MAX(xScale, yScale);
    const double scale = self.isAspectFillMode ? maxScale : minScale;
    
    const double halfWidth = self.frameWidth / 2.0;
    const double halfHeight = self.frameHeight / 2.0;
    
    const double adjustedWidth = halfWidth * scale;
    const double adjustedHeight = halfHeight * scale;
    
    const RDMPEGVertex quadVertices[] = {
        // Pixel positions, Texture coordinates
        { {  adjustedWidth,  -adjustedHeight },  { 1.0f, 1.0f } },
        { { -adjustedWidth,  -adjustedHeight },  { 0.0f, 1.0f } },
        { { -adjustedWidth,   adjustedHeight },  { 0.0f, 0.0f } },

        { {  adjustedWidth,  -adjustedHeight },  { 1.0f, 1.0f } },
        { { -adjustedWidth,   adjustedHeight },  { 0.0f, 0.0f } },
        { {  adjustedWidth,   adjustedHeight },  { 1.0f, 0.0f } },
    };
    
    _vertexBuffer =
    [self.device
     newBufferWithBytes:quadVertices
     length:sizeof(quadVertices)
     options:MTLResourceStorageModeShared];
}

#pragma mark - Notifications

- (void)applicationDidBecomeActiveNotification:(NSNotification *)notification {
    [self render:self.currentFrame];
}

@end

NS_ASSUME_NONNULL_END
