//
//  RDMPEGPlayer.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 8/17/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGPlayer.h"
#import "RDMPEGPlayerView+Player.h"
#import "RDMPEGDecoder.h"
#import "RDMPEGIOStream.h"
#import "RDMPEGStream.h"
#import <Log4Cocoa/Log4Cocoa.h>

#import <RDMPEG/RDMPEG-Swift.h>

NS_ASSUME_NONNULL_BEGIN

static const NSTimeInterval RDMPEGPlayerMinVideoBufferSize = 0.2;
static const NSTimeInterval RDMPEGPlayerMaxVideoBufferSize = 1.0;
static const NSTimeInterval RDMPEGPlayerMinAudioBufferSize = 0.2;

static NSString * const RDMPEGPlayerInputDecoderKey = @"RDMPEGPlayerInputDecoderKey";
static NSString * const RDMPEGPlayerInputNameKey = @"RDMPEGPlayerInputNameKey";
static NSString * const RDMPEGPlayerInputAudioStreamsKey = @"RDMPEGPlayerInputAudioStreamsKey";
static NSString * const RDMPEGPlayerInputSubtitleStreamsKey = @"RDMPEGPlayerInputSubtitleStreamsKey";



@interface RDMPEGPlayer ()

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSOperationQueue *decodingQueue;
@property (nonatomic, strong) NSOperationQueue *externalInputsQueue;
@property (nonatomic, strong) RDMPEGFramebuffer *framebuffer;
@property (nonatomic, strong) RDMPEGPlayerView *playerView;
@property (nonatomic, strong) RDMPEGAudioRenderer *audioRenderer;
@property (nonatomic, strong, nullable) id<RDMPEGIOStream> stream;
@property (nonatomic, strong, nullable) RDMPEGDecoder *decoder;
@property (nonatomic, strong, nullable) RDMPEGDecoder *externalAudioDecoder;
@property (nonatomic, strong, nullable) RDMPEGDecoder *externalSubtitleDecoder;
@property (nonatomic, strong, nullable) NSMutableArray<NSDictionary<NSString *, id> *> *selectableInputs;
@property (nonatomic, strong, nullable) NSError *error;
@property (nonatomic, strong, nullable) RDMPEGRenderScheduler *scheduler;
@property (nonatomic, strong, nullable) NSTimer *timeObservingTimer;
@property (nonatomic, strong, nullable) NSArray<RDMPEGSelectableInputStream *> *audioStreams;
@property (nonatomic, strong, nullable) NSArray<RDMPEGSelectableInputStream *> *subtitleStreams;
@property (nonatomic, strong, nullable) NSNumber *activeAudioStreamIndex;
@property (nonatomic, strong, nullable) NSNumber *activeSubtitleStreamIndex;
@property (nonatomic, strong, nullable) NSMutableArray<RDMPEGSubtitleFrame *> *currentSubtitleFrames;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign, getter=isBuffering) BOOL buffering;
@property (nonatomic, assign, getter=isSeeking) BOOL seeking;
@property (nonatomic, assign, getter=isPlayingBeforeSeek) BOOL playingBeforeSeek;
@property (atomic, strong, nullable) RDMPEGRawAudioFrame *rawAudioFrame;
@property (atomic, strong, nullable) RDMPEGCorrectionInfo *correctionInfo;
@property (atomic, weak, nullable) NSOperation *decodingOperation;
@property (atomic, weak, nullable) NSOperation *seekOperation;
@property (atomic, assign) RDMPEGPlayerState internalState;
@property (atomic, assign) NSTimeInterval currentInternalTime;
@property (atomic, assign, getter=isPreparedToPlay) BOOL preparedToPlay;
@property (atomic, assign, getter=isDecodingFinished) BOOL decodingFinished;
@property (atomic, assign, getter=isVideoStreamExist) BOOL videoStreamExist;
@property (atomic, assign, getter=isAudioStreamExist) BOOL audioStreamExist;
@property (atomic, assign, getter=isSubtitleStreamExist) BOOL subtitleStreamExist;
@property (atomic, readonly, getter=isVideoBufferReady) BOOL videoBufferReady;
@property (atomic, readonly, getter=isAudioBufferReady) BOOL audioBufferReady;
@property (atomic, readonly, getter=isSubtitleBufferReady) BOOL subtitleBufferReady;

@end



@implementation RDMPEGPlayer

#pragma mark - Overridden Class Methods

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGPlayer"];
}

#pragma mark - Lifecycle

- (instancetype)initWithFilePath:(NSString *)filePath {
    return [self initWithFilePath:filePath stream:nil];
}

- (instancetype)initWithFilePath:(NSString *)filePath stream:(nullable id<RDMPEGIOStream>)stream {
    self = [super init];
    if (self) {
        self.filePath = filePath;
        self.stream = stream;
        
        self.decodingQueue = [[NSOperationQueue alloc] init];
        self.decodingQueue.name = @"RDMPEGPlayer Decoding Queue";
        self.decodingQueue.maxConcurrentOperationCount = 1;
        
        self.externalInputsQueue = [[NSOperationQueue alloc] init];
        self.externalInputsQueue.name = @"RDMPEGPlayer External Inputs Queue";
        self.externalInputsQueue.maxConcurrentOperationCount = 1;
        
        self.framebuffer = [[RDMPEGFramebuffer alloc] init];
        self.playerView = [[RDMPEGPlayerView alloc] init];
        self.audioRenderer = [[RDMPEGAudioRenderer alloc] init];
        self.selectableInputs = [NSMutableArray array];
        
        self.timeObservingInterval = 1.0;
        
        self.currentSubtitleFrames = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [self stopScheduler];
    [self setAudioOutputEnabled:NO];
    [self stopTimeObservingTimer];
    
    [self.decodingQueue cancelAllOperations];
    [self.externalInputsQueue cancelAllOperations];
}

#pragma mark - Public Accessors

- (RDMPEGPlayerState)state {
    return self.internalState;
}

- (NSTimeInterval)currentTime {
    return self.currentInternalTime;
}

- (void)setTimeObservingInterval:(NSTimeInterval)timeObservingInterval {
    if (_timeObservingInterval == timeObservingInterval) {
        return;
    }
    
    _timeObservingInterval = timeObservingInterval;
    
    if (self.timeObservingTimer) {
        [self stopTimeObservingTimer];
        [self startTimeObservingTimer];
    }
}

- (void)setDeinterlacingEnabled:(BOOL)deinterlacingEnabled {
    if (_deinterlacingEnabled == deinterlacingEnabled) {
        return;
    }
    
    _deinterlacingEnabled = deinterlacingEnabled;
    
    __weak __typeof(self) weakSelf = self;
    
    [self.decodingQueue addOperationWithBlock:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        strongSelf.decoder.deinterlacingEnabled = deinterlacingEnabled;
    }];
}

