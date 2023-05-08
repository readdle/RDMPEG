//
//  RDMobileFFmpegOperation.h
//  RDMPEG
//
//  Created by Artem on 24.08.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <RDMPEG/RDMPEGOperation.h>

@class RDMobileFFmpegStatistics;


NS_ASSUME_NONNULL_BEGIN


typedef void(^RDMobileFFmpegOperationStatisticsBlock)(RDMobileFFmpegStatistics *statistics);
typedef void(^RDMobileFFmpegOperationResultBlock)(int result);
typedef void(^RDMobileFFmpegOperationLogBlock)(NSString *log, int level);


@interface RDMobileFFmpegOperation : RDMPEGOperation

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments
                  statisticsBlock:(RDMobileFFmpegOperationStatisticsBlock)statisticsBlock
                      resultBlock:(RDMobileFFmpegOperationResultBlock)resultBlock;

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments
                  statisticsBlock:(RDMobileFFmpegOperationStatisticsBlock)statisticsBlock
                      resultBlock:(RDMobileFFmpegOperationResultBlock)resultBlock
                         logBlock:(__nullable RDMobileFFmpegOperationLogBlock)logBlock;

+ (BOOL)isReturnCodeCancel:(int)code;

+ (BOOL)isReturnCodeSuccess:(int)code;

@end

NS_ASSUME_NONNULL_END
