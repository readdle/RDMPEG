//
//  RDMPEGFrames.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <UIKit/UIKit.h>



NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, RDMPEGFrameType) {
    RDMPEGFrameTypeAudio,
    RDMPEGFrameTypeVideo,
    RDMPEGFrameTypeArtwork,
    RDMPEGFrameTypeSubtitle
};

typedef NS_ENUM(NSUInteger, RDMPEGVideoFrameFormat) {
    RDMPEGVideoFrameFormatRGB,
    RDMPEGVideoFrameFormatYUV,
};



@interface RDMPEGFrame : NSObject

@property (nonatomic, readonly) RDMPEGFrameType type;
@property (nonatomic, readonly) NSTimeInterval position;
@property (nonatomic, readonly) NSTimeInterval duration;

@end



@interface RDMPEGAudioFrame : RDMPEGFrame

@property (nonatomic, readonly) NSData *samples;

@end



@interface RDMPEGVideoFrame : RDMPEGFrame

@property (nonatomic, readonly) RDMPEGVideoFrameFormat format;
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;

@end



@interface RDMPEGVideoFrameRGB : RDMPEGVideoFrame

@property (nonatomic, readonly) NSUInteger linesize;
@property (nonatomic, readonly) NSData *rgb;

- (nullable UIImage *)asImage;

@end



@interface RDMPEGVideoFrameYUV : RDMPEGVideoFrame

@property (nonatomic, readonly) NSData *luma;
@property (nonatomic, readonly) NSData *chromaB;
@property (nonatomic, readonly) NSData *chromaR;

@end



@interface RDMPEGArtworkFrame : RDMPEGFrame

@property (nonatomic, readonly) NSData *picture;

- (nullable UIImage *)asImage;

@end



@interface RDMPEGSubtitleFrame : RDMPEGFrame

@property (nonatomic, readonly) NSString *text;

@end

NS_ASSUME_NONNULL_END

