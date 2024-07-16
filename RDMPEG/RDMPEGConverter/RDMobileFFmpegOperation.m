//
//  RDMobileFFmpegOperation.m
//  RDMPEG
//
//  Created by Artem on 24.08.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "RDMobileFFmpegOperation.h"
#import "RDMPEGOperation+Protected.h"
#import <FFmpegKit/FFmpegKit.h>
#import <Log4Cocoa/Log4Cocoa.h>

#import <RDMPEG/RDMPEG-Swift.h>


@interface RDMobileFFmpegOperation()

@property (nonatomic,strong)NSArray<NSString *> *arguments;
@property (nonatomic,copy)RDMobileFFmpegOperationResultBlock resultBlock;
@property (nonatomic,copy)RDMobileFFmpegOperationStatisticsBlock statisticsBlock;
@property (nonatomic, copy, nullable) RDMobileFFmpegOperationLogBlock logBlock;
@property (atomic, strong) FFmpegSession *session;

@end


@implementation RDMobileFFmpegOperation

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments
                  statisticsBlock:(RDMobileFFmpegOperationStatisticsBlock)statisticsBlock
                      resultBlock:(RDMobileFFmpegOperationResultBlock)resultBlock{
    return [self initWithArguments:arguments statisticsBlock:statisticsBlock resultBlock:resultBlock logBlock:nil];
}

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments
                  statisticsBlock:(RDMobileFFmpegOperationStatisticsBlock)statisticsBlock
                      resultBlock:(RDMobileFFmpegOperationResultBlock)resultBlock
                         logBlock:(__nullable RDMobileFFmpegOperationLogBlock)logBlock {
    NSParameterAssert(arguments);
    if(arguments == nil){
        return nil;
    }
    self = [super init];
    if(self){
        self.arguments = arguments;
        self.resultBlock = resultBlock;
        self.statisticsBlock = statisticsBlock;
        self.logBlock = logBlock;
    }
    return self;
}

- (void)main {
    NSParameterAssert(self.session == nil);
    
    __weak __typeof(self) const weakSelf = self;
    
    self.session =
    [FFmpegKit
     executeWithArgumentsAsync:self.arguments
     withExecuteCallback:^(id<Session> session) {
        if (weakSelf.resultBlock) {
            weakSelf.resultBlock([[session getReturnCode] getValue]);
        }
        
        [weakSelf completeOperation];
     }
     withLogCallback:^(Log *log) {
        if (weakSelf.logBlock) {
            weakSelf.logBlock([log getMessage], [log getLevel]);
        }
        log4CDebug(@"level: %@, message: %@", @([log getLevel]), [log getMessage]);
     }
     withStatisticsCallback:^(Statistics *statistics) {
        if (weakSelf.statisticsBlock) {
            weakSelf.statisticsBlock([[RDMobileFFmpegStatistics alloc] initWithStatistics:statistics]);
        }
    }];
}

- (void)cancel{
    [super cancel];
    
    long sessionId = [self.session getSessionId];
    [FFmpegKit cancel:sessionId];
}

+ (BOOL)isReturnCodeCancel:(int)code{
    return code == ReturnCodeCancel;
}

+ (BOOL)isReturnCodeSuccess:(int)code{
    return code == ReturnCodeSuccess;
}

@end
