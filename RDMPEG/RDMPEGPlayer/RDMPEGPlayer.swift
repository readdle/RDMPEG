//
//  RDMPEGPlayer.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 18/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa
import ReaddleLib

private let RDMPEGPlayerMinVideoBufferSize: TimeInterval = 0.2
private let RDMPEGPlayerMaxVideoBufferSize: TimeInterval = 1.0
private let RDMPEGPlayerMinAudioBufferSize: TimeInterval = 0.2

private let RDMPEGPlayerInputDecoderKey = "RDMPEGPlayerInputDecoderKey"
private let RDMPEGPlayerInputNameKey = "RDMPEGPlayerInputNameKey"
private let RDMPEGPlayerInputAudioStreamsKey = "RDMPEGPlayerInputAudioStreamsKey"
private let RDMPEGPlayerInputSubtitleStreamsKey = "RDMPEGPlayerInputSubtitleStreamsKey"

@objc
public enum RDMPEGPlayerState: Int {
    case stopped
    case failed
    case paused
    case playing
}

@objc
public protocol RDMPEGPlayerDelegate: AnyObject {
    func mpegPlayerDidPrepareToPlay(_ player: RDMPEGPlayer)
    func mpegPlayer(_ player: RDMPEGPlayer, didChangeState state: RDMPEGPlayerState)
    func mpegPlayer(_ player: RDMPEGPlayer, didChangeBufferingState state: RDMPEGPlayerState)
    func mpegPlayer(_ player: RDMPEGPlayer, didUpdateCurrentTime currentTime: TimeInterval)
    func mpegPlayerDidAttachInput(_ player: RDMPEGPlayer)
    func mpegPlayerDidFinishPlaying(_ player: RDMPEGPlayer)
}

@objc
public class RDMPEGPlayer: NSObject {
    @objc public private(set) var playerView: RDMPEGPlayerView
    @objc public var state: RDMPEGPlayerState { internalState }
    @objc public private(set) var error: Error?
    @objc public private(set) var audioStreams: [RDMPEGSelectableInputStream]?
    @objc public private(set) var subtitleStreams: [RDMPEGSelectableInputStream]?
    @objc public private(set) var activeAudioStreamIndex: NSNumber?
    @objc public private(set) var activeSubtitleStreamIndex: NSNumber?
    @objc public var currentTime: TimeInterval { currentInternalTime }
    @objc public private(set) var duration: TimeInterval
    @objc public private(set) var isBuffering: Bool
    @objc public private(set) var isSeeking: Bool
    @objc public var timeObservingInterval: TimeInterval {
        didSet {
            if timeObservingInterval != oldValue {
                if timeObservingTimer != nil {
                    stopTimeObservingTimer()
                    startTimeObservingTimer()
                }
            }
        }
    }
    @objc public var isDeinterlacingEnabled: Bool {
        didSet {
            if isDeinterlacingEnabled != oldValue {
                decodingQueue.addOperation { [weak self] in
                    guard let self = self else { return }
                    self.decoder?.isDeinterlacingEnabled = self.isDeinterlacingEnabled
                }
            }
        }
    }
    @objc public weak var delegate: RDMPEGPlayerDelegate?

    private var filePath: String
    private var decodingQueue: OperationQueue
    private var externalInputsQueue: OperationQueue
    private var framebuffer: RDMPEGFramebuffer
    private var audioRenderer: RDMPEGAudioRenderer
    private var stream: RDMPEGIOStream?
    private var decoder: RDMPEGDecoder?
    private var externalAudioDecoder: RDMPEGDecoder?
    private var externalSubtitleDecoder: RDMPEGDecoder?
    private var selectableInputs: [Dictionary<String, Any>]?
    private var scheduler: RDMPEGRenderScheduler?
    private var timeObservingTimer: Timer?
    private var currentSubtitleFrames: [RDMPEGSubtitleFrame]
    private var playingBeforeSeek: Bool = false
    private var rawAudioFrame: RDMPEGRawAudioFrame?
    private var correctionInfo: RDMPEGCorrectionInfo?
    private weak var decodingOperation: Operation?
    private weak var seekOperation: Operation?
    private var internalState: RDMPEGPlayerState = .stopped
    private var currentInternalTime: TimeInterval = 0
    private var preparedToPlay: Bool = false
    private var decodingFinished: Bool = false
    private var videoStreamExist: Bool = false
    private var audioStreamExist: Bool = false
    private var subtitleStreamExist: Bool = false

    @objc
    public init(filePath: String) {
        self.filePath = filePath
        self.stream = nil
        self.decodingQueue = OperationQueue()
        self.externalInputsQueue = OperationQueue()
        self.framebuffer = RDMPEGFramebuffer()
        self.playerView = RDMPEGPlayerView()
        self.audioRenderer = RDMPEGAudioRenderer()
        self.selectableInputs = []
        self.timeObservingInterval = 1.0
        self.currentSubtitleFrames = []
        self.isBuffering = false
        self.isSeeking = false
        self.duration = 0
        self.isDeinterlacingEnabled = false

        super.init()

        self.decodingQueue.name = "RDMPEGPlayer Decoding Queue"
        self.decodingQueue.maxConcurrentOperationCount = 1
        self.externalInputsQueue.name = "RDMPEGPlayer External Inputs Queue"
        self.externalInputsQueue.maxConcurrentOperationCount = 1
    }

