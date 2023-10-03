//
//  RDMPEGDecoder.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGDecoder.h"
#import "RDMPEGIOStream.h"
#import "RDMPEGSubtitleASSParser.h"
#import "RDMPEGFrames+Decoder.h"
#import "RDMPEGStream+Decoder.h"
#import <Accelerate/Accelerate.h>
#import <libavformat/avformat.h>
#import <libswscale/swscale.h>
#import <libswresample/swresample.h>
#import <libavutil/pixdesc.h>
#import <libavutil/imgutils.h>
#import <libavfilter/avfilter.h>
#import <libavfilter/buffersink.h>
#import <libavfilter/buffersrc.h>
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

NSString * const RDMPEGDecoderErrorDomain = @"RDMPEGDecoderErrorDomain";



static void ffmpeg_log(void *context, int level, const char *format, va_list args);
static int interrupt_callback(void *ctx);
static int iostream_readbuffer(void *ctx, uint8_t *buf, int buf_size);
static int64_t iostream_seekoffset(void *ctx, int64_t offset, int whence);
static void av_stream_FPS_timebase(AVStream *st, double defaultTimeBase, double * _Nullable pFPS, double * _Nullable pTimeBase);
static NSData *copy_frame_data(UInt8 *src, int linesize, int width, int height);



@interface RDMPEGDecoder () {
    AVFormatContext *_formatCtx;
    AVIOContext *_avioContext;
    AVFrame *_videoFrame;
    AVFrame *_filteredVideoFrame;
    AVFrame *_bgraVideoFrame;
    AVFrame *_audioFrame;
    double _videoTimeBase;
    double _audioTimeBase;
    double _subtitleTimeBase;
    double _fps;
    SwrContext *_swrContext;
    void *_swrBuffer;
    NSUInteger _swrBufferSize;
    struct SwsContext *_swsContext;
    NSNumber *_subtitleASSEvents;
    AVFilterGraph *_filterGraph;
}

@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSMutableArray<RDMPEGStream *> *videoStreams;
@property (nonatomic, strong) NSMutableArray<RDMPEGStream *> *audioStreams;
@property (nonatomic, strong) NSMutableArray<RDMPEGStream *> *subtitleStreams;
@property (nonatomic, strong) NSMutableArray<RDMPEGStream *> *artworkStreams;
@property (nonatomic, strong, nullable) id<RDMPEGIOStream> ioStream;
@property (nonatomic, strong, nullable) NSString *subtitleEncoding;
@property (nonatomic, strong, nullable) RDMPEGDecoderInterruptCallback interruptCallback;
@property (nonatomic, assign, nullable) RDMPEGStream *activeVideoStream;
@property (nonatomic, assign, nullable) RDMPEGStream *activeAudioStream;
@property (nonatomic, assign, nullable) RDMPEGStream *activeSubtitleStream;
@property (nonatomic, assign, nullable) RDMPEGStream *activeArtworkStream;
@property (nonatomic, assign) RDMPEGVideoFrameFormat actualVideoFrameFormat;
@property (nonatomic, assign) double audioSamplingRate;
@property (nonatomic, assign) NSUInteger audioOutputChannels;
@property (nonatomic, assign, getter=isEndReached) BOOL endReached;

@end



@implementation RDMPEGDecoder

#pragma mark - Overridden Class Methods

+ (void)initialize {
    av_log_set_callback(ffmpeg_log);
    avformat_network_init();
}

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGDecoder"];
}

#pragma mark - Lifecycle

