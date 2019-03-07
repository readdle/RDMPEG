//
//  RDMPEGCorrectionInfo.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/8/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGCorrectionInfo.h"
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGCorrectionInfo ()

@property (nonatomic, strong) NSDate *playbackStartDate;
@property (nonatomic, assign) NSTimeInterval playbackStartTime;

@end



@implementation RDMPEGCorrectionInfo

#pragma mark - Overridden Class Methods

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGCorrectionInfo"];
}

#pragma mark - Lifecycle

- (instancetype)initWithPlaybackStartDate:(NSDate *)playbackStartDate
                        playbackStartTime:(NSTimeInterval)playbackStartTime {
    self = [super init];
    if (self) {
        self.playbackStartDate = playbackStartDate;
        self.playbackStartTime = playbackStartTime;
    }
    return self;
}

#pragma mark - Public Methods

- (NSTimeInterval)correctionIntervalWithCurrentTime:(NSTimeInterval)currentTime {
    NSTimeInterval continuousPlaybackRealTime = [[NSDate date] timeIntervalSinceDate:self.playbackStartDate];
    
    if (continuousPlaybackRealTime < 0.0) {
        log4Assert(NO, @"Seems like playback start date is incorrect");
        return 0.0;
    }
    
    NSTimeInterval continuousPlaybackPlayedTime = currentTime - self.playbackStartTime;
    
    NSTimeInterval correctionInterval = continuousPlaybackPlayedTime - continuousPlaybackRealTime;
    return correctionInterval;
}

@end

NS_ASSUME_NONNULL_END
