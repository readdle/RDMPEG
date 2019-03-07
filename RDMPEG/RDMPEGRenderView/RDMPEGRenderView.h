//
//  RDMPEGRenderView.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RDMPEGVideoFrame;
@protocol RDMPEGRenderer;



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGRenderView : UIView

@property (nonatomic, readonly) CGRect videoFrame;
@property (nonatomic, readonly) CGRect aspectFitVideoFrame;
@property (nonatomic, assign, getter=isAspectFillMode) BOOL aspectFillMode;

- (instancetype)initWithFrame:(CGRect)frame
                     renderer:(id<RDMPEGRenderer>)renderer
                   frameWidth:(NSUInteger)frameWidth
                  frameHeight:(NSUInteger)frameHeight;

- (void)render:(nullable RDMPEGVideoFrame *)videoFrame;

@end

NS_ASSUME_NONNULL_END