- (instancetype)initWithPath:(NSString *)path
                    ioStream:(nullable id<RDMPEGIOStream>)ioStream
            subtitleEncoding:(nullable NSString *)subtitleEncoding
           interruptCallback:(nullable RDMPEGDecoderInterruptCallback)interruptCallback {
    log4Assert(path, @"Path should be specified");
    
    self = [super init];
    if (self) {
        self.path = path;
        self.ioStream = ioStream;
        self.subtitleEncoding = subtitleEncoding;
        self.interruptCallback = interruptCallback;
        
        self.videoStreams = [NSMutableArray array];
        self.audioStreams = [NSMutableArray array];
        self.subtitleStreams = [NSMutableArray array];
        self.artworkStreams = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path
                    ioStream:(nullable id<RDMPEGIOStream>)ioStream {
    
    return [self initWithPath:path
                     ioStream:ioStream
             subtitleEncoding:nil
            interruptCallback:nil];
}

- (void)dealloc {
    [self close];
}

#pragma mark - Public Accessors

- (NSTimeInterval)duration {
    if (_formatCtx == NULL || _formatCtx->duration == AV_NOPTS_VALUE) {
        return 0.0;
    }

    return (CGFloat)_formatCtx->duration / AV_TIME_BASE;
}

- (int64_t)ffmpegDuration{
    return self.duration * AV_TIME_BASE;
}

- (BOOL)isOpened {
    return (_formatCtx != NULL);
}

- (BOOL)isVideoStreamExist {
    return (self.videoStreams.count > 0);
}

- (BOOL)isAudioStreamExist {
    return (self.audioStreams.count > 0);
}

- (BOOL)isSubtitleStreamExist {
    return (self.subtitleStreams.count > 0);
}

- (NSUInteger)frameWidth {
    return self.activeVideoStream.codecContext ? self.activeVideoStream.codecContext->width : 0;
}

- (NSUInteger)frameHeight {
    return self.activeVideoStream.codecContext ? self.activeVideoStream.codecContext->height : 0;
}

- (nullable NSNumber *)activeAudioStreamIndex {
    if (self.activeAudioStream == nil) {
        return nil;
    }
    
    return @([self.audioStreams indexOfObject:self.activeAudioStream]);
}

- (nullable NSNumber *)activeSubtitleStreamIndex {
    if (self.activeSubtitleStream == nil) {
        return nil;
    }
    
    return @([self.subtitleStreams indexOfObject:self.activeSubtitleStream]);
}

#pragma mark - Public Methods

- (nullable NSError *)openInput {
    if (self.isOpened) {
        log4Assert(NO, @"Already opened");
        return nil;
    }
    
    AVFormatContext *formatCtx = NULL;
    AVIOContext *avioContext = NULL;
    
    if (self.interruptCallback || self.ioStream) {
        formatCtx = avformat_alloc_context();
        
        if (formatCtx == NULL) {
            return [self errorWithCode:RDMPEGDecoderErrorCodeOpenFile];
        }
    }
    
    if (self.interruptCallback) {
        AVIOInterruptCB cb = {interrupt_callback, (__bridge void *)(self)};
        formatCtx->interrupt_callback = cb;
    }
    
    if (self.ioStream) {
        if ([self.ioStream open] == NO) {
            avformat_free_context(formatCtx);
            return [self errorWithCode:RDMPEGDecoderErrorCodeOpenFile];
        }
        
        const int bufSize = AV_INPUT_BUFFER_MIN_SIZE + AV_INPUT_BUFFER_PADDING_SIZE;
        Byte *buffer = av_malloc(bufSize);
        if (buffer == NULL) {
            avformat_free_context(formatCtx);
            return [self errorWithCode:RDMPEGDecoderErrorCodeOpenFile];
        }
        
        avioContext = avio_alloc_context(buffer,
                                         bufSize,
                                         0,
                                         (__bridge void *)(self),
                                         iostream_readbuffer,
                                         NULL,
                                         iostream_seekoffset);
        
        if (avioContext == NULL) {
            av_freep(buffer);
            avformat_free_context(formatCtx);
            return [self errorWithCode:RDMPEGDecoderErrorCodeOpenFile];
        }
        
        formatCtx->pb = avioContext;
    }
    
    if (avformat_open_input(&formatCtx, [self.path cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL) < 0) {
        if (avioContext) {
            av_freep(avioContext);
        }
        if (formatCtx) {
            avformat_free_context(formatCtx);
        }
        return [self errorWithCode:RDMPEGDecoderErrorCodeOpenFile];
    }
    
    if (avformat_find_stream_info(formatCtx, NULL) < 0) {
        if (avioContext) {
            av_freep(avioContext);
        }
        avformat_close_input(&formatCtx);
        return [self errorWithCode:RDMPEGDecoderErrorCodeStreamInfoNotFound];
    }
    
    av_dump_format(formatCtx, 0, [self.path.lastPathComponent cStringUsingEncoding:NSUTF8StringEncoding], false);
    
    _formatCtx = formatCtx;
    _avioContext = avioContext;
    
    [self loadStreams];
    
    return nil;
}

- (nullable NSError *)loadVideoStreamWithPreferredVideoFrameFormat:(RDMPEGVideoFrameFormat)preferredVideoFrameFormat
                                            actualVideoFrameFormat:(RDMPEGVideoFrameFormat * _Nullable)actualVideoFrameFormat {
    if (self.isOpened == NO) {
        NSError *openInputError = [self openInput];
        
        if (openInputError) {
            return openInputError;
        }
    }
    
    if (self.videoStreams.count == 0) {
        return [self errorWithCode:RDMPEGDecoderErrorCodeStreamNotFound];
    }
    
    [self closeVideoStream];
    
    NSError *error = nil;
    
    for (RDMPEGStream *videoStream in self.videoStreams) {
        error = [self openVideoStream:videoStream
            preferredVideoFrameFormat:preferredVideoFrameFormat
               actialVideoFrameFormat:actualVideoFrameFormat];
        
        if (error == nil) {
            return nil;
        }
    }
    
    return error;
}

- (nullable NSError *)loadAudioStreamWithSamplingRate:(double)samplingRate outputChannels:(NSUInteger)outputChannels {
    if (self.isOpened == NO) {
        NSError *openInputError = [self openInput];
        
        if (openInputError) {
            return openInputError;
        }
    }
    
    if (self.audioStreams.count == 0) {
        return [self errorWithCode:RDMPEGDecoderErrorCodeStreamNotFound];
    }
    
    [self closeAudioStream];
    
    NSError *error = nil;
    
    for (RDMPEGStream *audioStream in self.audioStreams) {
        error = [self openAudioStream:audioStream samplingRage:samplingRate outputChannels:outputChannels];
        
        if (error == nil) {
            return nil;
        }
    }
    
    return error;
}

- (void)close {
    if (self.isOpened == NO) {
        return;
    }
    
    [self closeVideoStream];
    [self closeAudioStream];
    [self closeSubtitleStream];
    self.activeArtworkStream = nil;
    
    [self.videoStreams removeAllObjects];
    [self.audioStreams removeAllObjects];
    [self.subtitleStreams removeAllObjects];
    [self.artworkStreams removeAllObjects];
    
    if (_formatCtx) {
        _formatCtx->interrupt_callback.opaque = NULL;
        _formatCtx->interrupt_callback.callback = NULL;
        
        avformat_close_input(&_formatCtx);
        _formatCtx = NULL;
    }
    
    if (_avioContext) {
        av_freep(_avioContext);
    }
    
    if (self.ioStream) {
        [self.ioStream close];
    }
}

- (void)moveAtPosition:(NSTimeInterval)position {
    self.endReached = NO;
    
    if (self.activeVideoStream) {
        int64_t ts = (int64_t)(position / _videoTimeBase);
        
        if (self.activeVideoStream.stream->start_time != AV_NOPTS_VALUE) {
            ts += self.activeVideoStream.stream->start_time;
        }
        
        avformat_seek_file(_formatCtx, (int)self.activeVideoStream.streamIndex, ts, ts, ts, AVSEEK_FLAG_FRAME);
    }
    else if (self.activeAudioStream) {
        int64_t ts = (int64_t)(position / _audioTimeBase);
        
        if (self.activeAudioStream.stream->start_time != AV_NOPTS_VALUE) {
            ts += self.activeAudioStream.stream->start_time;
        }
        
        avformat_seek_file(_formatCtx, (int)self.activeAudioStream.streamIndex, ts, ts, ts, AVSEEK_FLAG_FRAME);
    }
    else if (self.activeSubtitleStream) {
        int64_t ts = 0.0;
        avformat_seek_file(_formatCtx, (int)self.activeSubtitleStream.streamIndex, ts, ts, ts, AVSEEK_FLAG_FRAME);
    }
    
    if (self.activeVideoStream.codecContext) {
        avcodec_flush_buffers(self.activeVideoStream.codecContext);
    }
    if (self.activeAudioStream.codecContext) {
        avcodec_flush_buffers(self.activeAudioStream.codecContext);
    }
    if (self.activeSubtitleStream.codecContext) {
        avcodec_flush_buffers(self.activeSubtitleStream.codecContext);
    }
}

- (nullable NSArray<RDMPEGFrame *> *)decodeFrames {
    NSMutableArray<RDMPEGFrame *> *frames = [NSMutableArray array];
    
    BOOL isFinished = NO;
    while (isFinished == NO) {
        AVPacket packet;
        
        int readFrameStatus = av_read_frame(_formatCtx, &packet);
        if (readFrameStatus < 0) {
            log4Error(@"Read frame error: %s (%@)", av_err2str(readFrameStatus), self.path.lastPathComponent);
            self.endReached = YES;
            break;
        }
        
        if (self.activeVideoStream && packet.stream_index == self.activeVideoStream.streamIndex) {
            int sendVideoPacketStatus = avcodec_send_packet(self.activeVideoStream.codecContext, &packet);
            if (sendVideoPacketStatus >= 0) {
                while (YES) {
                    if ([self receiveFrameWithCodecContext:self.activeVideoStream.codecContext frame:_videoFrame] == NO) {
                        break;
                    }
                    
                    if (self.isDeinterlacingEnabled && _videoFrame->interlaced_frame && [self setupFilterGraphIfNeeded]) {
                        int addFrameToBufferStatus = av_buffersrc_add_frame_flags(_filterGraph->filters[0], _videoFrame, AV_BUFFERSRC_FLAG_KEEP_REF);
                        if (addFrameToBufferStatus < 0) {
                            log4Assert(NO, @"Add frame to buffer error: %s", av_err2str(addFrameToBufferStatus));
                            break;
                        }
                        
                        while (YES) {
                            int buffersinkGetFrameStatus = av_buffersink_get_frame(_filterGraph->filters[1], _filteredVideoFrame);
                            if (buffersinkGetFrameStatus == AVERROR(EAGAIN) || buffersinkGetFrameStatus == AVERROR(AVERROR_EOF)) {
                                break;
                            }
                            
                            if (buffersinkGetFrameStatus < 0) {
                                log4Assert(NO, @"Get frame from buffer error: %s", av_err2str(buffersinkGetFrameStatus));
                                break;
                            }
                            
                            RDMPEGVideoFrame *videoFrame = [self handleVideoFrame:_filteredVideoFrame];
                            if (videoFrame) {
                                [frames addObject:videoFrame];
                                isFinished = YES;
                            }
                            
                            av_frame_unref(_filteredVideoFrame);
                        }
                    }
                    else {
                        RDMPEGVideoFrame *videoFrame = [self handleVideoFrame:_videoFrame];
                        if (videoFrame) {
                            [frames addObject:videoFrame];
                            isFinished = YES;
                        }
                    }
                }
            }
            else {
                log4Assert(NO, @"Send video packet to decoder error: %s", av_err2str(sendVideoPacketStatus));
            }
        }
        else if (self.activeAudioStream && packet.stream_index == self.activeAudioStream.streamIndex) {
            int sendAudioPacketStatus = avcodec_send_packet(self.activeAudioStream.codecContext, &packet);
            if (sendAudioPacketStatus >= 0) {
                while (YES) {
                    if ([self receiveFrameWithCodecContext:self.activeAudioStream.codecContext frame:_audioFrame] == NO) {
                        break;
                    }
                    
                    RDMPEGAudioFrame *audioFrame = [self handleAudioFrame];
                    if (audioFrame) {
                        [frames addObject:audioFrame];
                        
                        if (self.activeVideoStream == nil) {
                            isFinished = YES;
                        }
                    }
                }
            }
            else {
                log4Error(@"Send audio packet to decoder error: %s", av_err2str(sendAudioPacketStatus));
            }
        }
        else if (self.activeArtworkStream && packet.stream_index == self.activeArtworkStream.streamIndex) {
            if (packet.size) {
                NSData *pictureData = [NSData dataWithBytes:packet.data length:packet.size];
                
                RDMPEGArtworkFrame *artworkFrame = [[RDMPEGArtworkFrame alloc] initWithPicture:pictureData];
                [frames addObject:artworkFrame];
            }
        }
        else if (self.activeSubtitleStream && packet.stream_index == self.activeSubtitleStream.streamIndex) {
            int remainingPacketSize = packet.size;
            while (remainingPacketSize > 0) {
                AVSubtitle subtitle;
                int gotsubtitle = 0;
                int len = avcodec_decode_subtitle2(self.activeSubtitleStream.codecContext, &subtitle, &gotsubtitle, &packet);
                
                if (len < 0) {
                    log4Error(@"Decode subtitle error, skip packet: %s", av_err2str(len));
                    break;
                }
                
                if (gotsubtitle) {
                    RDMPEGSubtitleFrame *subtitleFrame = [self handleSubtitle:&subtitle];
                    if (subtitleFrame) {
                        [frames addObject:subtitleFrame];
                        
                        if (self.activeVideoStream == nil && self.activeAudioStream == nil) {
                            isFinished = YES;
                        }
                    }
                    avsubtitle_free(&subtitle);
                }
                
                if (len == 0) {
                    break;
                }
                
                remainingPacketSize -= len;
            }
        }
        
        av_packet_unref(&packet);
    }
    
    return frames;
}

- (BOOL)activateAudioStreamAtIndex:(nullable NSNumber *)audioStreamIndex
                      samplingRate:(double)samplingRate
                    outputChannels:(NSUInteger)outputChannels {
    [self closeAudioStream];
    
    if (audioStreamIndex == nil || audioStreamIndex.integerValue >= self.audioStreams.count) {
        return NO;
    }
    
    RDMPEGStream *audioStream = self.audioStreams[audioStreamIndex.integerValue];
    NSError *error = [self openAudioStream:audioStream
                              samplingRage:samplingRate
                            outputChannels:outputChannels];
    
    return (error == nil);
}

- (void)deactivateAudioStream {
    [self activateAudioStreamAtIndex:nil samplingRate:0.0 outputChannels:0];
}

- (BOOL)activateSubtitleStreamAtIndex:(nullable NSNumber *)subtitleStreamIndex {
    [self closeSubtitleStream];
    
    if (subtitleStreamIndex == nil || subtitleStreamIndex.integerValue >= self.subtitleStreams.count) {
        return NO;
    }
    
    RDMPEGStream *subtitleStream = self.subtitleStreams[subtitleStreamIndex.integerValue];
    NSError *error = [self openSubtitleStream:subtitleStream];
    
    return (error == nil);
}

- (void)deactivateSubtitleStream {
    [self activateSubtitleStreamAtIndex:nil];
}

#pragma mark - Private Methods

#pragma mark Open

- (void)loadStreams {
    if (self.isOpened == NO) {
        log4Assert(NO, @"Should be opened");
        return;
    }
    
    for (NSUInteger i = 0; i < _formatCtx->nb_streams; i++) {
        AVStream *stream = _formatCtx->streams[i];
        
        switch (stream->codecpar->codec_type) {
            case AVMEDIA_TYPE_VIDEO: {
                if ((stream->disposition & AV_DISPOSITION_ATTACHED_PIC) == 0) {
                    [self.videoStreams addObject:[[RDMPEGStream alloc] initWithStream:stream atIndex:i]];
                }
                else {
                    [self.artworkStreams addObject:[[RDMPEGStream alloc] initWithStream:stream atIndex:i]];
                }
                break;
            }
            case AVMEDIA_TYPE_AUDIO: {
                [self.audioStreams addObject:[[RDMPEGStream alloc] initWithStream:stream atIndex:i]];
                break;
            }
            case AVMEDIA_TYPE_SUBTITLE: {
                RDMPEGStream *subtitleStream = [[RDMPEGStream alloc] initWithStream:stream atIndex:i];
                subtitleStream.subtitleEncoding = self.subtitleEncoding;
                [self.subtitleStreams addObject:subtitleStream];
                break;
            }
            default: {
                break;
            }
        }
    }
}

#pragma mark Streams

- (nullable NSError *)openVideoStream:(RDMPEGStream *)videoStream
            preferredVideoFrameFormat:(RDMPEGVideoFrameFormat)preferredVideoFrameFormat
               actialVideoFrameFormat:(RDMPEGVideoFrameFormat * _Nullable)actualVideoFrameFormat {
    if (videoStream.codec == nil) {
        return [self errorWithCode:RDMPEGDecoderErrorCodeCodecNotFound];
    }
    
    if ([videoStream openCodec] == NO) {
        return [self errorWithCode:RDMPEGDecoderErrorCodeOpenCodec];
    }
    
    _videoFrame = av_frame_alloc();
    
    if (_videoFrame == NULL) {
        [videoStream closeCodec];
        return [self errorWithCode:RDMPEGDecoderErrorCodeAllocateFrame];
    }
    
    self.activeVideoStream = videoStream;
    
    if (preferredVideoFrameFormat == RDMPEGVideoFrameFormatYUV &&
        (self.activeVideoStream.codecContext->pix_fmt == AV_PIX_FMT_YUV420P || self.activeVideoStream.codecContext->pix_fmt == AV_PIX_FMT_YUVJ420P)) {
        self.actualVideoFrameFormat = RDMPEGVideoFrameFormatYUV;
    }
    else {
        self.actualVideoFrameFormat = RDMPEGVideoFrameFormatBGRA;
    }
    
    if (actualVideoFrameFormat) {
        *actualVideoFrameFormat = self.actualVideoFrameFormat;
    }
    
    av_stream_FPS_timebase(videoStream.stream, 0.04, &_fps, &_videoTimeBase);
    
    log4Info(@"Video codec size: %lu:%lu fps: %.3f tb: %f", (unsigned long)self.frameWidth, (unsigned long)self.frameHeight, _fps, _videoTimeBase);
    log4Info(@"Video start time %f disposition: %d", self.activeVideoStream.stream->start_time * _videoTimeBase, self.activeVideoStream.stream->disposition);
    
    return nil;
}

- (nullable NSError *)openAudioStream:(RDMPEGStream *)audioStream
                         samplingRage:(double)samplingRate
                       outputChannels:(NSUInteger)outputChannels {
    if (audioStream.codec == nil) {
        return [self errorWithCode:RDMPEGDecoderErrorCodeCodecNotFound];
    }
    
    if ([audioStream openCodec] == NO) {
        return [self errorWithCode:RDMPEGDecoderErrorCodeOpenCodec];
    }
    
    BOOL audioCodecSupported = NO;
    if (audioStream.codecContext->sample_fmt == AV_SAMPLE_FMT_S16 &&
        audioStream.codecContext->sample_rate == (int)samplingRate &&
        audioStream.codecContext->ch_layout.nb_channels == outputChannels) {
        audioCodecSupported = YES;
    }
    
    SwrContext *swrContext = NULL;
    
    if (audioCodecSupported == NO) {
        AVChannelLayout outLayout;
        av_channel_layout_default(&outLayout, (int)outputChannels);

        AVChannelLayout inLayout;
        av_channel_layout_default(&inLayout, (int)audioStream.codecContext->ch_layout.nb_channels);

        swr_alloc_set_opts2(&swrContext,
                            &outLayout,
                            AV_SAMPLE_FMT_S16,
                            (int)samplingRate,
                            &inLayout,
                            audioStream.codecContext->sample_fmt,
                            audioStream.codecContext->sample_rate,
                            0,
                            NULL);

        if (swrContext == NULL) {
            [audioStream closeCodec];
            return [self errorWithCode:RDMPEGDecoderErrorCodeSampler];
        }
        
        if (swr_init(swrContext)) {
            swr_free(&swrContext);
            [audioStream closeCodec];
            
            return [self errorWithCode:RDMPEGDecoderErrorCodeSampler];
        }
    }
    
    _audioFrame = av_frame_alloc();
    
    if (_audioFrame == NULL) {
        swr_free(&swrContext);
        [audioStream closeCodec];
        return [self errorWithCode:RDMPEGDecoderErrorCodeAllocateFrame];
    }
    
    _swrContext = swrContext;
    
    self.activeAudioStream = audioStream;
    self.audioSamplingRate = samplingRate;
    self.audioOutputChannels = outputChannels;
    
    av_stream_FPS_timebase(self.activeAudioStream.stream, 0.025, NULL, &_audioTimeBase);
    
    log4Info(@"Audio codec smr: %.d fmt: %d chn: %d tb: %f %@", self.activeAudioStream.codecContext->sample_rate, self.activeAudioStream.codecContext->sample_fmt, self.activeAudioStream.codecContext->ch_layout.nb_channels, _audioTimeBase, _swrContext ? @"resample" : @"");

    return nil;
}

- (nullable NSError *)openSubtitleStream:(RDMPEGStream *)subtitleStream {
    if (subtitleStream.codec == nil) {
        return [self errorWithCode:RDMPEGDecoderErrorCodeCodecNotFound];
    }
    
    const AVCodecDescriptor *codecDesc = avcodec_descriptor_get(subtitleStream.stream->codecpar->codec_id);
    if (codecDesc && (codecDesc->props & AV_CODEC_PROP_BITMAP_SUB)) {
        return [self errorWithCode:RDMPEGDecoderErrorCodeUnsupported];
    }
    
    if ([subtitleStream openCodec] == NO) {
        return [self errorWithCode:RDMPEGDecoderErrorCodeOpenCodec];
    }
    
    self.activeSubtitleStream = subtitleStream;
    
    _subtitleASSEvents = nil;
    
    log4Info(@"subtitle codec: '%s' mode: %d enc: %s",
             nil != codecDesc ? codecDesc->name : "unknown",
             self.activeSubtitleStream.codecContext->sub_charenc_mode,
             self.activeSubtitleStream.codecContext->sub_charenc);
    
    if (self.activeSubtitleStream.codecContext->subtitle_header_size) {
        NSString *subtitleHeader = [[NSString alloc] initWithBytes:self.activeSubtitleStream.codecContext->subtitle_header
                                                            length:self.activeSubtitleStream.codecContext->subtitle_header_size
                                                          encoding:NSASCIIStringEncoding];
        
        if (subtitleHeader.length > 0) {
            NSArray *fields = [RDMPEGSubtitleASSParser parseEvents:subtitleHeader];
            if (fields.count > 0 && [fields.lastObject isEqualToString:@"Text"]) {
                _subtitleASSEvents = @(fields.count);
                log4Info(@"subtitle ass events: %@", [fields componentsJoinedByString:@","]);
            }
        }
    }
    
    av_stream_FPS_timebase(self.activeSubtitleStream.stream, 0.01, NULL, &_subtitleTimeBase);
    
    return nil;
}

- (void)closeVideoStream {
    [self unloadFilterGraph];
    
    [self.activeVideoStream closeCodec];
    
    self.activeVideoStream = nil;
    self.actualVideoFrameFormat = RDMPEGVideoFrameFormatYUV;
    
    [self closeVideoScaler];
    
    if (_videoFrame) {
        av_freep(_videoFrame);
    }
}

- (void)closeAudioStream {
    [self.activeAudioStream closeCodec];
    
    self.activeAudioStream = nil;
    self.audioSamplingRate = 0.0;
    self.audioOutputChannels = 0;
    
    if (_swrBuffer) {
        free(_swrBuffer);
        _swrBuffer = NULL;
        _swrBufferSize = 0;
    }
    
    if (_swrContext) {
        swr_free(&_swrContext);
        _swrContext = NULL;
    }
    
    if (_audioFrame) {
        av_freep(_audioFrame);
    }
}

- (void)closeSubtitleStream {
    [self.activeSubtitleStream closeCodec];
    self.activeSubtitleStream = nil;
}

#pragma mark Decoding

- (BOOL)receiveFrameWithCodecContext:(AVCodecContext *)codecContext frame:(AVFrame *)frame {
    int receiveFrameStatus = avcodec_receive_frame(codecContext, frame);
    
    if (receiveFrameStatus == AVERROR(EAGAIN) || receiveFrameStatus == AVERROR_EOF) {
        return NO;
    }
    
    if (receiveFrameStatus < 0) {
        log4Assert(NO, @"Receive frame status error: %s", av_err2str(receiveFrameStatus));
        return NO;
    }
    
    return YES;
}

#pragma mark Filtering

- (BOOL)setupFilterGraphIfNeeded {
    if (_filterGraph) {
        return YES;
    }
    
    if (self.activeVideoStream.codecContext == NULL) {
        log4Assert(NO, @"Active video tream with correct codec context should exist");
        return NO;
    }
    
    const AVFilter *buffer = avfilter_get_by_name("buffer");
    const AVFilter *buffersink = avfilter_get_by_name("buffersink");
    
    _filterGraph = avfilter_graph_alloc();
    if (_filterGraph == NULL) {
        return NO;
    }
    
    char args[512];
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             self.activeVideoStream.codecContext->width,
             self.activeVideoStream.codecContext->height,
             self.activeVideoStream.codecContext->pix_fmt,
             self.activeVideoStream.codecContext->time_base.num,
             self.activeVideoStream.codecContext->time_base.den,
             self.activeVideoStream.codecContext->sample_aspect_ratio.num,
             self.activeVideoStream.codecContext->sample_aspect_ratio.den);
    
    AVFilterContext *bufferContext = NULL;
    AVFilterContext *buffersinkContext = NULL;
    
    int createInFilterStatus = avfilter_graph_create_filter(&bufferContext, buffer, "in", args, NULL, _filterGraph);
    if (createInFilterStatus < 0) {
        log4Assert(NO, @"Create in filter error: %s", av_err2str(createInFilterStatus));
        avfilter_graph_free(&_filterGraph);
        return NO;
    }
    
    int createOutFilterStatus = avfilter_graph_create_filter(&buffersinkContext, buffersink, "out", NULL, NULL, _filterGraph);
    if (createOutFilterStatus < 0) {
        log4Assert(NO, @"Create out filter error: %s", av_err2str(createOutFilterStatus));
        avfilter_graph_free(&_filterGraph);
        return NO;
    }
    
    AVFilterInOut *inputs  = avfilter_inout_alloc();
    if (inputs == NULL) {
        log4Assert(NO, @"Unable to create inputs");
        avfilter_graph_free(&_filterGraph);
        return NO;
    }
    
    AVFilterInOut *outputs = avfilter_inout_alloc();
    if (outputs == NULL) {
        log4Assert(NO, @"Unable to create outputs");
        avfilter_inout_free(&inputs);
        avfilter_graph_free(&_filterGraph);
        return NO;
    }
    
    outputs->name = av_strdup("in");
    outputs->filter_ctx = bufferContext;
    outputs->pad_idx = 0;
    outputs->next = NULL;
    
    inputs->name = av_strdup("out");
    inputs->filter_ctx = buffersinkContext;
    inputs->pad_idx = 0;
    inputs->next = NULL;
    
    int parseGraphStatus = avfilter_graph_parse_ptr(_filterGraph, "yadif=0:-1:0", &inputs, &outputs, NULL);
    
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    
    if (parseGraphStatus < 0) {
        log4Assert(NO, @"Parse graph error: %s", av_err2str(parseGraphStatus));
        avfilter_graph_free(&_filterGraph);
        return NO;
    }
    
    int configureGraphStatus = avfilter_graph_config(_filterGraph, NULL);
    if (configureGraphStatus < 0) {
        log4Assert(NO, @"Configure graph error: %s", av_err2str(configureGraphStatus));
        avfilter_graph_free(&_filterGraph);
        return NO;
    }
    
    _filteredVideoFrame = av_frame_alloc();
    if (_filteredVideoFrame == NULL) {
        log4Assert(NO, @"Unable to create filter frame");
        avfilter_graph_free(&_filterGraph);
        return NO;
    }
    
    return YES;
}

- (void)unloadFilterGraph {
    avfilter_graph_free(&_filterGraph);
    
    if (_filteredVideoFrame) {
        av_freep(_filteredVideoFrame);
    }
}

#pragma mark Frames

- (nullable RDMPEGVideoFrame *)handleVideoFrame:(AVFrame *)avFrame {
    if (avFrame == NULL) {
        log4Assert(NO, @"Video frame doesn't exist");
        return nil;
    }
    
    if (avFrame->data[0] == NULL) {
        return nil;
    }
    
    NSTimeInterval frameOffset = 0.0;
    
    if (self.activeVideoStream.stream->start_time != AV_NOPTS_VALUE) {
        frameOffset = self.activeVideoStream.stream->start_time * _videoTimeBase;
    }
    
    NSTimeInterval framePosition = avFrame->best_effort_timestamp * _videoTimeBase - frameOffset;
    
    NSTimeInterval frameDuration = 0.0;
    if (avFrame->duration) {
        frameDuration = avFrame->duration * _videoTimeBase;
        frameDuration += avFrame->repeat_pict * _videoTimeBase * 0.5;
    }
    else {
        // sometimes, ffmpeg unable to determine a frame duration
        // as example yuvj420p stream from web camera
        frameDuration = 1.0 / _fps;
    }
    
    RDMPEGVideoFrame *videoFrame;
    
    if (self.actualVideoFrameFormat == RDMPEGVideoFrameFormatYUV) {
        NSData *luma = copy_frame_data(avFrame->data[0], avFrame->linesize[0], self.activeVideoStream.codecContext->width, self.activeVideoStream.codecContext->height);
        NSData *chromaB = copy_frame_data(avFrame->data[1], avFrame->linesize[1], self.activeVideoStream.codecContext->width / 2, self.activeVideoStream.codecContext->height / 2);
        NSData *chromaR = copy_frame_data(avFrame->data[2], avFrame->linesize[2], self.activeVideoStream.codecContext->width / 2, self.activeVideoStream.codecContext->height / 2);
        
        videoFrame = [[RDMPEGVideoFrameYUV alloc] initWithPosition:framePosition
                                                          duration:frameDuration
                                                             width:self.frameWidth
                                                            height:self.frameHeight
                                                              luma:luma
                                                           chromaB:chromaB
                                                           chromaR:chromaR];
    }
    else {
        if (_swsContext == NULL && [self setupVideoScaler] == NO) {
            log4Assert(NO, @"Failed to setup video scaler");
            return nil;
        }
        
        sws_scale(_swsContext,
                  (const uint8_t **)avFrame->data,
                  avFrame->linesize,
                  0,
                  self.activeVideoStream.codecContext->height,
                  _bgraVideoFrame->data,
                  _bgraVideoFrame->linesize);
        
        NSUInteger linesize = _bgraVideoFrame->linesize[0];
        NSData *bgra = [NSData dataWithBytes:_bgraVideoFrame->data[0] length:(linesize * self.activeVideoStream.codecContext->height)];
        
        videoFrame = [[RDMPEGVideoFrameBGRA alloc] initWithPosition:framePosition
                                                           duration:frameDuration
                                                              width:self.frameWidth
                                                             height:self.frameHeight
                                                               bgra:bgra
                                                           linesize:linesize];
    }
    
    return videoFrame;
}

- (nullable RDMPEGAudioFrame *)handleAudioFrame {
    if (_audioFrame == NULL) {
        log4Assert(NO, @"Audio frame doesn't exist");
        return nil;
    }
    
    if (_audioFrame->data[0] == NULL) {
        return nil;
    }
    
    NSInteger samplesCount;
    void *audioData;
    
    if (_swrContext) {
        const NSUInteger ratio = MAX(1, self.audioSamplingRate / self.activeAudioStream.codecContext->sample_rate) *
                                 MAX(1, self.audioOutputChannels / self.activeAudioStream.codecContext->ch_layout.nb_channels) * 2;

        const int bufSize = av_samples_get_buffer_size(NULL,
                                                       (int)self.audioOutputChannels,
                                                       (int)(_audioFrame->nb_samples * ratio),
                                                       AV_SAMPLE_FMT_S16,
                                                       1);
        
        if (_swrBuffer == NULL || _swrBufferSize < bufSize) {
            _swrBufferSize = bufSize;
            _swrBuffer = realloc(_swrBuffer, _swrBufferSize);
        }
        
        Byte *outbuf[2] = {_swrBuffer, 0};
        
        samplesCount = swr_convert(_swrContext,
                                   outbuf,
                                   (int)(_audioFrame->nb_samples * ratio),
                                   (const uint8_t **)_audioFrame->data,
                                   _audioFrame->nb_samples);
        
        if (samplesCount < 0) {
            log4Assert(NO, @"Failed to resample audio");
            return nil;
        }
        
        audioData = _swrBuffer;
    }
    else {
        if (self.activeAudioStream.codecContext->sample_fmt != AV_SAMPLE_FMT_S16) {
            log4Assert(NO, @"Invalid audio format");
            return nil;
        }
        
        audioData = _audioFrame->data[0];
        samplesCount = _audioFrame->nb_samples;
    }
    
    const NSUInteger elementsCount = samplesCount * self.audioOutputChannels;
    NSMutableData *samples = [NSMutableData dataWithLength:(elementsCount * sizeof(float))];
    
    float scale = 1.0 / (float)INT16_MAX;
    vDSP_vflt16((SInt16 *)audioData, 1, samples.mutableBytes, 1, elementsCount);
    vDSP_vsmul(samples.mutableBytes, 1, &scale, samples.mutableBytes, 1, elementsCount);
    
    NSTimeInterval frameOffset = 0.0;
    
    if (self.activeAudioStream.stream->start_time != AV_NOPTS_VALUE) {
        frameOffset = self.activeAudioStream.stream->start_time * _audioTimeBase;
    }
    
    NSTimeInterval framePosition = _audioFrame->best_effort_timestamp * _audioTimeBase - frameOffset;
    
    NSTimeInterval frameDuration = 0.0;
    if (_audioFrame->duration) {
        frameDuration = _audioFrame->duration * _audioTimeBase;
    }
    else {
        // sometimes ffmpeg can't determine the duration of audio frame
        // especially of wma/wmv format
        // so in this case must compute duration
        frameDuration = samples.length / (sizeof(float) * self.audioOutputChannels * self.audioSamplingRate);
    }
    
    RDMPEGAudioFrame *audioFrame = [[RDMPEGAudioFrame alloc] initWithPosition:framePosition
                                                                     duration:frameDuration
                                                                      samples:samples];
    return audioFrame;
}

- (nullable RDMPEGSubtitleFrame *)handleSubtitle:(AVSubtitle *)pSubtitle {
    NSMutableString *mutableSubtitle = [NSMutableString string];
    
    for (NSUInteger i = 0; i < pSubtitle->num_rects; ++i) {
        AVSubtitleRect *rect = pSubtitle->rects[i];
        if (rect == NULL) {
            continue;
        }
        
        if (rect->text) { // rect->type == SUBTITLE_TEXT
            NSString *subtitle = [NSString stringWithUTF8String:rect->text];
            if (subtitle.length > 0) {
                [mutableSubtitle appendString:subtitle];
            }
        }
        else if (rect->ass && _subtitleASSEvents) {
            NSString *subtitle = [NSString stringWithUTF8String:rect->ass];
            if (subtitle.length > 0) {
                NSArray<NSString *> *fields = [RDMPEGSubtitleASSParser parseDialogue:subtitle numFields:_subtitleASSEvents.integerValue];
                if (fields.count > 0 && fields.lastObject.length > 0) {
                    subtitle = [RDMPEGSubtitleASSParser removeCommandsFromEventText:fields.lastObject];
                    if (subtitle.length > 0) {
                        [mutableSubtitle appendString:subtitle];
                    }
                }
            }
        }
    }
    
    if (mutableSubtitle.length == 0) {
        return nil;
    }
    
    NSTimeInterval subtitlePosition = ((CGFloat)pSubtitle->pts / AV_TIME_BASE) + pSubtitle->start_display_time;
    NSTimeInterval subtitleDuration = (CGFloat)(pSubtitle->end_display_time - pSubtitle->start_display_time) / 1000.0f;
    
    RDMPEGSubtitleFrame *subtitleFrame = [[RDMPEGSubtitleFrame alloc] initWithPosition:subtitlePosition
                                                                              duration:subtitleDuration
                                                                                  text:mutableSubtitle];
    
    return subtitleFrame;
}

#pragma mark Scalers

- (BOOL)setupVideoScaler {
    [self closeVideoScaler];
    
    _bgraVideoFrame = av_frame_alloc();
    
    if (_bgraVideoFrame == NULL) {
        return NO;
    }
    
    _bgraVideoFrame->width = self.activeVideoStream.codecContext->width;
    _bgraVideoFrame->height = self.activeVideoStream.codecContext->height;
    _bgraVideoFrame->format = AV_PIX_FMT_BGRA;
    
    int imageStatusCode = av_image_alloc(_bgraVideoFrame->data,
                                         _bgraVideoFrame->linesize,
                                         _bgraVideoFrame->width,
                                         _bgraVideoFrame->height,
                                         _bgraVideoFrame->format,
                                         1);
    
    if (imageStatusCode < 0) {
        log4Error(@"Allocate image error: %s", av_err2str(imageStatusCode));
        
        av_freep(_bgraVideoFrame);
        
        return NO;
    }
    
    _swsContext = sws_getCachedContext(_swsContext,
                                       self.activeVideoStream.codecContext->width,
                                       self.activeVideoStream.codecContext->height,
                                       self.activeVideoStream.codecContext->pix_fmt,
                                       _bgraVideoFrame->width,
                                       _bgraVideoFrame->height,
                                       _bgraVideoFrame->format,
                                       SWS_FAST_BILINEAR,
                                       NULL, NULL, NULL);
    
    return (_swsContext != NULL);
}

- (void)closeVideoScaler {
    if (_swsContext) {
        sws_freeContext(_swsContext);
        _swsContext = NULL;
    }
    
    if (_bgraVideoFrame) {
        av_freep(_bgraVideoFrame->data);
        av_freep(_bgraVideoFrame);
    }
}

#pragma mark Errors

- (NSError *)errorWithCode:(RDMPEGDecoderErrorCode)errorCode {
    NSString *message = nil;
    
    switch (errorCode) {
        case RDMPEGDecoderErrorCodeOpenFile: { message = @"Unable to open file"; break; }
        case RDMPEGDecoderErrorCodeStreamInfoNotFound: { message = @"Unable to find stream information"; break; }
        case RDMPEGDecoderErrorCodeStreamNotFound: { message = @"Unable to find stream"; break; }
        case RDMPEGDecoderErrorCodeCodecNotFound: { message = @"Unable to find codec"; break; }
        case RDMPEGDecoderErrorCodeOpenCodec: { message = @"Unable to open codec"; break; }
        case RDMPEGDecoderErrorCodeAllocateFrame: { message = @"Unable to allocate frame"; break; }
        case RDMPEGDecoderErrorCodeSampler: { message = @"Unable to setup resampler"; break; }
        case RDMPEGDecoderErrorCodeUnsupported: { message = @"The ability is not supported"; break; }
    }
    
    log4Assert(message, @"Message not specified");
    
    NSDictionary<NSErrorUserInfoKey, id> *userInfo = nil;
    if (message) {
        userInfo = @{NSDebugDescriptionErrorKey: message};
    }
    
    return [NSError errorWithDomain:RDMPEGDecoderErrorDomain code:errorCode userInfo:userInfo];
}

@end



static void ffmpeg_log(void *context, int level, const char *format, va_list args) {
    @autoreleasepool {
        if (level == AV_LOG_PANIC ||
            level == AV_LOG_FATAL ||
            level == AV_LOG_ERROR) {
            log4CError(@"%@", [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args]);
        }
        else if (level == AV_LOG_WARNING) {
            log4CWarn(@"%@", [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args]);
        }
        else if (level == AV_LOG_INFO ||
                 level == AV_LOG_VERBOSE) {
            log4CDebug(@"%@", [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args]);
        }
    }
}

static int interrupt_callback(void *ctx) {
    if (ctx == NULL) {
        return 0;
    }
    
    RDMPEGDecoder *decoder = (__bridge RDMPEGDecoder *)ctx;
    if (decoder.interruptCallback) {
        BOOL interrupt = decoder.interruptCallback();
        return interrupt ? 1 : 0;
    }
    
    return 0;
}

static int iostream_readbuffer(void *ctx, uint8_t *buf, int buf_size) {
    if (ctx == NULL) {
        return -1;
    }
    
    RDMPEGDecoder *decoder = (__bridge RDMPEGDecoder *)ctx;
    
    if (decoder.ioStream) {
        return (int)[decoder.ioStream readBuffer:buf length:buf_size];
    }
    else {
        log4CError(@"Method 'iostream_readbuffer' should be called only if stream exist");
        NSCParameterAssert(NO);
        return -1;
    }
}

static int64_t iostream_seekoffset(void *ctx, int64_t offset, int whence) {
    if (ctx == NULL) {
        return -1;
    }
    
    RDMPEGDecoder *decoder = (__bridge RDMPEGDecoder *)ctx;
    
    if (decoder.ioStream) {
        if (whence == AVSEEK_SIZE) {
            if ([decoder.ioStream respondsToSelector:@selector(contentLength)] == NO) {
                return -1;
            }
            return decoder.ioStream.contentLength;
        }
        
        return [decoder.ioStream seekOffset:offset whence:whence];
    }
    else {
        log4CError(@"Method 'iostream_seekoffset' should be called only if stream exist");
        NSCParameterAssert(NO);
        return -1;
    }
}

static void av_stream_FPS_timebase(AVStream *st, double defaultTimeBase, double * _Nullable pFPS, double * _Nullable pTimeBase) {
    double fps;
    double timebase;
    
    if (st->time_base.den && st->time_base.num) {
        timebase = av_q2d(st->time_base);
    }
    else {
        log4CWarn(@"Default timebase used: %f", defaultTimeBase);
        NSCParameterAssert(NO);
        timebase = defaultTimeBase;
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num) {
        fps = av_q2d(st->avg_frame_rate);
    }
    else if (st->r_frame_rate.den && st->r_frame_rate.num) {
        fps = av_q2d(st->r_frame_rate);
    }
    else {
        fps = 1.0 / timebase;
        log4CWarn(@"Default fps used: %f", fps);
    }
    
    if (pFPS) {
        *pFPS = fps;
    }
    if (pTimeBase) {
        *pTimeBase = timebase;
    }
}

static NSData *copy_frame_data(UInt8 *src, int linesize, int width, int height) {
    width = MIN(linesize, width);
    
    NSMutableData *frameData = [NSMutableData dataWithLength:(width * height)];
    Byte *dst = frameData.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    
    return frameData;
}

NS_ASSUME_NONNULL_END
