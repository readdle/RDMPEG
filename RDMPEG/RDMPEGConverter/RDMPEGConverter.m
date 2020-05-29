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

- (NSString *)convertToMP3FileAtPath:(NSString *)inputFilePath{
    
    if(inputFilePath == nil){
        NSParameterAssert(NO);
        return nil;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:inputFilePath] == NO) {
        NSParameterAssert(NO);
        return nil;
    }
    
    self.inputFileTotalDuration = [RDMPEGConverter getDurationOfLocalFileAtPath:inputFilePath];
    self.inputFileProcessedDuration = 0;
    NSLog(@"frame total duration: %@",@(self.inputFileTotalDuration));
    
    int result = -1;
    NSString *pathToMP3;
    NSString *baseFileName = [inputFilePath.lastPathComponent stringByDeletingPathExtension];
    NSString *convertedMP3 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"converted.mp3"];
    [[NSFileManager defaultManager] removeItemAtPath:convertedMP3 error:nil];
    
    result = [MobileFFmpeg executeWithArguments:@[@"-i",
                                                  inputFilePath,
                                                  @"-vn",
                                                  convertedMP3]];
    if (result == 0) {
        NSString *pathToArtwork = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFileName stringByAppendingPathExtension:@"jpg"]];
        [[NSFileManager defaultManager] removeItemAtPath:pathToArtwork error:nil];
        result = [MobileFFmpeg executeWithArguments:@[@"-i",
                                                      inputFilePath,
                                                      @"-frames",
                                                      @"1",
                                                      @"-q:v",
                                                      @"1",
                                                      @"-vf",
                                                      @"select=not(mod(n\\,40)),scale=-1:160,tile=2x3",
                                                      @"-s",
                                                      @"512x512",
                                                      @"-f",
                                                      @"image2",
                                                      pathToArtwork]];
        if (result == 0) {
            pathToMP3 = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFileName stringByAppendingPathExtension:@"mp3"]];
            [[NSFileManager defaultManager] removeItemAtPath:pathToMP3 error:nil];
            result = [MobileFFmpeg executeWithArguments:@[@"-i",
                                                          convertedMP3,
                                                          @"-i",
                                                          pathToArtwork,
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
    }
    [[NSFileManager defaultManager] removeItemAtPath:convertedMP3 error:nil];
    if (result == RETURN_CODE_CANCEL) {
        [[NSFileManager defaultManager] removeItemAtPath:pathToMP3 error:nil];
    }
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
}

@end

NS_ASSUME_NONNULL_END