#pragma mark - Private Accessors

- (BOOL)isVideoBufferReady {
    log4Assert([NSOperationQueue currentQueue] == self.decodingQueue, @"Method '%@' called from wrong queue", NSStringFromSelector(_cmd));
    
    if (self.decoder.isVideoStreamExist == NO || self.decoder.isEndReached) {
        return YES;
    }
    
    return (self.framebuffer.bufferedVideoDuration > RDMPEGPlayerMinVideoBufferSize);
}

- (BOOL)isAudioBufferReady {
    log4Assert([NSOperationQueue currentQueue] == self.decodingQueue, @"Method '%@' called from wrong queue", NSStringFromSelector(_cmd));
    
    if (self.decoder.isVideoStreamExist) {
        if (nil != self.decoder.activeAudioStreamIndex) {
            log4Assert(self.externalAudioDecoder == nil, @"External audio decoder should be nil when main audio stream activated");
            
            if (self.decoder.isEndReached) {
                return YES;
            }
            
            if (self.framebuffer.bufferedAudioDuration > RDMPEGPlayerMinAudioBufferSize) {
                return YES;
            }
            
            if (self.framebuffer.bufferedVideoDuration >= RDMPEGPlayerMaxVideoBufferSize) {
                return YES;
            }
            
            return NO;
        }
        else if (nil != self.externalAudioDecoder.activeAudioStreamIndex) {
            if (self.externalAudioDecoder.isEndReached) {
                return YES;
            }
            
            if (self.framebuffer.bufferedAudioDuration > RDMPEGPlayerMinAudioBufferSize) {
                return YES;
            }
            
            return NO;
        }
        else {
            return YES;
        }
    }
    else {
        if (self.decoder.isAudioStreamExist == NO || self.decoder.isEndReached) {
            return YES;
        }
        
        return (self.framebuffer.bufferedAudioDuration > RDMPEGPlayerMinAudioBufferSize);
    }
}

- (BOOL)isSubtitleBufferReady {
    log4Assert([NSOperationQueue currentQueue] == self.decodingQueue, @"Method '%@' called from wrong queue", NSStringFromSelector(_cmd));
    
    if (self.decoder.isVideoStreamExist) {
        if (nil != self.decoder.activeSubtitleStreamIndex) {
            log4Assert(self.externalSubtitleDecoder == nil, @"External subtitle decoder should be nil when main subtitle stream activated");
            
            if (self.decoder.isEndReached) {
                return YES;
            }
            
            if (self.framebuffer.bufferedVideoDuration >= RDMPEGPlayerMaxVideoBufferSize) {
                return YES;
            }
            
            return self.framebuffer.bufferedSubtitleFramesCount > 0;
        }
        else if (nil != self.externalSubtitleDecoder.activeSubtitleStreamIndex) {
            if (self.externalSubtitleDecoder.isEndReached) {
                return YES;
            }
            
            if (self.framebuffer.bufferedVideoDuration >= RDMPEGPlayerMaxVideoBufferSize) {
                return YES;
            }
            
            return self.framebuffer.bufferedSubtitleFramesCount > 0;
        }
        else {
            return YES;
        }
    }
    else {
        return YES;
    }
}

#pragma mark - Public Methods

- (void)attachInputWithFilePath:(NSString *)filePath
               subtitleEncoding:(nullable NSString *)subtitleEncoding
                         stream:(nullable id<RDMPEGIOStream>)stream {
    log4BlocksLoggingScope
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    __weak __typeof(self) weakSelf = self;

    [self prepareToPlayIfNeededWithSuccesCallback:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        if (strongSelf.isVideoStreamExist == NO) {
            log4BlockInfo(@"Ignoring external input since video stream doesn't exist");
            return;
        }
        
        [strongSelf.externalInputsQueue addOperationWithBlock:^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            
            RDMPEGDecoder *decoder = [[RDMPEGDecoder alloc] initWithPath:filePath
                                                                ioStream:stream
                                                        subtitleEncoding:subtitleEncoding
                                                       interruptCallback:^BOOL{
                                                           __strong __typeof(weakSelf) strongSelf = weakSelf;
                                                           return (strongSelf == nil);
                                                       }];
            
            NSError *openInputError = [decoder openInput];
            
            if (openInputError == nil) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    NSString *inputFileName = [decoder.path.lastPathComponent stringByDeletingPathExtension];
                    [strongSelf registerSelectableInputFromDecoderIfNeeded:decoder inputName:inputFileName];
                });
            }
        }];
    }];
}

- (void)play {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    __weak __typeof(self) weakSelf = self;
    
    [self prepareToPlayIfNeededWithSuccesCallback:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        if (strongSelf.internalState != RDMPEGPlayerStatePlaying) {
            if (strongSelf.activeAudioStreamIndex != nil) {
                [strongSelf setAudioOutputEnabled:YES];
            }
            [strongSelf startScheduler];
            [strongSelf updateStateIfNeededAndNotify:RDMPEGPlayerStatePlaying error:nil];
        }
    }];
}

