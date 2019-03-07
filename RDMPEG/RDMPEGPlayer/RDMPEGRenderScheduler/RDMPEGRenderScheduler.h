//
//  RDMPEGRenderScheduler.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/8/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

typedef NSDate * _Nullable (^RDMPEGRenderSchedulerCallback)();



@interface RDMPEGRenderScheduler : NSObject

@property (nonatomic, readonly, getter=isScheduling) BOOL scheduling;

- (void)startWithCallback:(RDMPEGRenderSchedulerCallback)callback;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
