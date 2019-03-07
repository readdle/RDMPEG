//
//  RDMPEGWeakTimerTarget.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/2/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGWeakTimerTarget : NSObject

@property (nonatomic, readonly, weak) id target;
@property (nonatomic, readonly) SEL action;

- (instancetype)initWithTarget:(id)target action:(SEL)action;

- (void)timerFired:(NSTimer *)timer;

@end

NS_ASSUME_NONNULL_END
