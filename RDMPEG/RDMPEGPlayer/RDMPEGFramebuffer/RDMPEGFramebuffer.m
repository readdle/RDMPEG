//
//  RDMPEGFramebuffer.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 8/17/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGFramebuffer.h"
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGFramebuffer ()

@property (nonatomic, strong) NSMutableArray<RDMPEGVideoFrame *> *videoFrames;
@property (nonatomic, strong) NSMutableArray<RDMPEGAudioFrame *> *audioFrames;
@property (nonatomic, strong) NSMutableArray<RDMPEGSubtitleFrame *> *subtitleFrames;
@property (atomic, strong, nullable) RDMPEGArtworkFrame *artworkFrame;

@end



@implementation RDMPEGFramebuffer

#pragma mark - Overridden Class Methods

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGFramebuffer"];
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        self.videoFrames = [NSMutableArray array];
        self.audioFrames = [NSMutableArray array];
        self.subtitleFrames = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public Accessors

- (NSTimeInterval)bufferedVideoDuration {
    @synchronized (self.videoFrames) {
        NSTimeInterval bufferedVideoDuration = 0.0;
        for (RDMPEGVideoFrame *videoFrame in self.videoFrames) {
            bufferedVideoDuration += videoFrame.duration;
        }
        return bufferedVideoDuration;
    }
}

- (NSTimeInterval)bufferedAudioDuration {
    @synchronized (self.audioFrames) {
        NSTimeInterval bufferedAudioDuration = 0.0;
        for (RDMPEGAudioFrame *audioFrame in self.audioFrames) {
            bufferedAudioDuration += audioFrame.duration;
        }
        return bufferedAudioDuration;
    }
}

- (NSTimeInterval)bufferedSubtitleDuration {
    @synchronized (self.subtitleFrames) {
        NSTimeInterval minSubtitlePosition = self.nextSubtitleFrame.position;
        NSTimeInterval maxSubtitlePosition = self.nextSubtitleFrame.position + self.nextSubtitleFrame.duration;
        
        for (RDMPEGSubtitleFrame *subtitleFrame in self.subtitleFrames) {
            minSubtitlePosition = MIN(minSubtitlePosition, subtitleFrame.position);
            maxSubtitlePosition = MAX(maxSubtitlePosition, subtitleFrame.position + subtitleFrame.duration);
        }
        
        return maxSubtitlePosition - minSubtitlePosition;
    }
}

- (NSUInteger)bufferedVideoFramesCount {
    @synchronized (self.videoFrames) {
        return self.videoFrames.count;
    }
}

- (NSUInteger)bufferedAudioFramesCount {
    @synchronized (self.audioFrames) {
        return self.audioFrames.count;
    }
}

- (NSUInteger)bufferedSubtitleFramesCount {
    @synchronized (self.subtitleFrames) {
        return self.subtitleFrames.count;
    }
}

- (nullable RDMPEGVideoFrame *)nextVideoFrame {
    @synchronized (self.videoFrames) {
        return self.videoFrames.firstObject;
    }
}

- (nullable RDMPEGAudioFrame *)nextAudioFrame {
    @synchronized (self.audioFrames) {
        return self.audioFrames.firstObject;
    }
}

- (nullable RDMPEGSubtitleFrame *)nextSubtitleFrame {
    @synchronized (self.subtitleFrames) {
        return self.subtitleFrames.firstObject;
    }
}

#pragma mark - Public Methods