- (void)pause {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    __weak __typeof(self) weakSelf = self;
    
    [self prepareToPlayIfNeededWithSuccesCallback:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        if (strongSelf.internalState != RDMPEGPlayerStatePlaying) {
            return;
        }
        
        [strongSelf setAudioOutputEnabled:NO];
        [strongSelf stopScheduler];
        
        [strongSelf.decodingOperation cancel];
        strongSelf.correctionInfo = nil;
        strongSelf.rawAudioFrame = nil;
        
        [strongSelf setBufferingStateIfNeededAndNotify:NO];
        [strongSelf updateStateIfNeededAndNotify:RDMPEGPlayerStatePaused error:nil];
    }];
}

- (void)beginSeeking {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    if (self.isSeeking == NO) {
        self.seeking = YES;
        
        if (self.internalState == RDMPEGPlayerStatePlaying) {
            self.playingBeforeSeek = YES;
            [self pause];
        }
    }
}

- (void)seekToTime:(NSTimeInterval)time {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    __weak __typeof(self) weakSelf = self;
    
    [self prepareToPlayIfNeededWithSuccesCallback:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf.decodingOperation cancel];
        [strongSelf.seekOperation cancel];
        
        NSBlockOperation *seekOperation = [[NSBlockOperation alloc] init];
        __weak typeof(seekOperation) weakSeekOperation = seekOperation;
        
        [seekOperation addExecutionBlock:^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            __strong __typeof(weakSeekOperation) strongSeekOperation = weakSeekOperation;
            
            if (strongSelf == nil || strongSeekOperation == nil) {
                return;
            }
            
            [strongSelf.framebuffer purge];
            strongSelf.rawAudioFrame = nil;
            
            [strongSelf moveDecodersToTime:time includingMainDecoder:YES];
            
            strongSelf.decodingFinished = strongSelf.decoder.isEndReached;
            
            [strongSelf decodeFrames];
            
            if (strongSelf.isVideoStreamExist) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    if (strongSelf.seekOperation && strongSelf.seekOperation != strongSeekOperation) {
                        return;
                    }
                    
                    [strongSelf showNextVideoFrame];
                    
                    [strongSelf.delegate mpegPlayer:strongSelf didUpdateCurrentTime:strongSelf.currentInternalTime];
                });
            }
        }];
        seekOperation.name = @"Seek Operation";
        
        strongSelf.seekOperation = seekOperation;
        [strongSelf.decodingQueue addOperation:seekOperation];
    }];
}

- (void)endSeeking {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    if (self.isSeeking) {
        self.seeking = NO;
        
        if (self.isPlayingBeforeSeek) {
            self.playingBeforeSeek = NO;
            [self play];
        }
    }
}

- (nullable RDMPEGDecoder *)decoderForStreamAtIndex:(NSNumber *)streamIndex
                                         streamsKey:(NSString *)streamsKey
                                 decoderStreamIndex:(NSNumber * _Nullable * _Nullable)decoderStreamIndex {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    NSUInteger currentStreamIndex = 0;
    for (NSDictionary<NSString *, id> *selectableInput in self.selectableInputs) {
        NSArray<NSString *> *streams = selectableInput[streamsKey];
        
        for (NSUInteger i = 0; i < streams.count; i++) {
            if (streamIndex.integerValue == currentStreamIndex) {
                if (decoderStreamIndex) {
                    *decoderStreamIndex = @(i);
                }
                
                return selectableInput[RDMPEGPlayerInputDecoderKey];
            }
            
            currentStreamIndex++;
        }
    }
    
    log4Assert(NO, @"Trying to access non-existent stream");
    return nil;
}

- (void)activateAudioStreamAtIndex:(nullable NSNumber *)streamIndex {
    if (self.isPreparedToPlay == NO) {
        return;
    }
    
    if ((self.activeAudioStreamIndex == nil && streamIndex == nil) ||
        (streamIndex && [self.activeAudioStreamIndex isEqualToNumber:streamIndex])) {
        return;
    }
    
    self.activeAudioStreamIndex = streamIndex;
    
    RDMPEGDecoder *decoder = nil;
    NSNumber *decoderStreamToActivate = nil;
    
    if (nil != streamIndex) {
        decoder = [self decoderForStreamAtIndex:streamIndex streamsKey:RDMPEGPlayerInputAudioStreamsKey decoderStreamIndex:&decoderStreamToActivate];
    }
    
    double samplingRate = self.audioRenderer.samplingRate;
    NSUInteger outputChannelsCount = self.audioRenderer.outputChannelsCount;
    
    __weak __typeof(self) weakSelf = self;
    
    [self.decodingQueue addOperationWithBlock:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf.framebuffer purge];
        strongSelf.rawAudioFrame = nil;
        
        if (strongSelf.externalAudioDecoder && strongSelf.externalAudioDecoder != decoder) {
            [strongSelf.externalAudioDecoder deactivateAudioStream];
            strongSelf.externalAudioDecoder = nil;
        }
        
        if (strongSelf.decoder == decoder) {
            [strongSelf.decoder activateAudioStreamAtIndex:decoderStreamToActivate samplingRate:samplingRate outputChannels:outputChannelsCount];
        }
        else {
            [strongSelf.decoder deactivateAudioStream];
            
            strongSelf.externalAudioDecoder = decoder;
            [strongSelf.externalAudioDecoder activateAudioStreamAtIndex:decoderStreamToActivate samplingRate:samplingRate outputChannels:outputChannelsCount];
            
            [strongSelf moveDecodersToTime:strongSelf.currentInternalTime includingMainDecoder:NO];
        }
    }];
}

