//
//  RDMPEGRendererRGB.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/5/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGRendererRGB.h"
#import "RDMPEGShaders.h"
#import "RDMPEGFrames.h"
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRendererRGB () {
    GLint _uniformSampler;
    GLuint _texture;
}

@end



@implementation RDMPEGRendererRGB

#pragma mark - Overridden Class Methods

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGRendererRGB"];
}

#pragma mark - Lifecycle

- (void)dealloc {
    if (_texture) {
        glDeleteTextures(1, &_texture);
        _texture = 0;
    }
}

#pragma mark - RDMPEGRenderer

- (BOOL)isValid {
    return (_texture != 0);
}

- (NSString *)fragmentShader {
    return rgbFragmentShaderString;
}

- (void)resolveUniforms:(GLuint)program {
    _uniformSampler = glGetUniformLocation(program, "s_texture");
}

- (void)generateTextureForFrame:(RDMPEGVideoFrame *)videoFrame {
    if ([videoFrame isKindOfClass:[RDMPEGVideoFrameRGB class]] == NO) {
        log4Assert(NO, @"RGB frame expected");
        return;
    }
    
    RDMPEGVideoFrameRGB *rgbFrame = (RDMPEGVideoFrameRGB *)videoFrame;
    
    log4Assert(rgbFrame.rgb.length == rgbFrame.width * rgbFrame.height * 3, @"Unexpected rgb data length");
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (_texture == 0) {
        glGenTextures(1, &_texture);
    }
    
    glBindTexture(GL_TEXTURE_2D, _texture);
    
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGB,
                 (int)rgbFrame.width,
                 (int)rgbFrame.height,
                 0,
                 GL_RGB,
                 GL_UNSIGNED_BYTE,
                 rgbFrame.rgb.bytes);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (BOOL)prepareRender {
    if (_texture == 0) {
        return NO;
    }
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(_uniformSampler, 0);
    
    return YES;
}

@end

NS_ASSUME_NONNULL_END
