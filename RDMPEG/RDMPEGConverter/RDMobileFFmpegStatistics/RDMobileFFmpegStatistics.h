//
//  RDMobileFFmpegStatistics.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 28.08.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RDMobileFFmpegStatistics : NSObject

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) NSInteger frameNumber;
@property (nonatomic, readonly) double fps;
@property (nonatomic, readonly) double quality;
@property (nonatomic, readonly) NSInteger size;
@property (nonatomic, readonly) NSInteger time;
@property (nonatomic, readonly) double bitrate;
@property (nonatomic, readonly) double speed;

@end

NS_ASSUME_NONNULL_END
