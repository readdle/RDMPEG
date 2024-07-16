//
//  RDMPEGDecoder.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RDMPEG/RDMPEG-Swift.h>

@protocol RDMPEGIOStream;
@class RDMPEGStream;



NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const RDMPEGDecoderErrorDomain;

typedef NS_ENUM(NSUInteger, RDMPEGDecoderErrorCode) {
    RDMPEGDecoderErrorCodeOpenFile,
    RDMPEGDecoderErrorCodeStreamInfoNotFound,
    RDMPEGDecoderErrorCodeStreamNotFound,
    RDMPEGDecoderErrorCodeCodecNotFound,
    RDMPEGDecoderErrorCodeOpenCodec,
    RDMPEGDecoderErrorCodeAllocateFrame,
    RDMPEGDecoderErrorCodeSampler,
    RDMPEGDecoderErrorCodeUnsupported
};



typedef BOOL (^RDMPEGDecoderInterruptCallback)(void);



@interface RDMPEGDecoder : NSObject

@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) int64_t ffmpegDuration;
@property (nonatomic, readonly) NSUInteger frameWidth;
@property (nonatomic, readonly) NSUInteger frameHeight;
@property (nonatomic, readonly) RDMPEGVideoFrameFormat actualVideoFrameFormat;
@property (nonatomic, readonly) NSMutableArray<RDMPEGStream *> *videoStreams;
@property (nonatomic, readonly) NSMutableArray<RDMPEGStream *> *audioStreams;
@property (nonatomic, readonly) NSMutableArray<RDMPEGStream *> *subtitleStreams;
@property (nonatomic, readonly) NSMutableArray<RDMPEGStream *> *artworkStreams;
@property (nonatomic, readonly, nullable) NSNumber *activeAudioStreamIndex;
@property (nonatomic, readonly, nullable) NSNumber *activeSubtitleStreamIndex;
@property (nonatomic, readonly, getter=isOpened) BOOL opened;
@property (nonatomic, readonly, getter=isEndReached) BOOL endReached;
@property (nonatomic, readonly, getter=isVideoStreamExist) BOOL videoStreamExist;
@property (nonatomic, readonly, getter=isAudioStreamExist) BOOL audioStreamExist;
@property (nonatomic, readonly, getter=isSubtitleStreamExist) BOOL subtitleStreamExist;
@property (nonatomic, assign, getter=isDeinterlacingEnabled) BOOL deinterlacingEnabled;

- (instancetype)initWithPath:(NSString *)path
                    ioStream:(nullable id<RDMPEGIOStream>)ioStream
            subtitleEncoding:(nullable NSString *)subtitleEncoding
           interruptCallback:(nullable RDMPEGDecoderInterruptCallback)interruptCallback;

- (instancetype)initWithPath:(NSString *)path
                    ioStream:(nullable id<RDMPEGIOStream>)ioStream;

- (nullable NSError *)openInput;
- (nullable NSError *)loadVideoStreamWithPreferredVideoFrameFormat:(RDMPEGVideoFrameFormat)preferredVideoFrameFormat
                                            actualVideoFrameFormat:(RDMPEGVideoFrameFormat * _Nullable)actualVideoFrameFormat;
- (nullable NSError *)loadAudioStreamWithSamplingRate:(double)samplingRate
                                       outputChannels:(NSUInteger)outputChannels;
- (void)close;

- (void)moveAtPosition:(NSTimeInterval)position;
- (nullable NSArray<RDMPEGFrame *> *)decodeFrames;

- (BOOL)activateAudioStreamAtIndex:(nullable NSNumber *)audioStreamIndex
                      samplingRate:(double)samplingRate
                    outputChannels:(NSUInteger)outputChannels;
- (void)deactivateAudioStream;

- (BOOL)activateSubtitleStreamAtIndex:(nullable NSNumber *)subtitleStreamIndex;
- (void)deactivateSubtitleStream;

@end

NS_ASSUME_NONNULL_END
