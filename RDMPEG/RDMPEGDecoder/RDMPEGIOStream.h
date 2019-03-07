//
//  RDMPEGIOStream.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

@protocol RDMPEGIOStream <NSObject>

@required

- (BOOL)open;
- (void)close;

- (NSInteger)readBuffer:(Byte *)buffer length:(NSInteger)length;
- (NSInteger)writeBuffer:(Byte *)buffer length:(NSInteger)length;
- (unsigned long long)seekOffset:(unsigned long long)offset whence:(NSInteger)whence;


@optional

- (unsigned long long)contentLength;

@end

NS_ASSUME_NONNULL_END
