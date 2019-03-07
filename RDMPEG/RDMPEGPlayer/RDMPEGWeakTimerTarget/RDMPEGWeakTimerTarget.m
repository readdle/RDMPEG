//
//  RDMPEGWeakTimerTarget.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/2/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGWeakTimerTarget.h"



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGWeakTimerTarget ()

@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL action;

@end



@implementation RDMPEGWeakTimerTarget

#pragma mark - Lifecycle

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    self = [super init];
    if (self) {
        self.target = target;
        self.action = action;
    }
    return self;
}

#pragma mark - Public Methods

- (void)timerFired:(NSTimer *)timer {
    _Pragma("clang diagnostic push")
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"")
    
    [self.target performSelector:self.action withObject:timer];
    
    _Pragma("clang diagnostic pop")
}

@end

NS_ASSUME_NONNULL_END
