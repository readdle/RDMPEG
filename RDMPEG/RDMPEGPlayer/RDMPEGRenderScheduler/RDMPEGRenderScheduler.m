//
//  RDMPEGRenderScheduler.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/8/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGRenderScheduler.h"
#import <Log4Cocoa/Log4Cocoa.h>

#import <RDMPEG/RDMPEG-Swift.h>


NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRenderScheduler ()

@property (nonatomic, strong, nullable) NSTimer *timer;
@property (nonatomic, strong, nullable) RDMPEGRenderSchedulerCallback callback;

@end



@implementation RDMPEGRenderScheduler

#pragma mark - Overridden Class Methods

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGRenderScheduler"];
}

#pragma mark - Lifecycle

- (void)dealloc {
    [self stop];
}

#pragma mark - Public Accessors

- (BOOL)isScheduling {
    return self.timer != nil;
}

#pragma mark - Public Methods

- (void)startWithCallback:(RDMPEGRenderSchedulerCallback)callback {
    if (self.isScheduling) {
        log4Assert(NO, @"Already scheduling");
        return;
    }
    
    self.callback = callback;
    
    
    RDMPEGWeakTimerTarget *timerTarget = [[RDMPEGWeakTimerTarget alloc] initWithTarget:self action:@selector(renderTimerFired:)];
    self.timer = [NSTimer timerWithTimeInterval:0.0 target:timerTarget selector:@selector(timerFired:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stop {
    if (self.isScheduling == NO) {
        return;
    }
    
    [self.timer invalidate];
    self.timer = nil;
    
    self.callback = nil;
}

#pragma mark - Timer

- (void)renderTimerFired:(NSTimer *)timer {
    @autoreleasepool {
        NSDate *nextFireDate = self.callback();
        if (nextFireDate == nil) {
            nextFireDate = [NSDate dateWithTimeIntervalSinceNow:0.01];
        }
        timer.fireDate = nextFireDate;
    }
}

@end

NS_ASSUME_NONNULL_END
