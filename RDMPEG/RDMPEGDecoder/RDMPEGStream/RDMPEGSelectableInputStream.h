//
//  RDMPEGSelectableInputStream.h
//  RDMPEG
//
//  Created by Artem on 24.07.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGSelectableInputStream : NSObject

@property (nonatomic, copy, nullable) NSString *title;

@property (nonatomic, copy, nullable) NSString *inputName;

@end

NS_ASSUME_NONNULL_END
