//
//  RDMPEGPlayer.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 8/17/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RDMPEGPlayer;
@class RDMPEGPlayerView;
@protocol RDMPEGIOStream;



NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, RDMPEGPlayerState) {
    RDMPEGPlayerStateStopped,
    RDMPEGPlayerStateFailed,
    RDMPEGPlayerStatePaused,
    RDMPEGPlayerStatePlaying
};



@protocol RDMPEGPlayerDelegate <NSObject>

- (void)mpegPlayerDidPrepareToPlay:(RDMPEGPlayer *)player;
- (void)mpegPlayer:(RDMPEGPlayer *)player didChangeState:(RDMPEGPlayerState)state;
- (void)mpegPlayer:(RDMPEGPlayer *)player didChangeBufferingState:(RDMPEGPlayerState)state;
- (void)mpegPlayer:(RDMPEGPlayer *)player didUpdateCurrentTime:(NSTimeInterval)currentTime;
- (void)mpegPlayerDidAttachInput:(RDMPEGPlayer *)player;
- (void)mpegPlayerDidFinishPlaying:(RDMPEGPlayer *)player;

@end



@interface RDMPEGPlayer : NSObject

@property (nonatomic, readonly) RDMPEGPlayerView *playerView;
@property (nonatomic, readonly) RDMPEGPlayerState state;
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly, nullable) NSArray<NSString *> *audioStreams;
@property (nonatomic, readonly, nullable) NSArray<NSString *> *subtitleStreams;
@property (nonatomic, readonly, nullable) NSNumber *activeAudioStreamIndex;
@property (nonatomic, readonly, nullable) NSNumber *activeSubtitleStreamIndex;
@property (nonatomic, readonly) NSTimeInterval currentTime;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly, getter=isBuffering) BOOL buffering;
@property (nonatomic, readonly, getter=isSeeking) BOOL seeking;
@property (nonatomic, assign) NSTimeInterval timeObservingInterval;
@property (nonatomic, assign, getter=isDeinterlacingEnabled) BOOL deinterlacingEnabled;
@property (nonatomic, weak) id<RDMPEGPlayerDelegate> delegate;

- (instancetype)initWithFilePath:(NSString *)filePath;
- (instancetype)initWithFilePath:(NSString *)filePath stream:(nullable id<RDMPEGIOStream>)stream;

- (void)attachInputWithFilePath:(NSString *)filePath
               subtitleEncoding:(nullable NSString *)subtitleEncoding
                         stream:(nullable id<RDMPEGIOStream>)stream;

- (void)play;
- (void)pause;

- (void)beginSeeking;
- (void)seekToTime:(NSTimeInterval)time;
- (void)endSeeking;

- (void)activateAudioStreamAtIndex:(nullable NSNumber *)streamIndex;
- (void)activateSubtitleStreamAtIndex:(nullable NSNumber *)streamIndex;

@end

NS_ASSUME_NONNULL_END
