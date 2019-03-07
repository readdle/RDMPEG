//
//  RDMPEGRenderView.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGRenderView.h"
#import "RDMPEGFrames.h"
#import "RDMPEGShaders.h"
#import "RDMPEGRenderer.h"
#import <OpenGLES/ES2/gl.h>
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

static BOOL validate_program(GLuint prog);
static GLuint compile_shader(GLenum type, NSString *shaderString);
static void mat4f_load_ortho(float left, float right, float bottom, float top, float near, float far, float *mout);

enum {
    ATTRIBUTE_VERTEX,
    ATTRIBUTE_TEXCOORD,
};



@interface RDMPEGRenderView () {
    EAGLContext *_context;
    GLuint _framebuffer;
    GLuint _renderbuffer;
    GLint _backingWidth;
    GLint _backingHeight;
    GLuint _program;
    GLint _uniformMatrix;
    GLfloat _vertices[8];
}

@property (nonatomic, strong, nullable) id<RDMPEGRenderer> renderer;
@property (nonatomic, assign) NSUInteger frameWidth;
@property (nonatomic, assign) NSUInteger frameHeight;

@end



@implementation RDMPEGRenderView

#pragma mark - Overridden Class Methods

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGRenderView"];
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
                     renderer:(id<RDMPEGRenderer>)renderer
                   frameWidth:(NSUInteger)frameWidth
                  frameHeight:(NSUInteger)frameHeight {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentMode = UIViewContentModeScaleAspectFit;
        
        self.renderer = renderer;
        self.frameWidth = frameWidth;
        self.frameHeight = frameHeight;
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @NO,
                                         kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        self.contentScaleFactor = [UIScreen mainScreen].scale;
        eaglLayer.contentsScale = [UIScreen mainScreen].scale;
        
        if (_context == NULL || [EAGLContext setCurrentContext:_context] == NO) {
            log4Assert(NO, @"Failed to setup EAGLContext");
            return nil;
        }
        
        glGenFramebuffers(1, &_framebuffer);
        glGenRenderbuffers(1, &_renderbuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE) {
            log4Assert(NO, @"Failed to make complete framebuffer object %x", status);
            return nil;
        }
        
        GLenum glError = glGetError();
        if (GL_NO_ERROR != glError) {
            log4Assert(NO, @"Failed to setup GL %x", glError);
            return nil;
        }
        
        if (![self loadShaders]) {
            log4Assert(NO, @"Failed to load shaders");
            return nil;
        }
        
        _vertices[0] = -1.0f;  // x0
        _vertices[1] = -1.0f;  // y0
        _vertices[2] =  1.0f;  // ..
        _vertices[3] = -1.0f;
        _vertices[4] = -1.0f;
        _vertices[5] =  1.0f;
        _vertices[6] =  1.0f;  // x3
        _vertices[7] =  1.0f;  // y3
    }
    
    return self;
}

- (void)dealloc {
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
}

#pragma mark - Overridden

- (void)layoutSubviews {
    [super layoutSubviews];
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    log4Assert(status == GL_FRAMEBUFFER_COMPLETE, @"Failed to make complete framebuffer object %x", status);
    
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
    if (self.renderer.isValid) {
        [self render:nil];
    }
}

#pragma mark - Public Methods

