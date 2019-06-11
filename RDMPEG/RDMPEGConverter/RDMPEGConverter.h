//
//  RDMPEGConverter.h
//  RDMPEG
//
//  Created by Igor Fedorov on 10.06.2019.
//  Copyright © 2019 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGConverter : NSObject

- (instancetype)initWithFileAtPath:(NSString *)filePath;
- (NSString *)convertToMP3;
- (void)cancel;
- (NSString *)errorOutput;

@end

NS_ASSUME_NONNULL_END
