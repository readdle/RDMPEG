//
//  RDMPEGRenderer.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/5/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>

@class RDMPEGVideoFrame;



NS_ASSUME_NONNULL_BEGIN

@protocol RDMPEGRenderer <NSObject>

@property (nonatomic, readonly, getter=isValid) BOOL valid;
@property (nonatomic, readonly) NSString *fragmentShader;

- (void)resolveUniforms:(GLuint)program;
- (void)generateTextureForFrame:(RDMPEGVideoFrame *)videoFrame;
- (BOOL)prepareRender;

@end

NS_ASSUME_NONNULL_END
