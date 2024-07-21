//
//  RDMPEGAudioRenderer.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 16/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate
import Log4Cocoa

class RDMPEGAudioRenderer: NSObject {
    public typealias OutputCallback = (_ data: UnsafeMutablePointer<Float>, _ numFrames: UInt32, _ numChannels: UInt32) -> Void

    private static let maxFrameSize: Int = 4096
    private static let maxChannelsCount: Int = 2

    private(set) var isPlaying: Bool = false
    private(set) var samplingRate: Double
    private(set) var outputChannelsCount: Int = 0

    private var audioUnit: AudioUnit?
    private var outputCallback: OutputCallback?
    private var outputData: UnsafeMutablePointer<Float>?
    private var outputFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
    private var bytesPerSample: Int = 0
    private var audioUnitStarted: Bool = false

    override public init() {
        self.samplingRate = AVAudioSession.sharedInstance().sampleRate
        self.outputData = UnsafeMutablePointer<Float>.allocate(capacity: RDMPEGAudioRenderer.maxFrameSize * RDMPEGAudioRenderer.maxChannelsCount)
        super.init()

        self.outputData?.initialize(repeating: 0, count: RDMPEGAudioRenderer.maxFrameSize * RDMPEGAudioRenderer.maxChannelsCount)
        self.audioUnitStarted = startAudioUnit()
    }

    deinit {
        _ = stopAudioUnit()
        outputData?.deallocate()
        outputData = nil
    }

    func play(withOutputCallback outputCallback: @escaping OutputCallback) -> Bool {
        guard !isPlaying, let audioUnit = audioUnit else {
            log4Assert(false, "Already playing or Audio unit doesn't exist")
            return false
        }

        self.outputCallback = outputCallback

        let startStatus = AudioOutputUnitStart(audioUnit)
        log4Assert(startStatus == noErr, "Unable to start audio unit with error: \(startStatus)")

        if startStatus == noErr {
            isPlaying = true
        }

        return isPlaying
    }

    func pause() -> Bool {
        guard isPlaying, let audioUnit = audioUnit else {
            return true
        }

        let stopStatus = AudioOutputUnitStop(audioUnit)
        log4Assert(stopStatus == noErr, "Unable to stop audio unit with error: \(stopStatus)")

        if stopStatus == noErr {
            isPlaying = false
            outputCallback = nil
            return true
        }

        return false
    }

