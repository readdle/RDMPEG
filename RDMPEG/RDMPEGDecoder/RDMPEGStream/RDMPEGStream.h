//
//  RDMPEGStream.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/23/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGStream : NSObject

@property (nonatomic, readonly, nullable) NSString *languageCode;
@property (nonatomic, readonly, nullable) NSString *info;
@property (nonatomic, readonly, getter=isCanBeDecoded) BOOL canBeDecoded;

@end

NS_ASSUME_NONNULL_END