- (void)activateSubtitleStreamAtIndex:(nullable NSNumber *)streamIndex {
    if (self.isPreparedToPlay == NO) {
        return;
    }
    
    if ((self.activeSubtitleStreamIndex == nil && streamIndex == nil) ||
        (streamIndex && [self.activeSubtitleStreamIndex isEqualToNumber:streamIndex])) {
        return;
    }
    
    self.activeSubtitleStreamIndex = streamIndex;
    
    RDMPEGDecoder *decoder = nil;
    NSNumber *decoderStreamToActivate = nil;
    
    if (nil != streamIndex) {
        decoder = [self decoderForStreamAtIndex:streamIndex streamsKey:RDMPEGPlayerInputSubtitleStreamsKey decoderStreamIndex:&decoderStreamToActivate];
    }
    
    __weak __typeof(self) weakSelf = self;
    
    [self.decodingQueue addOperationWithBlock:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf.framebuffer purge];
        
        if (strongSelf.externalSubtitleDecoder && strongSelf.externalSubtitleDecoder != decoder) {
            [strongSelf.externalSubtitleDecoder deactivateSubtitleStream];
            strongSelf.externalSubtitleDecoder = nil;
        }
        
        if (strongSelf.decoder == decoder) {
            [strongSelf.decoder activateSubtitleStreamAtIndex:decoderStreamToActivate];
        }
        else {
            [strongSelf.decoder deactivateSubtitleStream];
            
            strongSelf.externalSubtitleDecoder = decoder;
            [strongSelf.externalSubtitleDecoder activateSubtitleStreamAtIndex:decoderStreamToActivate];
            
            [strongSelf moveDecodersToTime:strongSelf.currentInternalTime includingMainDecoder:NO];
        }
    }];
}

#pragma mark - Private Methods

#pragma mark Player State

- (void)updateStateIfNeededAndNotify:(RDMPEGPlayerState)state error:(nullable NSError *)error {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    if (self.internalState == state) {
        return;
    }
    
    self.internalState = state;
    self.error = (self.internalState == RDMPEGPlayerStateFailed) ? error : nil;
    
    if (self.internalState == RDMPEGPlayerStatePlaying) {
        [self startTimeObservingTimer];
    }
    else {
        [self stopTimeObservingTimer];
    }
    
    [self.delegate mpegPlayer:self didChangeState:self.internalState];
}

- (void)finishPlaying {
    [self pause];
    
    self.currentInternalTime = self.duration;
    
    [self.delegate mpegPlayer:self didUpdateCurrentTime:self.currentInternalTime];
    [self.delegate mpegPlayerDidFinishPlaying:self];
}

#pragma mark Inputs

- (void)registerSelectableInputFromDecoderIfNeeded:(RDMPEGDecoder *)decoder inputName:(nullable NSString *)inputName {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    if (decoder.audioStreams.count == 0 && decoder.subtitleStreams.count == 0) {
        return;
    }
    
    NSMutableArray<NSString *> *audioStreamNames = [NSMutableArray array];
    NSMutableArray<NSString *> *subtitleStreamNames = [NSMutableArray array];
    
    for (RDMPEGStream *stream in decoder.audioStreams) {
        NSString *audioStream = [self streamNameForStream:stream inputName:inputName];
        [audioStreamNames addObject:audioStream];
    }
    
    for (RDMPEGStream *stream in decoder.subtitleStreams) {
        NSString *subtitleStream = [self streamNameForStream:stream inputName:inputName];
        [subtitleStreamNames addObject:subtitleStream];
    }
    
    NSMutableDictionary<NSString *, id> *selectableInput = [NSMutableDictionary dictionary];
    selectableInput[RDMPEGPlayerInputDecoderKey] = decoder;
    if(inputName){
        selectableInput[RDMPEGPlayerInputNameKey] = inputName;
    }
    selectableInput[RDMPEGPlayerInputAudioStreamsKey] = audioStreamNames.count > 0 ? audioStreamNames : nil;
    selectableInput[RDMPEGPlayerInputSubtitleStreamsKey] = subtitleStreamNames.count > 0 ? subtitleStreamNames : nil;
    [self.selectableInputs addObject:selectableInput];
    
    NSMutableArray<RDMPEGSelectableInputStream *> *allAudioStreams = [NSMutableArray<RDMPEGSelectableInputStream *> array];
    NSMutableArray<RDMPEGSelectableInputStream *> *allSubtitleStreams = [NSMutableArray<RDMPEGSelectableInputStream *> array];
    
    for (NSMutableDictionary<NSString *, id> *selectableInput in self.selectableInputs) {
        NSArray<NSString *> *audioStreams = selectableInput[RDMPEGPlayerInputAudioStreamsKey];
        NSArray<NSString *> *subtitleStreams = selectableInput[RDMPEGPlayerInputSubtitleStreamsKey];
        NSString *inputName = selectableInput[RDMPEGPlayerInputNameKey];
        
        for (NSString *audioStreamName in audioStreams) {
            RDMPEGSelectableInputStream *selectableStream = [RDMPEGSelectableInputStream new];
            selectableStream.title = audioStreamName;
            selectableStream.inputName = inputName;
            [allAudioStreams addObject:selectableStream];
        }
        
        for (NSString *subtitleStreamName in subtitleStreams) {
            RDMPEGSelectableInputStream *selectableStream = [RDMPEGSelectableInputStream new];
            selectableStream.title = subtitleStreamName;
            selectableStream.inputName = inputName;
            [allSubtitleStreams addObject:selectableStream];
        }
    }
    
    self.audioStreams = allAudioStreams;
    self.subtitleStreams = allSubtitleStreams;
    
    [self.delegate mpegPlayerDidAttachInput:self];
}

- (NSString *)streamNameForStream:(RDMPEGStream *)stream inputName:(nullable NSString *)inputName {
    NSMutableString *streamName = [NSMutableString string];
    
    if (inputName) {
        [streamName appendFormat:@"[%@] - ", inputName];
    }
    
    if (stream.isCanBeDecoded) {
        if (stream.languageCode) {
            NSString *language = [[NSLocale currentLocale] localizedStringForLanguageCode:stream.languageCode];
            if (language.length > 0) {
                NSString *firstLetter = [language substringToIndex:1];
                NSString *foldedFirstLetter = [firstLetter stringByFoldingWithOptions:NSDiacriticInsensitiveSearch
                                                                               locale:[NSLocale currentLocale]];
                language = [[foldedFirstLetter uppercaseString] stringByAppendingString:[language substringFromIndex:1]];
            }
            
            [streamName appendString:(language ?: stream.languageCode)];
            
            if (stream.info) {
                [streamName appendString:@", "];
            }
        }
        
        if (stream.info) {
            [streamName appendString:stream.info];
        }
    }
    else {
        [streamName appendString:NSLocalizedString(@"Unsupported", @"Stream which we're unable to decode")];
    }
    
    return streamName;
}