- (void)render:(nullable RDMPEGVideoFrame *)videoFrame {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }
    
    static const GLfloat texCoords[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    [EAGLContext setCurrentContext:_context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(_program);
    
    log4Assert(self.renderer, @"Renderer not specified");
    
    if (videoFrame) {
        [self.renderer generateTextureForFrame:videoFrame];
    }
    
    if ([self.renderer prepareRender]) {
        GLfloat modelviewProj[16];
        mat4f_load_ortho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewProj);
        glUniformMatrix4fv(_uniformMatrix, 1, GL_FALSE, modelviewProj);
        
        glVertexAttribPointer(ATTRIBUTE_VERTEX, 2, GL_FLOAT, 0, 0, _vertices);
        glEnableVertexAttribArray(ATTRIBUTE_VERTEX);
        glVertexAttribPointer(ATTRIBUTE_TEXCOORD, 2, GL_FLOAT, 0, 0, texCoords);
        glEnableVertexAttribArray(ATTRIBUTE_TEXCOORD);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - Private Methods

- (BOOL)loadShaders {
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    
    _program = glCreateProgram();
    
    vertShader = compile_shader(GL_VERTEX_SHADER, vertexShaderString);
    if (vertShader == 0) {
        goto exit;
    }
    
    fragShader = compile_shader(GL_FRAGMENT_SHADER, self.renderer.fragmentShader);
    if (fragShader == 0) {
        goto exit;
    }
    
    glAttachShader(_program, vertShader);
    glAttachShader(_program, fragShader);
    glBindAttribLocation(_program, ATTRIBUTE_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIBUTE_TEXCOORD, "texcoord");
    
    glLinkProgram(_program);
    
    GLint status;
    glGetProgramiv(_program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        log4Error(@"Failed to link program %d", _program);
        goto exit;
    }
    
    result = validate_program(_program);
    
    _uniformMatrix = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    [self.renderer resolveUniforms:_program];
    
exit:
    
    if (vertShader) {
        glDeleteShader(vertShader);
    }
    
    if (fragShader) {
        glDeleteShader(fragShader);
    }
    
    if (result == NO) {
        glDeleteProgram(_program);
        _program = 0;
    }
    
    return result;
}

- (void)updateVertices {
    const BOOL fit = (self.isAspectFillMode == NO);
    const float width = self.frameWidth > 0 ? self.frameWidth : _backingWidth;
    const float height = self.frameHeight > 0 ? self.frameHeight : _backingHeight;
    const float dH = (float)_backingHeight / height;
    const float dW = (float)_backingWidth / width;
    const float mindd = MIN(dH, dW);
    const float maxdd = MAX(dH, dW);
    const float minh = (height * mindd / (float)_backingHeight);
    const float maxh = (height * maxdd / (float)_backingHeight);
    const float minw = (width * mindd / (float)_backingWidth);
    const float maxw = (width * maxdd / (float)_backingWidth);
    const float h = fit ? minh : maxh;
    const float w = fit ? minw : maxw;
    
    _vertices[0] = - w;
    _vertices[1] = - h;
    _vertices[2] =   w;
    _vertices[3] = - h;
    _vertices[4] = - w;
    _vertices[5] =   h;
    _vertices[6] =   w;
    _vertices[7] =   h;
    
    _aspectFitVideoFrame = CGRectMake(((_backingWidth - (_backingWidth * minw)) / 2.0) / self.contentScaleFactor,
                                      ((_backingHeight - (_backingHeight * minh)) / 2.0) / self.contentScaleFactor,
                                      (_backingWidth * minw) / self.contentScaleFactor,
                                      (_backingHeight * minh) / self.contentScaleFactor);
    _aspectFitVideoFrame = CGRectIntegral(_aspectFitVideoFrame);
}

@end



static BOOL validate_program(GLuint prog) {
    GLint status;
    
    glValidateProgram(prog);
    
#ifdef DEBUG
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        log4CDebug(@"Program validate log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
        log4CError(@"Failed to validate program %d", prog);
        return NO;
    }
    
    return YES;
}

static GLuint compile_shader(GLenum type, NSString *shaderString) {
    GLint status;
    const GLchar *sources = (GLchar *)shaderString.UTF8String;
    
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        log4CError(@"Failed to create shader %d", type);
        return 0;
    }
    
    glShaderSource(shader, 1, &sources, NULL);
    glCompileShader(shader);
    
#ifdef DEBUG
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        log4CDebug(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
        log4CDebug(@"Failed to compile shader:\n");
        return 0;
    }
    
    return shader;
}

static void mat4f_load_ortho(float left, float right, float bottom, float top, float near, float far, float *mout) {
    float r_l = right - left;
    float t_b = top - bottom;
    float f_n = far - near;
    float tx = - (right + left) / (right - left);
    float ty = - (top + bottom) / (top - bottom);
    float tz = - (far + near) / (far - near);
    
    mout[0] = 2.0f / r_l;
    mout[1] = 0.0f;
    mout[2] = 0.0f;
    mout[3] = 0.0f;
    
    mout[4] = 0.0f;
    mout[5] = 2.0f / t_b;
    mout[6] = 0.0f;
    mout[7] = 0.0f;
    
    mout[8] = 0.0f;
    mout[9] = 0.0f;
    mout[10] = -2.0f / f_n;
    mout[11] = 0.0f;
    
    mout[12] = tx;
    mout[13] = ty;
    mout[14] = tz;
    mout[15] = 1.0f;
}

NS_ASSUME_NONNULL_END