    @objc
    public init(filePath: String, stream: RDMPEGIOStream?) {
        self.filePath = filePath
        self.stream = stream
        self.decodingQueue = OperationQueue()
        self.externalInputsQueue = OperationQueue()
        self.framebuffer = RDMPEGFramebuffer()
        self.playerView = RDMPEGPlayerView()
        self.audioRenderer = RDMPEGAudioRenderer()
        self.selectableInputs = []
        self.timeObservingInterval = 1.0
        self.currentSubtitleFrames = []
        self.isBuffering = false
        self.isSeeking = false
        self.duration = 0
        self.isDeinterlacingEnabled = false

        super.init()

        self.decodingQueue.name = "RDMPEGPlayer Decoding Queue"
        self.decodingQueue.maxConcurrentOperationCount = 1
        self.externalInputsQueue.name = "RDMPEGPlayer External Inputs Queue"
        self.externalInputsQueue.maxConcurrentOperationCount = 1
    }

    deinit {
        stopScheduler()
        setAudioOutputEnabled(false)
        stopTimeObservingTimer()
        decodingQueue.cancelAllOperations()
        externalInputsQueue.cancelAllOperations()
    }

    @objc
    public func attachInput(filePath: String, subtitleEncoding: String?, stream: RDMPEGIOStream?) {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        prepareToPlayIfNeeded { [weak self] in
            guard let self = self else { return }

            if self.videoStreamExist == false {
                log4Info("Ignoring external input since video stream doesn't exist")
                return
            }

            self.externalInputsQueue.addOperation { [weak self] in
                guard let self = self else { return }

                let decoder = RDMPEGDecoder(
                    path: filePath,
                    ioStream: stream,
                    subtitleEncoding: subtitleEncoding
                ) { [weak self] in
                    self == nil
                }

                if decoder.openInput() != nil {
                    return
                }

                DispatchQueue.main.sync {
                    let inputFileName = decoder.path.lastPathComponent.deletingPathExtension
                    self.registerSelectableInputFromDecoderIfNeeded(decoder, inputName: inputFileName)
                }
            }
        }
    }

    @objc
    public func play() {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        prepareToPlayIfNeeded { [weak self] in
            guard let self = self else { return }

            if self.internalState != .playing {
                if self.activeAudioStreamIndex != nil {
                    self.setAudioOutputEnabled(true)
                }
                self.startScheduler()
                self.updateStateIfNeededAndNotify(.playing, error: nil)
            }
        }
    }

    @objc
    public func pause() {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        prepareToPlayIfNeeded { [weak self] in
            guard let self = self else { return }

            if self.internalState != .playing {
                return
            }

            self.setAudioOutputEnabled(false)
            self.stopScheduler()

            self.decodingOperation?.cancel()
            self.correctionInfo = nil
            self.rawAudioFrame = nil

            self.setBufferingStateIfNeededAndNotify(false)
            self.updateStateIfNeededAndNotify(.paused, error: nil)
        }
    }

    @objc
    public func beginSeeking() {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        if isSeeking == false {
            isSeeking = true

            if internalState == .playing {
                playingBeforeSeek = true
                pause()
            }
        }
    }

    @objc
    public func seek(to time: TimeInterval) {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        prepareToPlayIfNeeded { [weak self] in
            guard let self = self else { return }

            self.decodingOperation?.cancel()
            self.seekOperation?.cancel()

            let seekOperation = BlockOperation()
            seekOperation.name = "Seek Operation"

            seekOperation.addExecutionBlock { [weak self, weak seekOperation] in
                guard let self = self, let seekOperation = seekOperation else { return }

                self.framebuffer.purge()
                self.rawAudioFrame = nil

                self.moveDecoders(to: time, includingMainDecoder: true)

                self.decodingFinished = self.decoder?.isEndReached ?? false

                self.decodeFrames()

                if self.videoStreamExist {
                    DispatchQueue.main.sync {
                        if self.seekOperation != nil && self.seekOperation != seekOperation {
                            return
                        }

                        _ = self.showNextVideoFrame()

                        self.delegate?.mpegPlayer(self, didUpdateCurrentTime: self.currentInternalTime)
                    }
                }
            }

            self.seekOperation = seekOperation
            self.decodingQueue.addOperation(seekOperation)
        }
    }

    @objc
    public func endSeeking() {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        if isSeeking {
            isSeeking = false

            if playingBeforeSeek {
                playingBeforeSeek = false
                play()
            }
        }
    }