#pragma mark Decoding

- (void)prepareToPlayIfNeededWithSuccesCallback:(void (^)())successCallback {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    if (self.isPreparedToPlay) {
        if (successCallback) {
            successCallback();
        }
        return;
    }
    
    if (self.internalState == RDMPEGPlayerStateFailed) {
        return;
    }
    
    double samplingRate = self.audioRenderer.samplingRate;
    NSUInteger outputChannelsCount = self.audioRenderer.outputChannelsCount;
    
    NSBlockOperation *prepareOperation = [[NSBlockOperation alloc] init];
    prepareOperation.name = @"Prepare Operation";
    
    __weak __typeof(self) weakSelf = self;
    __weak __typeof(prepareOperation) weakPrepareOperation = prepareOperation;
    
    [prepareOperation addExecutionBlock:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        if (strongSelf.internalState == RDMPEGPlayerStateFailed) {
            return;
        }
        
        BOOL preparedToPlay = strongSelf.isPreparedToPlay;
        BOOL justPreparedToPlay = NO;
        NSError *prepareError = nil;
        
        if (preparedToPlay == NO) {
            preparedToPlay = [strongSelf prepareToPlayWithAudioSamplingRate:samplingRate outputChannelsCount:outputChannelsCount error:&prepareError];
            
            if (preparedToPlay) {
                justPreparedToPlay = YES;
            }
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            __strong __typeof(weakPrepareOperation) strongPrepareOperation = weakPrepareOperation;
            if (strongSelf == nil || strongPrepareOperation == nil) {
                return;
            }
            
            if (preparedToPlay) {
                if (justPreparedToPlay) {
                    strongSelf.preparedToPlay = YES;
                    strongSelf.duration = strongSelf.decoder.duration;
                    
                    strongSelf.decoder.deinterlacingEnabled = strongSelf.isDeinterlacingEnabled;
                    
                    id<RDMPEGTextureSampler> textureSampler = nil;
                    if (strongSelf.decoder.actualVideoFrameFormat == RDMPEGVideoFrameFormatYUV) {
                        textureSampler = [[RDMPEGTextureSamplerYUV alloc] init];
                    }
                    else {
                        textureSampler = [[RDMPEGTextureSamplerBGRA alloc] init];
                    }
                    
                    strongSelf.playerView.renderView =
                    [[RDMPEGRenderView alloc]
                     initWithFrame:strongSelf.playerView.bounds
                     textureSampler:textureSampler
                     frameWidth:strongSelf.decoder.frameWidth
                     frameHeight:strongSelf.decoder.frameHeight];
                    
                    strongSelf.videoStreamExist = strongSelf.decoder.isVideoStreamExist;
                    strongSelf.audioStreamExist = strongSelf.decoder.isAudioStreamExist;
                    strongSelf.subtitleStreamExist = strongSelf.decoder.isSubtitleStreamExist;
                    
                    [strongSelf registerSelectableInputFromDecoderIfNeeded:strongSelf.decoder inputName:nil];
                    
                    strongSelf.activeAudioStreamIndex = strongSelf.decoder.activeAudioStreamIndex;
                    strongSelf.activeSubtitleStreamIndex = strongSelf.decoder.activeSubtitleStreamIndex;
                    
                    [strongSelf.delegate mpegPlayerDidPrepareToPlay:strongSelf];
                }
                
                if (strongPrepareOperation.isCancelled == NO) {
                    if (successCallback) {
                        successCallback();
                    }
                }
            }
            else {
                if (strongPrepareOperation.isCancelled == NO) {
                    [strongSelf updateStateIfNeededAndNotify:RDMPEGPlayerStateFailed error:prepareError];
                }
            }
        });
    }];
    
    [self.decodingQueue addOperation:prepareOperation];
}

- (BOOL)prepareToPlayWithAudioSamplingRate:(double)samplingRate outputChannelsCount:(NSUInteger)outputChannelsCount error:(NSError * _Nullable * _Nullable)error {
    log4Assert([NSOperationQueue currentQueue] == self.decodingQueue, @"Method '%@' called from wrong queue", NSStringFromSelector(_cmd));
    log4Assert(samplingRate > 0 && outputChannelsCount > 0, @"Incorrect audio parameters");
    
    if (self.isPreparedToPlay) {
        return YES;
    }
    
    __weak __typeof(self) weakSelf = self;
    
    RDMPEGDecoder *decoder = [[RDMPEGDecoder alloc] initWithPath:self.filePath
                                                        ioStream:self.stream
                                                subtitleEncoding:nil
                                               interruptCallback:^BOOL{
                                                   __strong __typeof(weakSelf) strongSelf = weakSelf;
                                                   return (strongSelf == nil);
                                               }];
    
    NSError *openInputError = [decoder openInput];
    if (openInputError) {
        if (error) {
            *error = openInputError;
        }
        return NO;
    }
    
    NSError *videoError = [decoder loadVideoStreamWithPreferredVideoFrameFormat:RDMPEGVideoFrameFormatYUV actualVideoFrameFormat:nil];
    NSError *audioError = [decoder loadAudioStreamWithSamplingRate:samplingRate outputChannels:outputChannelsCount];
    
    if (videoError == nil || audioError == nil) {
        self.decoder = decoder;
        return YES;
    }
    
    if (error) {
        *error = videoError;
    }
    
    log4Assert(NO, @"Decoder should contain valid video and/or valid audio");
    return NO;
}

- (void)decodeFrames {
    log4Assert([NSOperationQueue currentQueue] == self.decodingQueue, @"Method '%@' called from wrong queue", NSStringFromSelector(_cmd));
    
    if (self.isPreparedToPlay == NO) {
        log4Assert(NO, @"Player should be prepared to play before attempting to decode");
        return;
    }
    
    if (self.decoder.isVideoStreamExist == NO && self.decoder.isAudioStreamExist == NO) {
        log4Assert(NO, @"Why we're trying to decode invalid video");
        return;
    }
    
    if (self.decoder.isEndReached) {
        log4Assert(self.isDecodingFinished, @"This properties expected to be synchronized");
        self.decodingFinished = YES;
        return;
    }
    
    @autoreleasepool {
        NSArray<RDMPEGFrame *> *frames = [self.decoder decodeFrames];
        if (frames) {
            [self.framebuffer pushFrames:frames];
        }
    }
    
    self.decodingFinished = self.decoder.isEndReached;
}

