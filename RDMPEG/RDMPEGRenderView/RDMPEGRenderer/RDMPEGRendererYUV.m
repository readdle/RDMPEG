//
//  RDMPEGRendererYUV.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/5/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGRendererYUV.h"
#import "RDMPEGShaders.h"
#import "RDMPEGFrames.h"
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRendererYUV () {
    GLint _uniformSamplers[3];
    GLuint _textures[3];
}

@end



@implementation RDMPEGRendererYUV

#pragma mark - Overridden Class Methods

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGRendererYUV"];
}

#pragma mark - Lifecycle

- (void)dealloc {
    if (_textures[0]) {
        glDeleteTextures(3, _textures);
    }
}

#pragma mark - RDMPEGRenderer

- (BOOL)isValid {
    return (_textures[0] != 0);
}

- (NSString *)fragmentShader {
    return yuvFragmentShaderString;
}

- (void)resolveUniforms:(GLuint)program {
    _uniformSamplers[0] = glGetUniformLocation(program, "s_texture_y");
    _uniformSamplers[1] = glGetUniformLocation(program, "s_texture_u");
    _uniformSamplers[2] = glGetUniformLocation(program, "s_texture_v");
}

- (void)generateTextureForFrame:(RDMPEGVideoFrame *)videoFrame {
    if ([videoFrame isKindOfClass:[RDMPEGVideoFrameYUV class]] == NO) {
        log4Assert(NO, @"YUV frame expected");
        return;
    }
    
    RDMPEGVideoFrameYUV *yuvFrame = (RDMPEGVideoFrameYUV *)videoFrame;
    
    log4Assert(yuvFrame.luma.length == yuvFrame.width * yuvFrame.height, @"Unexpected luma data length");
    log4Assert(yuvFrame.chromaB.length == ((yuvFrame.width / 2) * (yuvFrame.height / 2)), @"Unexpected chromaB data length");
    log4Assert(yuvFrame.chromaR.length == ((yuvFrame.width / 2) * (yuvFrame.height / 2)), @"Unexpected chromaR data length");
    
    const NSUInteger frameWidth = yuvFrame.width;
    const NSUInteger frameHeight = yuvFrame.height;
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (_textures[0] == 0) {
        glGenTextures(3, _textures);
    }
    
    const UInt8 *pixels[3] = { yuvFrame.luma.bytes, yuvFrame.chromaB.bytes, yuvFrame.chromaR.bytes };
    const NSUInteger widths[3]  = { frameWidth, frameWidth / 2, frameWidth / 2 };
    const NSUInteger heights[3] = { frameHeight, frameHeight / 2, frameHeight / 2 };
    
    for (int i = 0; i < 3; ++i) {
        glBindTexture(GL_TEXTURE_2D, _textures[i]);
        
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     (int)widths[i],
                     (int)heights[i],
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     pixels[i]);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}

- (BOOL)prepareRender {
    if (_textures[0] == 0) {
        return NO;
    }
        
    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, _textures[i]);
        glUniform1i(_uniformSamplers[i], i);
    }
    
    return YES;
}

@end

NS_ASSUME_NONNULL_END