    @objc
    public func activateAudioStream(at streamIndex: NSNumber?) {
        if preparedToPlay == false {
            return
        }

        if (activeAudioStreamIndex == nil && streamIndex == nil) ||
            (streamIndex != nil && activeAudioStreamIndex == streamIndex) {
            return
        }

        activeAudioStreamIndex = streamIndex

        var decoder: RDMPEGDecoder?
        var decoderStreamToActivate: NSNumber?

        if let streamIndex = streamIndex {
            decoder = decoderForStream(
                at: streamIndex,
                streamsKey: RDMPEGPlayerInputAudioStreamsKey,
                decoderStreamIndex: &decoderStreamToActivate
            )
        }

        let samplingRate = audioRenderer.samplingRate
        let outputChannelsCount = audioRenderer.outputChannelsCount

        decodingQueue.addOperation { [weak self] in
            guard let self = self else { return }

            self.framebuffer.purge()
            self.rawAudioFrame = nil

            if self.externalAudioDecoder != nil && self.externalAudioDecoder !== decoder {
                self.externalAudioDecoder?.deactivateAudioStream()
                self.externalAudioDecoder = nil
            }

            if self.decoder === decoder {
                self.decoder?
                    .activateAudioStream(
                        atIndex: decoderStreamToActivate,
                        samplingRate: samplingRate,
                        outputChannels: UInt(outputChannelsCount)
                    )
            }
            else {
                self.decoder?.deactivateAudioStream()

                self.externalAudioDecoder = decoder
                self.externalAudioDecoder?
                    .activateAudioStream(
                        atIndex: decoderStreamToActivate,
                        samplingRate: samplingRate,
                        outputChannels: UInt(outputChannelsCount)
                    )

                self.moveDecoders(to: self.currentInternalTime, includingMainDecoder: false)
            }
        }
    }

    @objc
    public func activateSubtitleStream(at streamIndex: NSNumber?) {
        if preparedToPlay == false {
            return
        }

        if (activeSubtitleStreamIndex == nil && streamIndex == nil) ||
            (streamIndex != nil && activeSubtitleStreamIndex == streamIndex) {
            return
        }

        activeSubtitleStreamIndex = streamIndex

        var decoder: RDMPEGDecoder?
        var decoderStreamToActivate: NSNumber?

        if let streamIndex = streamIndex {
            decoder = decoderForStream(
                at: streamIndex,
                streamsKey: RDMPEGPlayerInputSubtitleStreamsKey,
                decoderStreamIndex: &decoderStreamToActivate
            )
        }

        decodingQueue.addOperation { [weak self] in
            guard let self = self else { return }

            self.framebuffer.purge()

            if self.externalSubtitleDecoder != nil && self.externalSubtitleDecoder !== decoder {
                self.externalSubtitleDecoder?.deactivateSubtitleStream()
                self.externalSubtitleDecoder = nil
            }

            if self.decoder === decoder {
                self.decoder?.activateSubtitleStream(atIndex: decoderStreamToActivate)
            }
            else {
                self.decoder?.deactivateSubtitleStream()

                self.externalSubtitleDecoder = decoder
                self.externalSubtitleDecoder?.activateSubtitleStream(atIndex: decoderStreamToActivate)

                self.moveDecoders(to: self.currentInternalTime, includingMainDecoder: false)
            }
        }
    }

