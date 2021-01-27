//
//  RDMPEGFrames+Decoder.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/3/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGFrames.h"



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGFrame (Decoder)

@property (nonatomic, assign) NSTimeInterval position;
@property (nonatomic, assign) NSTimeInterval duration;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration;

@end



@interface RDMPEGAudioFrame (Decoder)

@property (nonatomic, strong) NSData *samples;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration
                         samples:(NSData *)samples;

@end



@interface RDMPEGVideoFrame (Decoder)

@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, assign) NSUInteger height;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration
                           width:(NSUInteger)width
                          height:(NSUInteger)height;

@end



@interface RDMPEGVideoFrameBGRA (Decoder)

@property (nonatomic, assign) NSUInteger linesize;
@property (nonatomic, strong) NSData *bgra;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration
                           width:(NSUInteger)width
                          height:(NSUInteger)height
                            bgra:(NSData *)bgra
                        linesize:(NSUInteger)linesize;

@end



@interface RDMPEGVideoFrameYUV (Decoder)

@property (nonatomic, strong) NSData *luma;
@property (nonatomic, strong) NSData *chromaB;
@property (nonatomic, strong) NSData *chromaR;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration
                           width:(NSUInteger)width
                          height:(NSUInteger)height
                            luma:(NSData *)luma
                         chromaB:(NSData *)chromaB
                         chromaR:(NSData *)chromaR;

@end



@interface RDMPEGArtworkFrame (Decoder)

@property (nonatomic, strong) NSData *picture;

- (instancetype)initWithPicture:(NSData *)picture;

@end



@interface RDMPEGSubtitleFrame (Decoder)

@property (nonatomic, strong) NSString *text;

- (instancetype)initWithPosition:(NSTimeInterval)position
                        duration:(NSTimeInterval)duration
                            text:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
