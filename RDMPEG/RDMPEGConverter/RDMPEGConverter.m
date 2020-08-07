//
//  RDMPEGConverter.m
//  RDMPEG
//
//  Created by Igor Fedorov on 10.06.2019.
//  Copyright © 2019 Readdle. All rights reserved.
//

#import "RDMPEGConverter.h"
#import <MobileFFmpeg.h>
#import <MobileFFmpegConfig.h>
#include <libavformat/avformat.h>


NS_ASSUME_NONNULL_BEGIN


@interface RDMPEGConverter()<StatisticsDelegate,LogDelegate>

@property (nonatomic,assign)int64_t inputFileTotalDuration;
@property (nonatomic,assign)int64_t inputFileProcessedDuration;
@property (atomic,assign,getter=isExecuting)BOOL executing;

@end


@implementation RDMPEGConverter

+ (instancetype)sharedConverter{
    static dispatch_once_t onceToken;
    static RDMPEGConverter *converter;
    dispatch_once(&onceToken, ^{
        converter = [RDMPEGConverter new];
    });
    return converter;
}

- (instancetype)init{
    self = [super init];
    if(self){
        [MobileFFmpegConfig setStatisticsDelegate:self];
        [MobileFFmpegConfig setLogDelegate:self];
        [MobileFFmpegConfig enableRedirection];
    }
    return self;
}

+ (int64_t)getDurationOfLocalFileAtPath:(NSString *)localFilePath{
    AVFormatContext* pFormatCtx = avformat_alloc_context();
    int result = avformat_open_input(&pFormatCtx, localFilePath.UTF8String, NULL, NULL);
    int64_t duration = 0;
    if(result == 0){
        result = avformat_find_stream_info(pFormatCtx,NULL);
        if(result >= 0){
            duration = pFormatCtx->duration;
        }
    }
    avformat_close_input(&pFormatCtx);
    avformat_free_context(pFormatCtx);
    return duration;
}

- (NSString *)convertToMP3FileAtPath:(NSString *)inputFilePath
                    audioStreamIndex:(NSUInteger)audioStreamIndex{
    
    if(self.isExecuting){
        NSParameterAssert(NO);
        return nil;
    }
    
    if(inputFilePath == nil){
        NSParameterAssert(NO);
        return nil;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:inputFilePath] == NO) {
        NSParameterAssert(NO);
        return nil;
    }
    
    self.executing = YES;
    
    [MobileFFmpegConfig resetStatistics];
    
    self.inputFileTotalDuration = [RDMPEGConverter getDurationOfLocalFileAtPath:inputFilePath];
    self.inputFileProcessedDuration = 0;
    NSLog(@"frame total duration: %@",@(self.inputFileTotalDuration));
    
    int result = -1;
    NSString *pathToMP3;
    NSString *baseFileName = [inputFilePath.lastPathComponent stringByDeletingPathExtension];
    NSString *convertedMP3 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"converted.mp3"];
    [[NSFileManager defaultManager] removeItemAtPath:convertedMP3 error:nil];
    
    NSMutableArray *arguments = [NSMutableArray new];
    [arguments addObject:@"-i"];
    [arguments addObject:inputFilePath];
    if(audioStreamIndex > 0){
        [arguments addObject:@"-map"];
        [arguments addObject:[NSString stringWithFormat:@"0:a:%@",@(audioStreamIndex)]];
    }
    [arguments addObject:@"-vn"];
    [arguments addObject:convertedMP3];
    
    result = [MobileFFmpeg executeWithArguments:arguments];
    
    if (result == 0) {
        NSString *pathToArtwork = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFileName stringByAppendingPathExtension:@"jpg"]];
        [[NSFileManager defaultManager] removeItemAtPath:pathToArtwork error:nil];
        result = [MobileFFmpeg executeWithArguments:@[@"-i",
                                                      inputFilePath,
                                                      @"-ss",
                                                      @"-00:00:01",
                                                      @"-vframes",
                                                      @"1",
                                                      pathToArtwork]];
        
        NSString *pathToArtworkScaled = [NSTemporaryDirectory() stringByAppendingPathComponent:[[baseFileName stringByAppendingString:@"_scaled"] stringByAppendingPathExtension:@"jpg"]];
        [[NSFileManager defaultManager] removeItemAtPath:pathToArtworkScaled error:nil];
        
        //https://superuser.com/questions/547296/resizing-videos-with-ffmpeg-avconv-to-fit-into-static-sized-player/1136305#1136305
        result = [MobileFFmpeg executeWithArguments:@[@"-i",
                                                      pathToArtwork,
                                                      @"-vf",
                                                      //@"scale=300:300:force_original_aspect_ratio=increase",
                                                      //@"scale=300:-2:force_original_aspect_ratio=increase,pad=300:300:(ow-iw)/2:(oh-ih)/2",
                                                      @"scale=600:-2:force_original_aspect_ratio=increase,crop=300:300:keep_aspect=1",
                                                      pathToArtworkScaled]];
        
        if (result == 0) {
            pathToMP3 = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFileName stringByAppendingPathExtension:@"mp3"]];
            [[NSFileManager defaultManager] removeItemAtPath:pathToMP3 error:nil];
            result = [MobileFFmpeg executeWithArguments:@[@"-i",
                                                          convertedMP3,
                                                          @"-i",
                                                          pathToArtworkScaled,
                                                          @"-map",
                                                          @"0:0",
                                                          @"-map",
                                                          @"1:0",
                                                          @"-c",
                                                          @"copy",
                                                          @"-id3v2_version",
                                                          @"3",
                                                          @"-metadata:s:v",
                                                          @"title=\"Album cover\"",
                                                          @"-metadata:s:v",
                                                          @"comment=\"Cover (front)\"",
                                                          pathToMP3]];
        }
        [[NSFileManager defaultManager] removeItemAtPath:pathToArtwork error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:pathToArtworkScaled error:nil];
    }
    [[NSFileManager defaultManager] removeItemAtPath:convertedMP3 error:nil];
    if (result == RETURN_CODE_CANCEL) {
        [[NSFileManager defaultManager] removeItemAtPath:pathToMP3 error:nil];
    }
    
    self.executing = NO;
    
    return result == 0 ? pathToMP3 : nil;
}

- (void)logCallback: (int)level :(NSString*)message{
    NSLog(@"level: %@, message: %@",@(level),message);
}

//https://github.com/tanersener/mobile-ffmpeg/issues/172
- (void)statisticsCallback:(Statistics *)statistics{
    self.inputFileProcessedDuration = MAX([statistics getTime],self.inputFileProcessedDuration);
    if([self.delegate respondsToSelector:@selector(converterDidChangeProgress:)]){
        float progress = ((float)self.inputFileProcessedDuration/(float)self.inputFileTotalDuration)*1000;
        NSLog(@"frame: progress: %@",@(progress));
        [self.delegate converterDidChangeProgress:progress];
    }
    NSLog(@"frame: %@, time: %@, size: %@",@([statistics getVideoFrameNumber]),@([statistics getTime]),@([statistics getSize]));
}

- (void)cancel{
    [MobileFFmpeg cancel];
    self.executing = NO;
}

@end

NS_ASSUME_NONNULL_END