    private func decoderForStream(
        at streamIndex: NSNumber,
        streamsKey: String,
        decoderStreamIndex: UnsafeMutablePointer<NSNumber?>
    ) -> RDMPEGDecoder? {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        var currentStreamIndex = 0
        for selectableInput in selectableInputs ?? [] {
            if let streams = selectableInput[streamsKey] as? [String] {
                for index in 0..<streams.count {
                    if streamIndex.intValue == currentStreamIndex {
                        decoderStreamIndex.pointee = NSNumber(value: index)
                        return selectableInput[RDMPEGPlayerInputDecoderKey] as? RDMPEGDecoder
                    }
                    currentStreamIndex += 1
                }
            }
        }

        log4AssertionFailure("Trying to access non-existent stream")
        return nil
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func prepareToPlayIfNeeded(successCallback: @escaping () -> Void) {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        if preparedToPlay {
            successCallback()
            return
        }

        if internalState == .failed {
            return
        }

        let samplingRate = audioRenderer.samplingRate
        let outputChannelsCount = audioRenderer.outputChannelsCount

        let prepareOperation = BlockOperation()
        prepareOperation.name = "Prepare Operation"

        prepareOperation.addExecutionBlock { [weak self, weak prepareOperation] in
            guard let self = self else { return }

            if self.internalState == .failed {
                return
            }

            var preparedToPlay = self.preparedToPlay
            var justPreparedToPlay = false
            var prepareError: Error?

            if preparedToPlay == false {
                preparedToPlay = self
                    .prepareToPlay(
                        audioSamplingRate: samplingRate,
                        outputChannelsCount: outputChannelsCount,
                        error: &prepareError
                    )

                if preparedToPlay {
                    justPreparedToPlay = true
                }
            }

            DispatchQueue.main.sync { [weak self] in
                guard let self = self, let prepareOperation = prepareOperation else { return }

                if preparedToPlay {
                    if justPreparedToPlay {
                        self.preparedToPlay = true
                        self.duration = self.decoder?.duration ?? 0

                        self.decoder?.isDeinterlacingEnabled = self.isDeinterlacingEnabled

                        let textureSampler: RDMPEGTextureSampler
                        if self.decoder?.actualVideoFrameFormat == .YUV {
                            textureSampler = RDMPEGTextureSamplerYUV()
                        }
                        else {
                            textureSampler = RDMPEGTextureSamplerBGRA()
                        }

                        self.playerView.renderView = RDMPEGRenderView(
                            frame: self.playerView.bounds,
                            textureSampler: textureSampler,
                            frameWidth: Int(self.decoder?.frameWidth ?? 0),
                            frameHeight: Int(self.decoder?.frameHeight ?? 0)
                        )

                        self.videoStreamExist = self.decoder?.isVideoStreamExist ?? false
                        self.audioStreamExist = self.decoder?.isAudioStreamExist ?? false
                        self.subtitleStreamExist = self.decoder?.isSubtitleStreamExist ?? false

                        self.registerSelectableInputFromDecoderIfNeeded(self.decoder, inputName: nil)

                        self.activeAudioStreamIndex = self.decoder?.activeAudioStreamIndex
                        self.activeSubtitleStreamIndex = self.decoder?.activeSubtitleStreamIndex

                        self.delegate?.mpegPlayerDidPrepareToPlay(self)
                    }

                    if prepareOperation.isCancelled == false {
                        successCallback()
                    }
                }
                else {
                    if prepareOperation.isCancelled == false {
                        self.updateStateIfNeededAndNotify(.failed, error: prepareError)
                    }
                }
            }
        }

        decodingQueue.addOperation(prepareOperation)
    }

    private func prepareToPlay(audioSamplingRate: Double, outputChannelsCount: Int, error: inout Error?) -> Bool {
        log4Assert(OperationQueue.current == decodingQueue, "Method '\(#function)' called from wrong queue")
        log4Assert(audioSamplingRate > 0 && outputChannelsCount > 0, "Incorrect audio parameters")

        if preparedToPlay {
            return true
        }

        let decoder = RDMPEGDecoder(path: filePath, ioStream: stream, subtitleEncoding: nil) { [weak self] in
            self == nil
        }

        if let openInputError = decoder.openInput() {
            error = openInputError
            return false
        }

        let videoError = decoder.loadVideoStream(
            withPreferredVideoFrameFormat: .YUV,
            actualVideoFrameFormat: nil
        )
        let audioError = decoder.loadAudioStream(
            withSamplingRate: audioSamplingRate,
            outputChannels: UInt(outputChannelsCount)
        )

        if videoError == nil || audioError == nil {
            self.decoder = decoder
            return true
        }

        error = videoError
        log4AssertionFailure("Decoder should contain valid video and/or valid audio")
        return false
    }

    private func decodeFrames() {
        log4Assert(OperationQueue.current == decodingQueue, "Method '\(#function)' called from wrong queue")

        guard preparedToPlay else {
            log4AssertionFailure("Player should be prepared to play before attempting to decode")
            return
        }

        guard decoder?.isVideoStreamExist == true || decoder?.isAudioStreamExist == true else {
            log4AssertionFailure("Why we're trying to decode invalid video")
            return
        }

        guard decoder?.isEndReached == false else {
            log4Assert(decodingFinished, "This properties expected to be synchronized")
            decodingFinished = true
            return
        }

        autoreleasepool {
            if let frames = decoder?.decodeFrames() {
                framebuffer.pushFrames(frames)
            }
        }

        decodingFinished = decoder?.isEndReached ?? true
    }

    private func decodeExternalAudioFrames() {
        guard let externalAudioDecoder = externalAudioDecoder else {
            log4AssertionFailure("External audio decoder isn't selected")
            return
        }

        while true {
            if externalAudioDecoder.isEndReached {
                break
            }

            autoreleasepool {
                if let audioFrames = externalAudioDecoder.decodeFrames() {
                    let filteredAudioFrames = audioFrames.compactMap { $0 as? RDMPEGAudioFrame }

                    if filteredAudioFrames.isEmpty == false {
                        framebuffer.pushFrames(filteredAudioFrames)

                        if let nextAudioFrame = framebuffer.nextAudioFrame {
                            let externalAudioBufferOverrun =
                                nextAudioFrame.position + framebuffer.bufferedAudioDuration - currentInternalTime
                            if externalAudioBufferOverrun > RDMPEGPlayerMinAudioBufferSize {
                                return
                            }
                        }
                    }
                }
            }
        }
    }

    private func decodeExternalSubtitleFrames() {
        guard let externalSubtitleDecoder = externalSubtitleDecoder else {
            log4AssertionFailure("External subtitle decoder isn't selected")
            return
        }

        while true {
            if externalSubtitleDecoder.isEndReached {
                break
            }

            autoreleasepool {
                if let subtitleFrames = externalSubtitleDecoder.decodeFrames() {
                    let filteredSubtitleFrames = subtitleFrames.compactMap { $0 as? RDMPEGSubtitleFrame }

                    if subtitleFrames.isEmpty == false {
                        framebuffer.pushFrames(filteredSubtitleFrames)

                        if let nextSubtitleFrame = framebuffer.nextSubtitleFrame {
                            let externalSubtitleBufferOverrun =
                            nextSubtitleFrame.position + framebuffer.bufferedSubtitleDuration - currentInternalTime
                            if externalSubtitleBufferOverrun > 0.0 {
                                return
                            }
                        }
                    }
                }
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func asyncDecodeFramesIfNeeded() {
        if let decodingOperation = decodingOperation, decodingOperation.isCancelled == false {
            return
        }

        let decodingOperation = BlockOperation()
        decodingOperation.name = "Decoding Operation"

        decodingOperation.addExecutionBlock { [weak self, weak decodingOperation] in
            guard let self = self, let decodingOperation = decodingOperation else { return }

            while decodingOperation.isCancelled == false {
                if self.isVideoBufferReady && self.isAudioBufferReady && self.isSubtitleBufferReady {
                    break
                }

                if self.isVideoBufferReady == false {
                    self.decodeFrames()
                }

                if self.isAudioBufferReady == false {
                    if self.decoder?.activeAudioStreamIndex != nil {
                        self.decodeFrames()
                    }
                    else if self.externalAudioDecoder?.activeAudioStreamIndex != nil {
                        self.decodeExternalAudioFrames()
                    }
                }

                if self.isSubtitleBufferReady == false {
                    if self.decoder?.activeSubtitleStreamIndex != nil {
                        self.decodeFrames()
                    }
                    else if self.externalSubtitleDecoder?.activeSubtitleStreamIndex != nil {
                        self.decodeExternalSubtitleFrames()
                    }
                }
            }
        }

        self.decodingOperation = decodingOperation
        decodingQueue.addOperation(decodingOperation)
    }

    private func moveDecoders(to time: TimeInterval, includingMainDecoder: Bool) {
        if includingMainDecoder {
            let clippedTime = min(decoder?.duration ?? 0, max(0.0, time))
            decoder?.move(atPosition: clippedTime)
        }

        if let externalAudioDecoder = externalAudioDecoder {
            let clippedExternalAudioTime = min(externalAudioDecoder.duration, max(0.0, time))
            externalAudioDecoder.move(atPosition: clippedExternalAudioTime)
        }

        if let externalSubtitleDecoder = externalSubtitleDecoder {
            let clippedExternalSubtitleTime = min(externalSubtitleDecoder.duration, max(0.0, time))
            externalSubtitleDecoder.move(atPosition: clippedExternalSubtitleTime)
        }
    }

    private func startScheduler() {
        guard scheduler?.isScheduling != true else {
            log4AssertionFailure("Video scheduler already started")
            return
        }

        scheduler = RDMPEGRenderScheduler()
        scheduler?.start { [weak self] in
            guard let self = self, self.seekOperation == nil else {
                return nil
            }

            if self.videoStreamExist {
                guard let presentedFrame = self.showNextVideoFrame() else {
                    self.correctionInfo = nil

                    if self.decodingFinished {
                        self.finishPlaying()
                    }
                    else {
                        self.setBufferingStateIfNeededAndNotify(true)
                        self.asyncDecodeFramesIfNeeded()
                    }

                    return nil
                }

                if self.correctionInfo == nil {
                    self.correctionInfo = RDMPEGCorrectionInfo(
                        playbackStartDate: Date(),
                        playbackStartTime: self.currentInternalTime
                    )
                    self.setBufferingStateIfNeededAndNotify(false)
                }

                let correctionInterval = self.correctionInfo?.correctionInterval(
                    withCurrentTime: self.currentInternalTime
                ) ?? 0
                let nextFrameInterval = presentedFrame.duration + correctionInterval

                self.asyncDecodeFramesIfNeeded()

                return Date(timeIntervalSinceNow: nextFrameInterval)
            }
            else {
                if self.decodingFinished {
                    if self.framebuffer.nextAudioFrame == nil {
                        self.finishPlaying()
                        return nil
                    }
                }
                else {
                    self.asyncDecodeFramesIfNeeded()
                }

                if let nextAudioFrame = self.framebuffer.nextAudioFrame {
                    return Date(timeIntervalSinceNow: nextAudioFrame.duration)
                }
                else {
                    return Date(timeIntervalSinceNow: 0.01)
                }
            }
        }
    }

    private func stopScheduler() {
        guard scheduler?.isScheduling == true else {
            return
        }

        scheduler?.stop()
        scheduler = nil
    }

    private func showNextVideoFrame() -> RDMPEGVideoFrame? {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        guard let videoFrame = framebuffer.popVideoFrame() else {
#if RD_DEBUG_MPEG_PLAYER
            log4debug("There is no video frame to render")
#endif
            return nil
        }

#if RD_DEBUG_MPEG_PLAYER
        log4debug("Rendering video frame: \(videoFrame.position) \(videoFrame.duration)")
#endif

        currentInternalTime = videoFrame.position

        playerView.renderView?.render(videoFrame)

        showSubtitleForCurrentVideoFrame()

        return videoFrame
    }

    private func showSubtitleForCurrentVideoFrame() {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        let currentSubtitleFramesCopy = currentSubtitleFrames
        for currentSubtitleFrame in currentSubtitleFramesCopy {
            let curSubtitleStartTime = currentSubtitleFrame.position
            let curSubtitleEndTime = curSubtitleStartTime + currentSubtitleFrame.duration

            if curSubtitleStartTime > currentInternalTime || curSubtitleEndTime < currentInternalTime {
                currentSubtitleFrames.removeAll { $0 === currentSubtitleFrame }
            }
        }

        framebuffer.atomicSubtitleFramesAccess {
            while let nextSubtitleFrame = self.framebuffer.nextSubtitleFrame {
                let nextSubtitleStartTime = nextSubtitleFrame.position
                let nextSubtitleEndTime = nextSubtitleStartTime + nextSubtitleFrame.duration

                if nextSubtitleStartTime <= currentInternalTime {
                    if currentInternalTime < nextSubtitleEndTime {
                        if let subtitleFrame = self.framebuffer.popSubtitleFrame() {
                            currentSubtitleFrames.append(subtitleFrame)
                        }
                        break
                    }
                    else {
                        _ = self.framebuffer.popSubtitleFrame()
                    }
                }
                else {
                    break
                }
            }
        }

        let subtitleString = currentSubtitleFrames.map { $0.text }.joined(separator: "\n")
        playerView.subtitle = subtitleString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setAudioOutputEnabled(_ audioOutputEnabled: Bool) {
        if audioOutputEnabled {
            guard audioRenderer.isPlaying == false else {
                return
            }

            _ = audioRenderer.play { [weak self] (data, numFrames, numChannels) in
                self?.audioCallbackFillData(data, numFrames: numFrames, numChannels: numChannels)
            }
        }
        else {
            _ = audioRenderer.pause()
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func audioCallbackFillData(_ outData: UnsafeMutablePointer<Float>, numFrames: UInt32, numChannels: UInt32) {
        autoreleasepool {
            var outData = outData

            if videoStreamExist && correctionInfo == nil {
#if RD_DEBUG_MPEG_PLAYER
                L4Logger.logger(forName: "rd.mediaplayer.RDMPEGPlayer").debug("Silence audio while correcting video")
#endif

                memset(outData, 0, Int(numFrames) * Int(numChannels) * MemoryLayout<Float>.size)
                return
            }

            var numFramesLeft = numFrames

            while numFramesLeft > 0 {
                if rawAudioFrame == nil {
                    var nextAudioFrame: RDMPEGAudioFrame?
                    var isAudioOutrun = false
                    var isAudioLags = false

#if RD_DEBUG_MPEG_PLAYER
                    let loggingScope = L4Logger.logger(forName: "rd.mediaplayer.RDMPEGPlayer").loggingScope()
#endif

                    framebuffer.atomicAudioFramesAccess {
                        if let nextFrame = self.framebuffer.nextAudioFrame {
                            let delta = self.correctionInfo?.correctionInterval(
                                withCurrentTime: nextFrame.position
                            ) ?? 0

                            if delta > 0.1 {
#if RD_DEBUG_MPEG_PLAYER
                                loggingScope.debug("""
                                    Desync audio (outrun) wait 
                                    \(self.currentInternalTime) \(nextFrame.position) \(delta)
                                """)
#endif

                                isAudioOutrun = true
                                return
                            }

                            nextAudioFrame = self.framebuffer.popAudioFrame()

                            if videoStreamExist == false {
                                currentInternalTime = nextAudioFrame?.position ?? 0
                            }

                            if delta < -0.1, self.framebuffer.nextAudioFrame != nil {
#if RD_DEBUG_MPEG_PLAYER
                                loggingScope.debug("""
                                    Desync audio (lags) skip \(self.currentInternalTime) \(nextFrame.position) \(delta)
                                """)
#endif

                                isAudioLags = true
                                return
                            }
                        }
                    }

                    if isAudioOutrun {
                        memset(outData, 0, Int(numFramesLeft) * Int(numChannels) * MemoryLayout<Float>.size)
                        break
                    }
                    if isAudioLags {
                        continue
                    }

                    if let audioFrame = nextAudioFrame {
#if RD_DEBUG_MPEG_PLAYER
                        L4Logger.logger(forName: "rd.mediaplayer.RDMPEGPlayer")
                            .debug("Audio frame will be rendered: \(audioFrame.position) \(audioFrame.duration)")
#endif

                        rawAudioFrame = RDMPEGRawAudioFrame(rawAudioData: audioFrame.samples)

                        if videoStreamExist == false {
                            correctionInfo = RDMPEGCorrectionInfo(
                                playbackStartDate: Date(),
                                playbackStartTime: currentInternalTime
                            )

                            DispatchQueue.main.async {
                                self.setBufferingStateIfNeededAndNotify(false)
                            }
                        }
                    }
                    else if videoStreamExist == false {
                        correctionInfo = nil

                        DispatchQueue.main.async {
                            self.setBufferingStateIfNeededAndNotify(true)
                        }
                    }
                }

                if let rawAudioFrame = rawAudioFrame {
#if RD_DEBUG_MPEG_PLAYER
                    L4Logger.logger(forName: "rd.mediaplayer.RDMPEGPlayer").debug("Rendering raw audio frame")
#endif

                    let bytes = rawAudioFrame.rawAudioData.withUnsafeBytes { $0.baseAddress }?
                        .advanced(by: rawAudioFrame.rawAudioDataOffset)
                    let bytesLeft = rawAudioFrame.rawAudioData.count - rawAudioFrame.rawAudioDataOffset
                    let frameSize = Int(numChannels) * MemoryLayout<Float>.size
                    let bytesToCopy = min(Int(numFramesLeft) * frameSize, bytesLeft)
                    let framesToCopy = bytesToCopy / frameSize

                    memcpy(outData, bytes, bytesToCopy)
                    numFramesLeft -= UInt32(framesToCopy)
                    outData = outData.advanced(by: framesToCopy * Int(numChannels))

                    rawAudioFrame.rawAudioDataOffset += bytesToCopy

                    if rawAudioFrame.rawAudioDataOffset >= rawAudioFrame.rawAudioData.count {
                        log4Assert(
                            rawAudioFrame.rawAudioDataOffset == rawAudioFrame.rawAudioData.count,
                            "Incorrect offset, copying should be checked"
                        )
                        self.rawAudioFrame = nil
                    }
                }
                else {
#if RD_DEBUG_MPEG_PLAYER
                    L4Logger.logger(forName: "rd.mediaplayer.RDMPEGPlayer").debug("Silence audio")
#endif

                    memset(outData, 0, Int(numFramesLeft) * Int(numChannels) * MemoryLayout<Float>.size)
                    break
                }
            }
        }
    }

    private func setBufferingStateIfNeededAndNotify(_ buffering: Bool) {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        guard isBuffering != buffering else {
            return
        }

        guard internalState == .playing || buffering == false else {
            return
        }

        isBuffering = buffering

        delegate?.mpegPlayer(self, didChangeBufferingState: isBuffering ? .paused : .playing)
    }

    private func startTimeObservingTimer() {
        guard timeObservingTimer == nil else {
            log4AssertionFailure("Time observing timer already started")
            return
        }

        timeObservingTimer = Timer.scheduledTimer(
                withTimeInterval: timeObservingInterval,
                repeats: true
            ) { [weak self] _ in
            self?.timeObservingTimerFired()
        }
    }

    private func stopTimeObservingTimer() {
        timeObservingTimer?.invalidate()
        timeObservingTimer = nil
    }

    private func timeObservingTimerFired() {
        guard seekOperation == nil else {
            return
        }

        delegate?.mpegPlayer(self, didUpdateCurrentTime: currentTime)
    }

    private func updateStateIfNeededAndNotify(_ state: RDMPEGPlayerState, error: Error?) {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        guard internalState != state else {
            return
        }

        internalState = state
        self.error = (internalState == .failed) ? error : nil

        if internalState == .playing {
            startTimeObservingTimer()
        }
        else {
            stopTimeObservingTimer()
        }

        delegate?.mpegPlayer(self, didChangeState: internalState)
    }

    private func finishPlaying() {
        pause()

        currentInternalTime = duration

        delegate?.mpegPlayer(self, didUpdateCurrentTime: currentInternalTime)
        delegate?.mpegPlayerDidFinishPlaying(self)
    }

    private func registerSelectableInputFromDecoderIfNeeded(_ decoder: RDMPEGDecoder?, inputName: String?) {
        log4Assert(Thread.isMainThread, "Method '\(#function)' called from wrong thread")

        // swiftlint:disable:next empty_count
        guard let decoder = decoder, decoder.audioStreams.count > 0 || decoder.subtitleStreams.count > 0 else {
            return
        }

        var audioStreamNames = [String]()
        var subtitleStreamNames = [String]()

        for stream in decoder.audioStreams {
            guard let stream = stream as? RDMPEGStream else { continue }

            let audioStream = streamName(for: stream, inputName: inputName)
            audioStreamNames.append(audioStream)
        }

        for stream in decoder.subtitleStreams {
            guard let stream = stream as? RDMPEGStream else { continue }

            let subtitleStream = streamName(for: stream, inputName: inputName)
            subtitleStreamNames.append(subtitleStream)
        }

        var selectableInput: [String: Any] = [
            RDMPEGPlayerInputDecoderKey: decoder
        ]
        if let inputName = inputName {
            selectableInput[RDMPEGPlayerInputNameKey] = inputName
        }
        selectableInput[RDMPEGPlayerInputAudioStreamsKey] = audioStreamNames.isEmpty ? nil : audioStreamNames
        selectableInput[RDMPEGPlayerInputSubtitleStreamsKey] = subtitleStreamNames.isEmpty ? nil : subtitleStreamNames
        selectableInputs?.append(selectableInput)

        var allAudioStreams = [RDMPEGSelectableInputStream]()
        var allSubtitleStreams = [RDMPEGSelectableInputStream]()

        for selectableInput in selectableInputs ?? [] {
            let audioStreams = selectableInput[RDMPEGPlayerInputAudioStreamsKey] as? [String] ?? []
            let subtitleStreams = selectableInput[RDMPEGPlayerInputSubtitleStreamsKey] as? [String] ?? []
            let inputName = selectableInput[RDMPEGPlayerInputNameKey] as? String

            for audioStreamName in audioStreams {
                let selectableStream = RDMPEGSelectableInputStream()
                selectableStream.title = audioStreamName
                selectableStream.inputName = inputName
                allAudioStreams.append(selectableStream)
            }

            for subtitleStreamName in subtitleStreams {
                let selectableStream = RDMPEGSelectableInputStream()
                selectableStream.title = subtitleStreamName
                selectableStream.inputName = inputName
                allSubtitleStreams.append(selectableStream)
            }
        }

        audioStreams = allAudioStreams
        subtitleStreams = allSubtitleStreams

        delegate?.mpegPlayerDidAttachInput(self)
    }

    private func streamName(for stream: RDMPEGStream, inputName: String?) -> String {
        var streamName = ""

        if let inputName = inputName {
            streamName += "[\(inputName)] - "
        }

        if stream.canBeDecoded {
            if let languageCode = stream.languageCode {
                if let language = Locale.current.localizedString(forLanguageCode: languageCode) {
                    let firstLetter = String(language.prefix(1))
                    let foldedFirstLetter = firstLetter.folding(options: .diacriticInsensitive, locale: .current)
                    streamName += foldedFirstLetter.uppercased() + language.dropFirst()
                }
                else {
                    streamName += languageCode
                }

                if stream.info != nil {
                    streamName += ", "
                }
            }

            if let info = stream.info {
                streamName += info
            }
        }
        else {
            streamName += NSLocalizedString("Unsupported", comment: "Stream which we're unable to decode")
        }

        return streamName
    }

    private var isVideoBufferReady: Bool {
        log4Assert(OperationQueue.current == decodingQueue, "Method '\(#function)' called from wrong queue")

        guard let decoder = decoder, decoder.isVideoStreamExist, decoder.isEndReached == false else {
            return true
        }

        return framebuffer.bufferedVideoDuration > RDMPEGPlayerMinVideoBufferSize
    }

    private var isAudioBufferReady: Bool {
        log4Assert(OperationQueue.current == decodingQueue, "Method '\(#function)' called from wrong queue")

        if decoder?.isVideoStreamExist == true {
            if decoder?.activeAudioStreamIndex != nil {
                log4Assert(
                    externalAudioDecoder == nil,
                    "External audio decoder should be nil when main audio stream activated"
                )

                if decoder?.isEndReached == true {
                    return true
                }

                if framebuffer.bufferedAudioDuration > RDMPEGPlayerMinAudioBufferSize {
                    return true
                }

                if framebuffer.bufferedVideoDuration >= RDMPEGPlayerMaxVideoBufferSize {
                    return true
                }

                return false
            }
            else if externalAudioDecoder?.activeAudioStreamIndex != nil {
                if externalAudioDecoder?.isEndReached == true {
                    return true
                }

                if framebuffer.bufferedAudioDuration > RDMPEGPlayerMinAudioBufferSize {
                    return true
                }

                return false
            }
            else {
                return true
            }
        }
        else {
            guard let decoder = decoder, decoder.isAudioStreamExist, decoder.isEndReached == false else {
                return true
            }

            return framebuffer.bufferedAudioDuration > RDMPEGPlayerMinAudioBufferSize
        }
    }

    private var isSubtitleBufferReady: Bool {
        log4Assert(OperationQueue.current == decodingQueue, "Method '\(#function)' called from wrong queue")

        if decoder?.isVideoStreamExist == true {
            if decoder?.activeSubtitleStreamIndex != nil {
                log4Assert(
                    externalSubtitleDecoder == nil,
                    "External subtitle decoder should be nil when main subtitle stream activated"
                )

                if decoder?.isEndReached == true {
                    return true
                }

                if framebuffer.bufferedVideoDuration >= RDMPEGPlayerMaxVideoBufferSize {
                    return true
                }

                return framebuffer.bufferedSubtitleFramesCount > 0
            }
            else if externalSubtitleDecoder?.activeSubtitleStreamIndex != nil {
                if externalSubtitleDecoder?.isEndReached == true {
                    return true
                }

                if framebuffer.bufferedVideoDuration >= RDMPEGPlayerMaxVideoBufferSize {
                    return true
                }

                return framebuffer.bufferedSubtitleFramesCount > 0
            }
            else {
                return true
            }
        }
        else {
            return true
        }
    }
}

extension RDMPEGPlayer {
    class var l4Logger: L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGPlayer")
    }
}
