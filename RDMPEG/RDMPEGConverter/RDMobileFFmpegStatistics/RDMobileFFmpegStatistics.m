//
//  RDMobileFFmpegStatistics.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 28.08.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "RDMobileFFmpegStatistics.h"
#import <FFmpegKit/FFmpegKit.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMobileFFmpegStatistics ()

@property (nonatomic, readonly) Statistics *statistics;

@end



@implementation RDMobileFFmpegStatistics

#pragma mark - Lifecycle

- (instancetype)initWithStatistics:(Statistics *)statistics {
    NSParameterAssert(statistics);
    
    self = [super init];
    
    if (nil == self) {
        return nil;
    }
    
    _statistics = statistics;
    
    return self;
}

#pragma mark - Accessors

- (NSInteger)frameNumber {
    return [self.statistics getVideoFrameNumber];
}

- (double)fps {
    return [self.statistics getVideoFps];
}

- (double)quality {
    return [self.statistics getVideoQuality];
}

- (NSInteger)size {
    return [self.statistics getSize];
}

- (NSInteger)time {
    return [self.statistics getTime];
}

- (double)bitrate {
    return [self.statistics getBitrate];
}

- (double)speed {
    return [self.statistics getSpeed];
}


@end

NS_ASSUME_NONNULL_END
