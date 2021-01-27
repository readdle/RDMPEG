//
//  RDMPEGPlayerView.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/13/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <UIKit/UIKit.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGPlayerView : UIView

@property (nonatomic, readonly) CGRect videoFrame;
@property (nonatomic, assign, getter=isAspectFillMode) BOOL aspectFillMode;

@end

NS_ASSUME_NONNULL_END