    private func startAudioUnit() -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            log4Assert(false, "Audio session error: \(error)")
            return false
        }

        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_RemoteIO,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0)

        guard let component = AudioComponentFindNext(nil, &description) else {
            log4Assert(false, "Couldn't find the output audio unit")
            return false
        }

        var status = AudioComponentInstanceNew(component, &audioUnit)
        guard status == noErr, let audioUnit = audioUnit else {
            log4Assert(false, "Couldn't create the output audio unit with error: \(status)")
            return false
        }

        var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioUnitGetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      0,
                                      &outputFormat,
                                      &formatSize)

        guard status == noErr else {
            log4Assert(false, "Couldn't get the hardware output stream format with error: \(status)")
            _ = disposeAudioUnit()
            return false
        }

        outputFormat.mSampleRate = samplingRate

        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      0,
                                      &outputFormat,
                                      formatSize)

        if status != noErr {
            log4Assert(false, "Couldn't set the hardware output stream format with error: \(status)")
        }

        bytesPerSample = Int(outputFormat.mBitsPerChannel / 8)
        outputChannelsCount = Int(outputFormat.mChannelsPerFrame)

        log4Debug("Bytes per sample: \(bytesPerSample)")
        log4Debug("Output channels: \(outputChannelsCount)")

        var callbackStruct = AURenderCallbackStruct(
            inputProc: audioRenderCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Input,
                                      0,
                                      &callbackStruct,
                                      UInt32(MemoryLayout<AURenderCallbackStruct>.size))

        guard status == noErr else {
            log4Assert(false, "Couldn't set the render callback on the audio unit with error: \(status)")
            _ = disposeAudioUnit()
            return false
        }

        status = AudioUnitInitialize(audioUnit)
        guard status == noErr else {
            log4Assert(false, "Couldn't initialize the audio unit with error: \(status)")
            _ = disposeAudioUnit()
            return false
        }

        return true
    }

    private func stopAudioUnit() -> Bool {
        guard audioUnit != nil else { return true }

        _ = pause()

        return uninitializeAudioUnit() && disposeAudioUnit()
    }

    private func uninitializeAudioUnit() -> Bool {
        guard let audioUnit = audioUnit else { return true }

        let uninitializeStatus = AudioUnitUninitialize(audioUnit)
        if uninitializeStatus != noErr {
            log4Assert(false, "Unable to uninitialize audio unit with error: \(uninitializeStatus)")
            return false
        }

        return true
    }

    private func disposeAudioUnit() -> Bool {
        guard let audioUnit = audioUnit else { return true }

        let disposeStatus = AudioComponentInstanceDispose(audioUnit)
        if disposeStatus != noErr {
            log4Assert(false, "Unable to dispose audio unit with error: \(disposeStatus)")
            return false
        }

        self.audioUnit = nil
        bytesPerSample = 0
        outputChannelsCount = 0

        outputFormat = AudioStreamBasicDescription()

        return true
    }

    fileprivate func renderFrames(_ numFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>) {
        log4Assert(audioUnit != nil, "Audio unit doesn't exist")
        log4Assert(outputCallback != nil, "Render callback not specified")

        for iBuffer in 0..<Int(ioData.pointee.mNumberBuffers) {
            let buffer = UnsafeMutableAudioBufferListPointer(ioData)[iBuffer]
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }

        guard audioUnit != nil, let outputCallback = outputCallback, let outputData = outputData else { return }

        outputCallback(outputData, numFrames, UInt32(outputChannelsCount))

        // Put the rendered data into the output buffer
        if bytesPerSample == 4 { // then we've already got floats
            var zero: Float = 0.0

            for iBuffer in 0..<Int(ioData.pointee.mNumberBuffers) {
                let buffer = UnsafeMutableAudioBufferListPointer(ioData)[iBuffer]
                let thisNumChannels = Int(buffer.mNumberChannels)

                for iChannel in 0..<thisNumChannels {
                    if let bufferAdvanced = buffer.mData?.assumingMemoryBound(to: Float.self).advanced(by: iChannel) {
                        vDSP_vsadd(outputData.advanced(by: iChannel),
                                   vDSP_Stride(outputChannelsCount),
                                   &zero,
                                   bufferAdvanced,
                                   vDSP_Stride(thisNumChannels),
                                   vDSP_Length(numFrames))
                    }
                }
            }
        } else if bytesPerSample == 2 {  // then we need to convert SInt16 -> Float (and also scale)
            var scale: Float = Float(Int16.max)
            vDSP_vsmul(outputData, 1, &scale, outputData, 1, vDSP_Length(numFrames) * vDSP_Length(outputChannelsCount))

            for iBuffer in 0..<Int(ioData.pointee.mNumberBuffers) {
                let buffer = UnsafeMutableAudioBufferListPointer(ioData)[iBuffer]
                let thisNumChannels = Int(buffer.mNumberChannels)

                for iChannel in 0..<thisNumChannels {
                    if let bufferAdvanced = buffer.mData?.assumingMemoryBound(to: Int16.self).advanced(by: iChannel) {
                        vDSP_vfix16(outputData.advanced(by: iChannel),
                                    vDSP_Stride(outputChannelsCount),
                                    bufferAdvanced,
                                    vDSP_Stride(thisNumChannels),
                                    vDSP_Length(numFrames))
                    }
                }
            }
        }
    }
}

private func audioRenderCallback(inRefCon: UnsafeMutableRawPointer,
                                 ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                                 inTimeStamp: UnsafePointer<AudioTimeStamp>,
                                 inBusNumber: UInt32,
                                 inNumberFrames: UInt32,
                                 ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    let audioRenderer = Unmanaged<RDMPEGAudioRenderer>.fromOpaque(inRefCon).takeUnretainedValue()
    if let ioData = ioData {
        audioRenderer.renderFrames(inNumberFrames, ioData: ioData)
    }
    return noErr
}

extension RDMPEGAudioRenderer {
    override class func l4Logger() -> L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGPlayer")
    }
}
