//
//  RDMobileFFmpegUtils.h
//  RDMPEG
//
//  Created by Artem on 25.08.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RDMobileFFmpegUtils : NSObject

+ (int64_t)getDurationForLocalFileAtPath:(NSString *)localFilePath;

@end

NS_ASSUME_NONNULL_END
