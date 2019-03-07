//
//  RDMPEGAudioRenderer.m
//  RDMPEG
//
//  Created by Serhii Alpieiev on 9/13/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDMPEGAudioRenderer.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <Log4Cocoa/Log4Cocoa.h>



NS_ASSUME_NONNULL_BEGIN

static const NSUInteger RDMPEGAudioRendererMaxFrameSize = 4096;
static const NSUInteger RDMPEGAudioRendererMaxChannelsCount = 2;



static OSStatus audioRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList * __nullable ioData);



@interface RDMPEGAudioRenderer ()

@property (nonatomic, assign, nullable) AudioUnit audioUnit;
@property (nonatomic, strong, nullable) RDMPEGAudioRendererOutputCallback outputCallback;
@property (nonatomic, assign, nullable) float *outputData;
@property (nonatomic, assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic, assign) NSUInteger bytesPerSample;
@property (nonatomic, assign) NSUInteger outputChannelsCount;
@property (nonatomic, assign, getter=isAudioUnitStarted) BOOL audioUnitStarted;
@property (nonatomic, assign, getter=isPlaying) BOOL playing;
@property (nonatomic, assign) double samplingRate;

@end



@implementation RDMPEGAudioRenderer

#pragma mark - Overridden Class Methods

+ (L4Logger *)l4Logger {
    return [L4Logger loggerForName:@"rd.mediaplayer.RDMPEGPlayer"];
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        self.outputData = (float *)calloc(RDMPEGAudioRendererMaxFrameSize * RDMPEGAudioRendererMaxChannelsCount, sizeof(float));
        
        self.samplingRate = [AVAudioSession sharedInstance].sampleRate;
        self.audioUnitStarted = [self startAudioUnit];
    }
    return self;
}

- (void)dealloc {
    [self stopAudioUnit];
    
    free(self.outputData);
    self.outputData = nil;
}

#pragma mark - Public Methods

- (BOOL)playWithOutputCallback:(RDMPEGAudioRendererOutputCallback)outputCallback {
    if (self.isPlaying) {
        log4Assert(NO, @"Already playing");
        return NO;
    }
    
    if (self.audioUnit == nil) {
        log4Assert(NO, @"Audio unit doesn't exist");
        return NO;
    }
    
    self.outputCallback = outputCallback;
    
    OSStatus startStatus = AudioOutputUnitStart(self.audioUnit);
    log4Assert(startStatus == noErr, @"Unable to start audio unit with error: %d", (int)startStatus);
    
    if (startStatus == noErr) {
        self.playing = YES;
    }
    
    return self.isPlaying;
}

- (BOOL)pause {
    if (self.isPlaying == NO) {
        return YES;
    }
    
    if (self.audioUnit == nil) {
        log4Assert(NO, @"Audio unit doesn't exist");
        return YES;
    }
    
    OSStatus stopStatus = AudioOutputUnitStop(self.audioUnit);
    log4Assert(stopStatus == noErr, @"Unable to stop audio unit with error: %d", (int)stopStatus);
    
    if (stopStatus == noErr) {
        self.playing = NO;
        self.outputCallback = nil;
        return YES;
    }
    
    return NO;
}

#pragma mark - Private Methods