- (void)decodeExternalAudioFrames {
    if (self.externalAudioDecoder == nil) {
        log4Assert(NO, @"External audio decoder isn't selected");
        return;
    }
    
    while (YES) {
        if (self.externalAudioDecoder.isEndReached) {
            break;
        }
        
        @autoreleasepool {
            NSArray<RDMPEGFrame *> *audioFrames = [self.externalAudioDecoder decodeFrames];
            
            NSMutableArray<RDMPEGFrame *> *filteredAudioFrames = [NSMutableArray array];
            for (RDMPEGFrame *frame in audioFrames) {
                if ([frame isKindOfClass:[RDMPEGAudioFrame class]]) {
                    [filteredAudioFrames addObject:frame];
                }
                else {
                    log4Assert(NO, @"Unexpected frame deteted");
                }
            }
            
            if (filteredAudioFrames.count > 0) {
                [self.framebuffer pushFrames:filteredAudioFrames];
                
                RDMPEGAudioFrame *nextAudioFrame = self.framebuffer.nextAudioFrame;
                
                NSTimeInterval externalAudioBufferOverrun = nextAudioFrame.position + self.framebuffer.bufferedAudioDuration - self.currentInternalTime;
                if (externalAudioBufferOverrun > RDMPEGPlayerMinAudioBufferSize) {
                    break;
                }
            }
        }
    }
}

- (void)decodeExternalSubtitleFrames {
    if (self.externalSubtitleDecoder == nil) {
        log4Assert(NO, @"External subtitle decoder isn't selected");
        return;
    }
    
    while (YES) {
        if (self.externalSubtitleDecoder.isEndReached) {
            break;
        }
        
        @autoreleasepool {
            NSArray<RDMPEGFrame *> *subtitleFrames = [self.externalSubtitleDecoder decodeFrames];
            
            NSMutableArray<RDMPEGFrame *> *filteredSubtitleFrames = [NSMutableArray array];
            for (RDMPEGFrame *frame in subtitleFrames) {
                if ([frame isKindOfClass:[RDMPEGSubtitleFrame class]]) {
                    [filteredSubtitleFrames addObject:frame];
                }
                else {
                    log4Assert(NO, @"Unexpected frame deteted");
                }
            }
            
            if (subtitleFrames.count > 0) {
                [self.framebuffer pushFrames:filteredSubtitleFrames];
                
                RDMPEGSubtitleFrame *nextSubtitleFrame = self.framebuffer.nextSubtitleFrame;
                
                NSTimeInterval externalSubtitleBufferOverrun = nextSubtitleFrame.position + self.framebuffer.bufferedSubtitleDuration - self.currentInternalTime;
                if (externalSubtitleBufferOverrun > 0.0) {
                    break;
                }
            }
        }
    }
}

- (void)asyncDecodeFramesIfNeeded {
    if (self.decodingOperation != nil && self.decodingOperation.isCancelled == NO) {
        return;
    }
    
    NSBlockOperation *decodingOperation = [[NSBlockOperation alloc] init];
    decodingOperation.name = @"Decoding Operation";
    
    __weak __typeof(self) weakSelf = self;
    __weak __typeof(decodingOperation) weakDecodingOperation = decodingOperation;
    
    [decodingOperation addExecutionBlock:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        __strong __typeof(weakDecodingOperation) strongDecodingOperation = weakDecodingOperation;
        if (strongSelf == nil || strongDecodingOperation == nil) {
            return;
        }
        
        while (strongDecodingOperation.isCancelled == NO) {
            if (strongSelf.isVideoBufferReady && strongSelf.isAudioBufferReady && strongSelf.isSubtitleBufferReady) {
                break;
            }
            
            if (strongSelf.isVideoBufferReady == NO) {
                [strongSelf decodeFrames];
            }
            
            if (strongSelf.isAudioBufferReady == NO) {
                if (nil != strongSelf.decoder.activeAudioStreamIndex) {
                    [strongSelf decodeFrames];
                }
                else if (nil != strongSelf.externalAudioDecoder.activeAudioStreamIndex) {
                    [strongSelf decodeExternalAudioFrames];
                }
            }
            
            if (strongSelf.isSubtitleBufferReady == NO) {
                if (nil != strongSelf.decoder.activeSubtitleStreamIndex) {
                    [strongSelf decodeFrames];
                }
                else if (nil != strongSelf.externalSubtitleDecoder.activeSubtitleStreamIndex) {
                    [strongSelf decodeExternalSubtitleFrames];
                }
            }
        }
    }];
    
    self.decodingOperation = decodingOperation;
    [self.decodingQueue addOperation:self.decodingOperation];
}

- (void)moveDecodersToTime:(NSTimeInterval)time includingMainDecoder:(BOOL)moveMainDecoder {
    if (moveMainDecoder) {
        NSTimeInterval clippedTime = MIN(self.decoder.duration, MAX(0.0, time));
        [self.decoder moveAtPosition:clippedTime];
    }
    
    if (self.externalAudioDecoder) {
        NSTimeInterval clippedExternalAudioTime = MIN(self.externalAudioDecoder.duration, MAX(0.0, time));
        [self.externalAudioDecoder moveAtPosition:clippedExternalAudioTime];
    }
    
    if (self.externalSubtitleDecoder) {
        NSTimeInterval clippedExternalSubtitleTime = MIN(self.externalSubtitleDecoder.duration, MAX(0.0, time));
        [self.externalSubtitleDecoder moveAtPosition:clippedExternalSubtitleTime];
    }
}

#pragma mark Scheduling

