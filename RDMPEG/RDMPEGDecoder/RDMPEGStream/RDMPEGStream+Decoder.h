//
//  RDMPEGStream+Decoder.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 10/23/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGStream.h"
#import <libavformat/avformat.h>



NS_ASSUME_NONNULL_BEGIN

@interface RDMPEGStream (Decoder)

@property (nonatomic, assign) AVStream *stream;
@property (nonatomic, assign) NSUInteger streamIndex;
@property (nonatomic, assign, nullable) AVCodec *codec;
@property (nonatomic, assign, nullable) AVCodecContext *codecContext;
@property (nonatomic, strong, nullable) NSString *subtitleEncoding;

- (instancetype)initWithStream:(AVStream *)stream atIndex:(NSUInteger)streamIndex;

- (BOOL)openCodec;
- (void)closeCodec;

@end

NS_ASSUME_NONNULL_END
