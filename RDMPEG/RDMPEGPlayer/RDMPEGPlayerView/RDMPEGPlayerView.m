//
//  RDMPEGPlayerView.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/13/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGPlayerView.h"
#import "RDMPEGRenderView.h"
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGPlayerView ()

@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong, nullable) RDMPEGRenderView *renderView;
@property (nonatomic, strong, nullable) NSString *subtitle;

@end



@implementation RDMPEGPlayerView

#pragma mark - Overridden Class Methods

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGPlayerView"];
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.subtitleLabel = [[UILabel alloc] init];
        self.subtitleLabel.numberOfLines = 0;
        self.subtitleLabel.textColor = [UIColor whiteColor];
        self.subtitleLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        self.subtitleLabel.clipsToBounds = YES;
        self.subtitleLabel.layer.cornerRadius = 2.0;
        [self addSubview:self.subtitleLabel];
    }
    return self;
}

#pragma mark - Overridden

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (self.subtitleLabel.text.length == 0) {
        self.subtitleLabel.frame = CGRectZero;
    }
    else {
        const CGFloat horisontalSubtitleOffset = 10.0;
        const CGFloat verticalSubtitleOffset = 10.0;
        
        CGRect aspectFitVideoFrame = self.renderView.aspectFitVideoFrame;
        
        CGFloat subtitleMinX = CGRectGetMinX(aspectFitVideoFrame) + horisontalSubtitleOffset;
        CGFloat subtitleMaxY = CGRectGetMaxY(aspectFitVideoFrame) - verticalSubtitleOffset;
        CGFloat subtitleMaxWidth = CGRectGetWidth(aspectFitVideoFrame) - horisontalSubtitleOffset * 2.0;
        CGFloat subtitleMaxHeight = CGRectGetHeight(aspectFitVideoFrame) - verticalSubtitleOffset * 2.0;
        CGSize subtitleFitSize = CGSizeMake(subtitleMaxWidth, subtitleMaxHeight);
        
        CGSize subtitleSize = [self.subtitleLabel sizeThatFits:subtitleFitSize];
        
        CGRect subtitleFrame = CGRectMake(subtitleMinX + (subtitleMaxWidth - subtitleSize.width) / 2.0,
                                          subtitleMaxY - subtitleSize.height,
                                          subtitleSize.width,
                                          subtitleSize.height);
        
        self.subtitleLabel.frame = CGRectIntegral(subtitleFrame);
    }
}

#pragma mark - Public Accessors

- (void)setAspectFillMode:(BOOL)aspectFillMode {
    if (_aspectFillMode == aspectFillMode) {
        return;
    }
    
    _aspectFillMode = aspectFillMode;
    
    self.renderView.aspectFillMode = _aspectFillMode;
}

- (void)setRenderView:(nullable RDMPEGRenderView *)renderView {
    if (_renderView == renderView) {
        return;
    }
    
    if (_renderView) {
        if ([_renderView isDescendantOfView:self]) {
            [_renderView removeFromSuperview];
        }
        else {
            log4Assert(NO, @"Content view is not descendant of player view");
        }
    }
    
    _renderView = renderView;
    
    if (_renderView) {
        _renderView.frame = self.bounds;
        _renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _renderView.aspectFillMode = self.isAspectFillMode;
        [self addSubview:_renderView];
        
        [self bringSubviewToFront:self.subtitleLabel];
    }
}

- (CGRect)videoFrame {
    return self.renderView.videoFrame;
}

- (void)setSubtitle:(nullable NSString *)subtitle {
    self.subtitleLabel.text = subtitle;
    
    [self setNeedsLayout];
}

- (nullable NSString *)subtitle {
    return self.subtitleLabel.text;
}

@end

NS_ASSUME_NONNULL_END