- (BOOL)startAudioUnit {
    NSError *categoryError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];
    log4Assert(categoryError == nil, @"Audio setCategory error: %@", categoryError);
    
    NSError *activationError = nil;
    [[AVAudioSession sharedInstance] setActive:YES error:&activationError];
    log4Assert(activationError == nil, @"Audio setActive error: %@", activationError);
    
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_RemoteIO;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    
    OSStatus audioUnitStatus = AudioComponentInstanceNew(component, &_audioUnit);
    if (audioUnitStatus != noErr) {
        log4Assert(NO, @"Couldn't create the output audio unit with error: %d", (int)audioUnitStatus);
        self.audioUnit = nil;
        return NO;
    }
    
    UInt32 formatSize = sizeof(AudioStreamBasicDescription);
    OSStatus outputGetFormatStatus = AudioUnitGetProperty(self.audioUnit,
                                                          kAudioUnitProperty_StreamFormat,
                                                          kAudioUnitScope_Input,
                                                          0,
                                                          &_outputFormat,
                                                          &formatSize);
    
    if (outputGetFormatStatus != noErr) {
        log4Assert(NO, @"Couldn't get the hardware output stream format with error: %d", (int)outputGetFormatStatus);
        [self disposeAudioUnit];
        return NO;
    }
    
    _outputFormat.mSampleRate = self.samplingRate;
    
    OSStatus outputSetFormatStatus = AudioUnitSetProperty(self.audioUnit,
                                                          kAudioUnitProperty_StreamFormat,
                                                          kAudioUnitScope_Input,
                                                          0,
                                                          &_outputFormat,
                                                          formatSize);
    
    if (outputSetFormatStatus != noErr) {
        log4Assert(NO, @"Couldn't set the hardware output stream format with error: %d", (int)outputSetFormatStatus);
    }
    
    self.bytesPerSample = _outputFormat.mBitsPerChannel / 8;
    self.outputChannelsCount = _outputFormat.mChannelsPerFrame;
    
    log4Debug(@"Bytes per sample: %d", (int)self.bytesPerSample);
    log4Debug(@"Output channels: %d", (int)self.outputChannelsCount);
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = audioRenderCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    
    OSStatus renderCallbacStatus = AudioUnitSetProperty(self.audioUnit,
                                                        kAudioUnitProperty_SetRenderCallback,
                                                        kAudioUnitScope_Input,
                                                        0,
                                                        &callbackStruct,
                                                        sizeof(callbackStruct));
    if (renderCallbacStatus != noErr) {
        log4Assert(NO, @"Couldn't set the render callback on the audio unit with error: %d", (int)renderCallbacStatus);
        [self disposeAudioUnit];
        return NO;
    }
    
    OSStatus initializeStatus = AudioUnitInitialize(self.audioUnit);
    if (initializeStatus != noErr) {
        log4Assert(NO, @"Couldn't initialize the audio unit with error: %d", (int)initializeStatus);
        [self disposeAudioUnit];
        return NO;
    }
    
    return YES;
}

- (BOOL)stopAudioUnit {
    if (self.audioUnit == nil) {
        return YES;
    }
    
    [self pause];
    
    if ([self uninitializeAudioUnit] && [self disposeAudioUnit]) {
        return YES;
    }
    
    return NO;
}

- (BOOL)uninitializeAudioUnit {
    if (self.audioUnit == nil) {
        return YES;
    }
    
    OSStatus uninitializeStatus = AudioUnitUninitialize(self.audioUnit);
    if (uninitializeStatus != noErr) {
        log4Assert(NO, @"Unable to uninitialize audio unit with error: %d", (int)uninitializeStatus);
        return NO;
    }
    
    return YES;
}

- (BOOL)disposeAudioUnit {
    if (self.audioUnit == nil) {
        return YES;
    }
    
    OSStatus disposeStatus = AudioComponentInstanceDispose(self.audioUnit);
    if (disposeStatus != noErr) {
        log4Assert(NO, @"Unable to dispose audio unit with error: %d", (int)disposeStatus);
        return NO;
    }
    
    self.audioUnit = nil;
    self.bytesPerSample = 0;
    self.outputChannelsCount = 0;
    
    self.outputFormat = (AudioStreamBasicDescription) {
        .mSampleRate = 0.0,
        .mFormatID = 0,
        .mFormatFlags = 0,
        .mBytesPerPacket = 0,
        .mFramesPerPacket = 0,
        .mBytesPerFrame = 0,
        .mChannelsPerFrame = 0,
        .mBitsPerChannel = 0,
        .mReserved = 0
    };
    
    return YES;
}

- (void)renderFrames:(UInt32)numFrames ioData:(AudioBufferList *)ioData {
    log4Assert(self.audioUnit, @"Audio unit doesn't exist");
    log4Assert(self.outputCallback, @"Render callback not specified");
    
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    if (self.audioUnit == NO || self.outputCallback == nil) {
        return;
    }
    
    self.outputCallback(self.outputData, numFrames, (UInt32)self.outputChannelsCount);
    
    // Put the rendered data into the output buffer
    if (self.bytesPerSample == 4) // then we've already got floats
    {
        float zero = 0.0;
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
            
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                vDSP_vsadd(self.outputData+iChannel, self.outputChannelsCount, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, numFrames);
            }
        }
    }
    else if (self.bytesPerSample == 2) // then we need to convert SInt16 -> Float (and also scale)
    {
        float scale = (float)INT16_MAX;
        vDSP_vsmul(self.outputData, 1, &scale, self.outputData, 1, numFrames*self.outputChannelsCount);
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
            
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                vDSP_vfix16(self.outputData+iChannel, self.outputChannelsCount, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
            }
        }
    }
}

@end



static OSStatus audioRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList * __nullable ioData) {
    RDMPEGAudioRenderer *audioRenderer = (__bridge RDMPEGAudioRenderer *)inRefCon;
    [audioRenderer renderFrames:inNumberFrames ioData:ioData];
    
    return noErr;
}

NS_ASSUME_NONNULL_END