- (void)startScheduler {
    if (self.scheduler.isScheduling) {
        log4Assert(NO, @"Video scheduler already started");
        return;
    }
    
    __weak __typeof(self) weakSelf = self;
    
    self.scheduler = [[RDMPEGRenderScheduler alloc] init];
    [self.scheduler startWith:^NSDate * _Nullable {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf.seekOperation) {
            return nil;
        }
        
        if (strongSelf.isVideoStreamExist) {
            RDMPEGVideoFrame *presentedFrame = [strongSelf showNextVideoFrame];
            
            if (presentedFrame == nil) {
                strongSelf.correctionInfo = nil;
                
                if (strongSelf.isDecodingFinished) {
                    [strongSelf finishPlaying];
                }
                else {
                    [strongSelf setBufferingStateIfNeededAndNotify:YES];
                    [strongSelf asyncDecodeFramesIfNeeded];
                }
                
                return nil;
            }
            
            if (strongSelf.correctionInfo == nil) {
                strongSelf.correctionInfo = [[RDMPEGCorrectionInfo alloc] initWithPlaybackStartDate:[NSDate date]
                                                                                  playbackStartTime:strongSelf.currentInternalTime];
                
                [strongSelf setBufferingStateIfNeededAndNotify:NO];
            }
            
            NSTimeInterval correctionInterval = [strongSelf.correctionInfo correctionIntervalWithCurrentTime:strongSelf.currentInternalTime];
            NSTimeInterval nextFrameInterval = presentedFrame.duration + correctionInterval;
            
            [strongSelf asyncDecodeFramesIfNeeded];
            
            return [[NSDate date] dateByAddingTimeInterval:nextFrameInterval];
        }
        else {
            if (strongSelf.isDecodingFinished) {
                if (strongSelf.framebuffer.nextAudioFrame == nil) {
                    [strongSelf finishPlaying];
                    return nil;
                }
            }
            else {
                [strongSelf asyncDecodeFramesIfNeeded];
            }
            
            RDMPEGAudioFrame *nextAudioFrame = strongSelf.framebuffer.nextAudioFrame;
            
            if (nextAudioFrame) {
                return [NSDate dateWithTimeIntervalSinceNow:strongSelf.framebuffer.nextAudioFrame.duration];
            }
            else {
                return [NSDate dateWithTimeIntervalSinceNow:0.01];
            }
        }
    }];
}

- (void)stopScheduler {
    if (self.scheduler.isScheduling == NO) {
        return;
    }
    
    [self.scheduler stop];
    self.scheduler = nil;
}

#pragma mark Rendering

- (nullable RDMPEGVideoFrame *)showNextVideoFrame {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    RDMPEGVideoFrame *videoFrame = [self.framebuffer popVideoFrame];
    
    if (videoFrame == nil) {
#if defined(RD_DEBUG_MPEG_PLAYER)
        log4Debug(@"There is no video frame to render");
#endif // RD_DEBUG_MPEG_PLAYER
        return nil;
    }
    
#if defined(RD_DEBUG_MPEG_PLAYER)
    log4Debug(@"Rendering video frame: %f %f", videoFrame.position, videoFrame.duration);
#endif // RD_DEBUG_MPEG_PLAYER
    
    self.currentInternalTime = videoFrame.position;
    
    [self.playerView.renderView render:videoFrame];
    
    [self showSubtitleForCurrentVideoFrame];
    
    return videoFrame;
}

