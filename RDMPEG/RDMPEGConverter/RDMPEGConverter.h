//
//  RDMPEGConverter.h
//  RDMPEG
//
//  Created by Igor Fedorov on 10.06.2019.
//  Copyright © 2019 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol RDMPEGConverterDelegate <NSObject>

- (void)converterDidChangeProgress:(float)progress;

@end

@interface RDMPEGConverter : NSObject

+ (instancetype)sharedConverter;

@property (nonatomic,weak)id<RDMPEGConverterDelegate> delegate;

- (NSString *)convertToMP3FileAtPath:(NSString *)inputFilePath;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
