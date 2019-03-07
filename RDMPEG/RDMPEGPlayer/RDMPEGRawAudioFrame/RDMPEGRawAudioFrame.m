//
//  RDMPEGRawAudioFrame.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/7/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGRawAudioFrame.h"



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRawAudioFrame ()

@property (nonatomic, strong) NSData *rawAudioData;

@end



@implementation RDMPEGRawAudioFrame

#pragma mark - Lifecycle

- (instancetype)initWithRawAudioData:(NSData *)rawAudioData {
    self = [super init];
    if (self) {
        self.rawAudioData = rawAudioData;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