- (void)showSubtitleForCurrentVideoFrame {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    NSArray<RDMPEGSubtitleFrame *> *currentSubtitleFrames = [self.currentSubtitleFrames copy];
    for (RDMPEGSubtitleFrame *currentSubtitleFrame in currentSubtitleFrames) {
        NSTimeInterval curSubtitleStartTime = currentSubtitleFrame.position;
        NSTimeInterval curSubtitleEndTime = curSubtitleStartTime + currentSubtitleFrame.duration;
        
        if (curSubtitleStartTime > self.currentInternalTime || curSubtitleEndTime < self.currentInternalTime) {
            [self.currentSubtitleFrames removeObject:currentSubtitleFrame];
        }
    }
    
    [self.framebuffer atomicSubtitleFramesAccess:^{
        while (self.framebuffer.nextSubtitleFrame) {
            NSTimeInterval nextSubtitleStartTime = self.framebuffer.nextSubtitleFrame.position;
            NSTimeInterval nextSubtitleEndTime = nextSubtitleStartTime + self.framebuffer.nextSubtitleFrame.duration;
            
            if (nextSubtitleStartTime <= self.currentInternalTime) {
                if (self.currentInternalTime < nextSubtitleEndTime) {
                    RDMPEGSubtitleFrame *subtitleFrame = [self.framebuffer popSubtitleFrame];
                    [self.currentSubtitleFrames addObject:subtitleFrame];
                    break;
                }
                else {
                    [self.framebuffer popSubtitleFrame];
                }
            }
            else {
                break;
            }
        }
    }];
    
    NSMutableString *subtitleString = [NSMutableString string];
    for (RDMPEGSubtitleFrame *currentSubtitleFrame in self.currentSubtitleFrames) {
        [subtitleString appendFormat:@"\n%@", currentSubtitleFrame.text];
    }
    self.playerView.subtitle = [subtitleString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

#pragma mark Audio

- (void)setAudioOutputEnabled:(BOOL)audioOutputEnabled {
    if (audioOutputEnabled) {
        if (self.audioRenderer.isPlaying) {
            return;
        }
        
        __weak __typeof(self) weakSelf = self;
        [self.audioRenderer playWithOutputCallback:^(float * _Nonnull data, UInt32 numFrames, UInt32 numChannels) {
            [weakSelf audioCallbackFillData:data numFrames:numFrames numChannels:numChannels];
        }];
    }
    else {
        [self.audioRenderer pause];
    }
}

- (void)audioCallbackFillData:(float *)outData numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels {
    
    @autoreleasepool {
        if (self.isVideoStreamExist && self.correctionInfo == nil) {
#if defined(RD_DEBUG_MPEG_PLAYER)
            log4Debug(@"Silence audio while correcting video");
#endif // RD_DEBUG_MPEG_PLAYER
            
            memset(outData, 0, numFrames * numChannels * sizeof(float));
            return;
        }
        
        UInt32 numFramesLeft = numFrames;
        
        while (numFramesLeft > 0) {
            if (self.rawAudioFrame == nil) {
                __block RDMPEGAudioFrame *nextAudioFrame = nil;
                __block BOOL isAudioOutrun = NO;
                __block BOOL isAudioLags = NO;
                
#if defined(RD_DEBUG_MPEG_PLAYER)
                log4BlocksLoggingScope
#endif // RD_DEBUG_MPEG_PLAYER
                
                [self.framebuffer atomicAudioFramesAccess:^{
                    if (self.framebuffer.nextAudioFrame) {
                        const CGFloat delta = [self.correctionInfo correctionIntervalWithCurrentTime:self.framebuffer.nextAudioFrame.position];
                        
                        if (delta > 0.1) {
#if defined(RD_DEBUG_MPEG_PLAYER)
                            log4BlockDebug(@"Desync audio (outrun) wait %.4f %.4f %.4f", self.currentInternalTime, self.framebuffer.nextAudioFrame.position, delta);
#endif // RD_DEBUG_MPEG_PLAYER
                            
                            isAudioOutrun = YES;
                            return;
                        }
                        
                        RDMPEGAudioFrame *audioFrame = [self.framebuffer popAudioFrame];
                        
                        if (self.isVideoStreamExist == NO) {
                            self.currentInternalTime = audioFrame.position;
                        }
                        
                        if (delta < -0.1 && self.framebuffer.nextAudioFrame) {
#if defined(RD_DEBUG_MPEG_PLAYER)
                            log4BlockDebug(@"Desync audio (lags) skip %.4f %.4f %.4f", self.currentInternalTime, self.framebuffer.nextAudioFrame.position, delta);
#endif // RD_DEBUG_MPEG_PLAYER
                            
                            isAudioLags = YES;
                            return;
                        }
                        
                        nextAudioFrame = audioFrame;
                    }
                }];
                
                
                if (isAudioOutrun) {
                    memset(outData, 0, numFramesLeft * numChannels * sizeof(float));
                    break;
                }
                if (isAudioLags) {
                    continue;
                }
                
                if (nextAudioFrame) {
#if defined(RD_DEBUG_MPEG_PLAYER)
                    log4Debug(@"Audio frame will be rendered: %.4f %.4f", nextAudioFrame.position, nextAudioFrame.duration);
#endif // RD_DEBUG_MPEG_PLAYER
                    
                    self.rawAudioFrame = [[RDMPEGRawAudioFrame alloc] initWithRawAudioData:nextAudioFrame.samples];
                    
                    if (self.isVideoStreamExist == NO) {
                        self.correctionInfo = [[RDMPEGCorrectionInfo alloc] initWithPlaybackStartDate:[NSDate date]
                                                                                    playbackStartTime:self.currentInternalTime];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setBufferingStateIfNeededAndNotify:NO];
                        });
                    }
                }
                else if (self.isVideoStreamExist == NO) {
                    self.correctionInfo = nil;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self setBufferingStateIfNeededAndNotify:YES];
                    });
                }
            }
            
            RDMPEGRawAudioFrame *rawAudioFrame = self.rawAudioFrame;
            
            if (rawAudioFrame) {
#if defined(RD_DEBUG_MPEG_PLAYER)
                log4Debug(@"Rendering raw audio frame");
#endif // RD_DEBUG_MPEG_PLAYER
                
                const void *bytes = rawAudioFrame.rawAudioData.bytes + rawAudioFrame.rawAudioDataOffset;
                const NSUInteger bytesLeft = (rawAudioFrame.rawAudioData.length - rawAudioFrame.rawAudioDataOffset);
                const NSUInteger frameSize = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFramesLeft * frameSize, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSize;
                
                memcpy(outData, bytes, bytesToCopy);
                numFramesLeft -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                rawAudioFrame.rawAudioDataOffset += bytesToCopy;
                
                if (rawAudioFrame.rawAudioDataOffset >= rawAudioFrame.rawAudioData.length) {
                    log4Assert(rawAudioFrame.rawAudioDataOffset == rawAudioFrame.rawAudioData.length, @"Incorrect offset, copying should be checked");
                    self.rawAudioFrame = nil;
                }
            }
            else {
#if defined(RD_DEBUG_MPEG_PLAYER)
                log4Debug(@"Silence audio");
#endif // RD_DEBUG_MPEG_PLAYER
                
                memset(outData, 0, numFramesLeft * numChannels * sizeof(float));
                break;
            }
        }
    }
}

#pragma mark - Buffering

- (void)setBufferingStateIfNeededAndNotify:(BOOL)buffering {
    log4Assert([NSThread isMainThread], @"Method '%@' called from wrong thread", NSStringFromSelector(_cmd));
    
    if (self.isBuffering == buffering) {
        return;
    }
    
    if (self.internalState != RDMPEGPlayerStatePlaying && buffering) {
        return;
    }
    
    self.buffering = buffering;
    
    [self.delegate mpegPlayer:self didChangeBufferingState:self.buffering];
}

#pragma mark Time Observing

- (void)startTimeObservingTimer {
    if (self.timeObservingTimer) {
        log4Assert(NO, @"Time observing timer already started");
        return;
    }
    
    RDMPEGWeakTimerTarget *timerTarget = [[RDMPEGWeakTimerTarget alloc] initWithTarget:self action:@selector(timeObservingTimerFired:)];
    self.timeObservingTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeObservingInterval target:timerTarget selector:@selector(timerFired:) userInfo:nil repeats:YES];
}

- (void)stopTimeObservingTimer {
    if (self.timeObservingTimer == nil) {
        return;
    }
    [self.timeObservingTimer invalidate];
    self.timeObservingTimer = nil;
}

- (void)timeObservingTimerFired:(NSTimer *)timer {
    if (self.seekOperation) {
        return;
    }
    
    [self.delegate mpegPlayer:self didUpdateCurrentTime:self.currentTime];
}

@end

NS_ASSUME_NONNULL_END
