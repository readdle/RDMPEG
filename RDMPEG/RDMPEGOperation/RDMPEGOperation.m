//
//  RDMPEGOperation.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 27.08.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "RDMPEGOperation.h"
#import "RDMPEGOperation+Protected.h"


// Implementation is taken here: https://developer.apple.com/library/archive/documentation/General/Conceptual/ConcurrencyProgrammingGuide/OperationObjects/OperationObjects.html#//apple_ref/doc/uid/TP40008091-CH101-SW8


NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGOperation () {
    BOOL _executing;
    BOOL _finished;
}

@end



@implementation RDMPEGOperation

#pragma mark - Accessors

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _finished;
}

#pragma mark - Overridden

- (void)start {
    if (self.isCancelled) {
        [self willChangeValueForKey:@"isFinished"];
        _finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    [self main];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

#pragma mark - Protected

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
 
    _executing = NO;
    _finished = YES;
 
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

@end

NS_ASSUME_NONNULL_END
