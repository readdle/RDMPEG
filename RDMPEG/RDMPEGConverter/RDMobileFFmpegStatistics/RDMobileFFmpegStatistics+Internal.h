//
//  RDMobileFFmpegStatistics+Internal.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 28.08.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "RDMobileFFmpegStatistics.h"

@class Statistics;



NS_ASSUME_NONNULL_BEGIN

@interface RDMobileFFmpegStatistics (Internal)

- (instancetype)initWithStatistics:(Statistics *)statistics;

@end

NS_ASSUME_NONNULL_END
