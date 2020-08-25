//
//  RDMobileFFmpegUtils.m
//  RDMPEG
//
//  Created by Artem on 25.08.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "RDMobileFFmpegUtils.h"
#include <libavformat/avformat.h>


@implementation RDMobileFFmpegUtils

+ (int64_t)getDurationForLocalFileAtPath:(NSString *)localFilePath{
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

@end
