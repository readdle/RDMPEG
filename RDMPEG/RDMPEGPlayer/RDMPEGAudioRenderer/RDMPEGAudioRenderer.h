//
//  RDMPEGAudioRenderer.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/13/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

typedef void (^RDMPEGAudioRendererOutputCallback)(float *data, UInt32 numFrames, UInt32 numChannels);



@interface RDMPEGAudioRenderer : NSObject

@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) double samplingRate;
@property (nonatomic, readonly) NSUInteger outputChannelsCount;

- (BOOL)playWithOutputCallback:(RDMPEGAudioRendererOutputCallback)outputCallback;
- (BOOL)pause;

@end

NS_ASSUME_NONNULL_END
