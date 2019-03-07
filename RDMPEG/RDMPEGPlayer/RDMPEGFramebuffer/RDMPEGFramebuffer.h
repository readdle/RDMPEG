//
//  RDMPEGFramebuffer.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 8/17/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGFrames.h"



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGFramebuffer : NSObject

@property (atomic, readonly) NSTimeInterval bufferedVideoDuration;
@property (atomic, readonly) NSTimeInterval bufferedAudioDuration;
@property (atomic, readonly) NSTimeInterval bufferedSubtitleDuration;
@property (atomic, readonly) NSUInteger bufferedVideoFramesCount;
@property (atomic, readonly) NSUInteger bufferedAudioFramesCount;
@property (atomic, readonly) NSUInteger bufferedSubtitleFramesCount;
@property (atomic, readonly, nullable) RDMPEGVideoFrame *nextVideoFrame;
@property (atomic, readonly, nullable) RDMPEGAudioFrame *nextAudioFrame;
@property (atomic, readonly, nullable) RDMPEGSubtitleFrame *nextSubtitleFrame;
@property (atomic, readonly, nullable) RDMPEGArtworkFrame *artworkFrame;

- (void)pushFrames:(NSArray<RDMPEGFrame *> *)frames;

- (nullable RDMPEGVideoFrame *)popVideoFrame;
- (nullable RDMPEGAudioFrame *)popAudioFrame;
- (nullable RDMPEGSubtitleFrame *)popSubtitleFrame;

- (void)atomicVideoFramesAccess:(void (^)())accessBlock;
- (void)atomicAudioFramesAccess:(void (^)())accessBlock;
- (void)atomicSubtitleFramesAccess:(void (^)())accessBlock;

- (void)purge;
- (void)purgeVideoFrames;
- (void)purgeAudioFrames;
- (void)purgeSubtitleFrames;
- (void)purgeArtworkFrame;

@end

NS_ASSUME_NONNULL_END
