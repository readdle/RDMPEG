//
//  RDMPEGConverter.m
//  RDMPEG
//
//  Created by Igor Fedorov on 10.06.2019.
//  Copyright © 2019 Readdle. All rights reserved.
//

#import "RDMPEGConverter.h"
#import <MobileFFmpeg.h>

NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGConverter ()

@property NSString *inputFilePath;

@end

NS_ASSUME_NONNULL_END

@implementation RDMPEGConverter

- (instancetype)initWithFileAtPath:(NSString *)filePath
{
    self = [super init];
    if (self) {
        self.inputFilePath = filePath;
    }
    return self;
}

- (NSString *)convertToMP3
{
    [MobileFFmpeg getLastCommandOutput];
    int result = -1;
    NSString *pathToMP3;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:self.inputFilePath]) {
        NSString *baseFileName = [self.inputFilePath.lastPathComponent stringByDeletingPathExtension];
        NSString *convertedMP3 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"converted.mp3"];
        [[NSFileManager defaultManager] removeItemAtPath:convertedMP3 error:nil];
        result = [MobileFFmpeg executeWithArguments:@[@"-i",
                                                      self.inputFilePath,
                                                      @"-vn",
                                                      convertedMP3]];
        if (result == 0) {
            NSString *pathToArtwork = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFileName stringByAppendingPathExtension:@"jpg"]];
            [[NSFileManager defaultManager] removeItemAtPath:pathToArtwork error:nil];
            result = [MobileFFmpeg executeWithArguments:@[@"-i",
                                                          self.inputFilePath,
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
    }
    if (result == RETURN_CODE_CANCEL) {
        [[NSFileManager defaultManager] removeItemAtPath:pathToMP3 error:nil];
    }
    return result == 0 ? pathToMP3 : nil;
}

- (void)cancel
{
    [MobileFFmpeg cancel];
}

- (NSString *)errorOutput
{
    return [MobileFFmpeg getLastCommandOutput];
}

@end
