//
//  RDMobileFFmpegOperation.m
//  RDMPEG
//
//  Created by Artem on 24.08.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "RDMobileFFmpegOperation.h"
#import <MobileFFmpeg.h>
#import <MobileFFmpegConfig.h>
#include <libavformat/avformat.h>
#import <Log4Cocoa/Log4Cocoa.h>



@protocol RDMobileFFmpegStatisticsDelegate <NSObject>

- (void)statisticsCallback:(Statistics *)statistics;

@end



@interface RDMobileFFmpegDelegate : NSObject <StatisticsDelegate,LogDelegate>

@property (nonatomic, strong)NSHashTable <RDMobileFFmpegStatisticsDelegate> *statisticsDelegates;

+ (instancetype)sharedDelegate;

- (void)addStatisticsDelegate:(id<RDMobileFFmpegStatisticsDelegate>)statisticsDelegate;

- (void)removeStatisticsDelegate:(id<RDMobileFFmpegStatisticsDelegate>)statisticsDelegate;

@end


@interface RDMobileFFmpegOperation()<RDMobileFFmpegStatisticsDelegate>

@property (nonatomic,strong)NSArray<NSString *> *arguments;
@property (nonatomic,copy)RDMobileFFmpegOperationResultBlock resultBlock;
@property (nonatomic,copy)RDMobileFFmpegOperationStatisticsBlock statisticsBlock;

@end


@implementation RDMobileFFmpegOperation

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments
                  statisticsBlock:(RDMobileFFmpegOperationStatisticsBlock)statisticsBlock
                      resultBlock:(RDMobileFFmpegOperationResultBlock)resultBlock{
    NSParameterAssert(arguments);
    if(arguments == nil){
        return nil;
    }
    self = [super init];
    if(self){
        [[RDMobileFFmpegDelegate sharedDelegate] addStatisticsDelegate:self];
        self.arguments = arguments;
        self.resultBlock = resultBlock;
        self.statisticsBlock = statisticsBlock;
    }
    return self;
}

- (void)dealloc{
    [[RDMobileFFmpegDelegate sharedDelegate] removeStatisticsDelegate:self];
}

- (void)statisticsCallback:(Statistics *)statistics{
    if(self.statisticsBlock){
        self.statisticsBlock(statistics);
    }
}

- (void)main {
    [MobileFFmpegConfig resetStatistics];
    int result = [MobileFFmpeg executeWithArguments:self.arguments];
    if(self.resultBlock){
        self.resultBlock(result);
    }
}

- (void)cancel{
    [super cancel];
    [MobileFFmpeg cancel];
}

+ (BOOL)isReturnCodeCancel:(int)code{
    return code == RETURN_CODE_CANCEL;
}

+ (BOOL)isReturnCodeSuccess:(int)code{
    return code == RETURN_CODE_SUCCESS;
}

@end


@implementation RDMobileFFmpegDelegate

+ (instancetype)sharedDelegate{
    static dispatch_once_t onceToken;
    static RDMobileFFmpegDelegate *sharedDelegate;
    dispatch_once(&onceToken, ^{
        sharedDelegate = [RDMobileFFmpegDelegate new];
    });
    return sharedDelegate;
}

- (instancetype)init{
    self = [super init];
    if(self){
        [MobileFFmpegConfig setStatisticsDelegate:self];
        [MobileFFmpegConfig setLogDelegate:self];
        [MobileFFmpegConfig enableRedirection];
        self.statisticsDelegates = (NSHashTable <RDMobileFFmpegStatisticsDelegate> *)[NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (void)logCallback:(long)executionId :(int)level :(NSString*)message{
    log4Debug(@"level: %@, message: %@",@(level),message);
}

- (void)statisticsCallback:(Statistics *)statistics{
    @synchronized (self.statisticsDelegates) {
        NSArray *delegates = [self.statisticsDelegates allObjects];
        for (id<RDMobileFFmpegStatisticsDelegate> delegate in delegates) {
            [delegate statisticsCallback:statistics];
        }
    }
}

- (void)addStatisticsDelegate:(id<RDMobileFFmpegStatisticsDelegate>)statisticsDelegate{
    if(statisticsDelegate == nil){
        return;
    }
    @synchronized (self.statisticsDelegates) {
        [self.statisticsDelegates addObject:statisticsDelegate];
    }
}

- (void)removeStatisticsDelegate:(id<RDMobileFFmpegStatisticsDelegate>)statisticsDelegate{
    if(statisticsDelegate == nil){
        return;
    }
    @synchronized (self.statisticsDelegates) {
        [self.statisticsDelegates removeObject:statisticsDelegate];
    }
}

@end