- (void)pushFrames:(NSArray<RDMPEGFrame *> *)frames {
    for (RDMPEGFrame *frame in frames) {
        switch (frame.type) {
            case RDMPEGFrameTypeVideo: {
                RDMPEGVideoFrame *videoFrame = (RDMPEGVideoFrame *)frame;
                
#if defined(RD_DEBUG_MPEG_PLAYER)
                log4Debug(@"Pushed video frame: %f %f", frame.position, frame.duration);
#endif // RD_DEBUG_MPEG_PLAYER
                
                @synchronized (self.videoFrames) {
                    [self.videoFrames addObject:videoFrame];
                }
                break;
            }
            case RDMPEGFrameTypeAudio: {
                RDMPEGAudioFrame *audioFrame = (RDMPEGAudioFrame *)frame;
                
#if defined(RD_DEBUG_MPEG_PLAYER)
                log4Debug(@"Pushed audio frame: %f %f", frame.position, frame.duration);
#endif // RD_DEBUG_MPEG_PLAYER
                
                @synchronized (self.audioFrames) {
                    [self.audioFrames addObject:audioFrame];
                }
                break;
            }
            case RDMPEGFrameTypeSubtitle: {
                RDMPEGSubtitleFrame *subtitleFrame = (RDMPEGSubtitleFrame *)frame;
                
#if defined(RD_DEBUG_MPEG_PLAYER)
                log4Debug(@"Pushed subtitle frame: %f %f %@", subtitleFrame.position, subtitleFrame.duration, subtitleFrame.text);
#endif // RD_DEBUG_MPEG_PLAYER
                
                @synchronized (self.subtitleFrames) {
                    [self.subtitleFrames addObject:subtitleFrame];
                }
                break;
            }
            case RDMPEGFrameTypeArtwork: {
#if defined(RD_DEBUG_MPEG_PLAYER)
                log4Debug(@"Pushed artwork frame: %f %f", frame.position, frame.duration);
#endif // RD_DEBUG_MPEG_PLAYER
                
                self.artworkFrame = (RDMPEGArtworkFrame *)frame;
                break;
            }
        }
    }
}

- (nullable RDMPEGVideoFrame *)popVideoFrame {
    @synchronized (self.videoFrames) {
        RDMPEGVideoFrame *videoFrame = self.videoFrames.firstObject;
        
        if (videoFrame == nil) {
            return nil;
        }
        
        [self.videoFrames removeObjectAtIndex:0];
        
        return videoFrame;
    }
}

- (nullable RDMPEGAudioFrame *)popAudioFrame {
    @synchronized (self.audioFrames) {
        RDMPEGAudioFrame *audioFrame = self.audioFrames.firstObject;
        
        if (audioFrame == nil) {
            return nil;
        }
        
        [self.audioFrames removeObjectAtIndex:0];
        
        return audioFrame;
    }
}

- (nullable RDMPEGSubtitleFrame *)popSubtitleFrame {
    @synchronized (self.subtitleFrames) {
        RDMPEGSubtitleFrame *subtitleFrame = self.subtitleFrames.firstObject;
        
        if (subtitleFrame == nil) {
            return nil;
        }
        
        [self.subtitleFrames removeObjectAtIndex:0];
        
        return subtitleFrame;
    }
}

- (void)atomicVideoFramesAccess:(void (^)())accessBlock {
    if (accessBlock) {
        @synchronized (self.videoFrames) {
            accessBlock();
        }
    }
}

- (void)atomicAudioFramesAccess:(void (^)())accessBlock {
    if (accessBlock) {
        @synchronized (self.audioFrames) {
            accessBlock();
        }
    }
}

- (void)atomicSubtitleFramesAccess:(void (^)())accessBlock {
    if (accessBlock) {
        @synchronized (self.subtitleFrames) {
            accessBlock();
        }
    }
}

- (void)purge {
    [self purgeVideoFrames];
    [self purgeAudioFrames];
    [self purgeSubtitleFrames];
    [self purgeArtworkFrame];
}

- (void)purgeVideoFrames {
    @synchronized (self.videoFrames) {
        [self.videoFrames removeAllObjects];
    }
}

- (void)purgeAudioFrames {
    @synchronized (self.audioFrames) {
        [self.audioFrames removeAllObjects];
    }
}

- (void)purgeSubtitleFrames {
    @synchronized (self.subtitleFrames) {
        [self.subtitleFrames removeAllObjects];
    }
}

- (void)purgeArtworkFrame {
    self.artworkFrame = nil;
}

@end

NS_ASSUME_NONNULL_END
