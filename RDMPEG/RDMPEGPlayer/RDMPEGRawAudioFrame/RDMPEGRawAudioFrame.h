//
//  RDMPEGRawAudioFrame.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/7/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRawAudioFrame : NSObject

@property (nonatomic, readonly) NSData *rawAudioData;
@property (nonatomic, assign) NSUInteger rawAudioDataOffset;

- (instancetype)initWithRawAudioData:(NSData *)rawAudioData;

@end

NS_ASSUME_NONNULL_END
