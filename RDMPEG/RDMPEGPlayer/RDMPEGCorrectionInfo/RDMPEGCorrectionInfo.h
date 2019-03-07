//
//  RDMPEGCorrectionInfo.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/8/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGCorrectionInfo : NSObject

@property (nonatomic, readonly) NSDate *playbackStartDate;
@property (nonatomic, readonly) NSTimeInterval playbackStartTime;

- (instancetype)initWithPlaybackStartDate:(NSDate *)playbackStartDate
                        playbackStartTime:(NSTimeInterval)playbackStartTime;

- (NSTimeInterval)correctionIntervalWithCurrentTime:(NSTimeInterval)currentTime;

@end

NS_ASSUME_NONNULL_END
