//
//  RDMPEGFramebuffer.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa

@objc public class RDMPEGFramebuffer: NSObject {
    @objc public var bufferedVideoDuration: TimeInterval {
        get {
            synchronized(videoFrames) {
                return videoFrames.reduce(0) { $0 + $1.duration }
            }
        }
    }

    @objc public var bufferedAudioDuration: TimeInterval {
        get {
            synchronized(audioFrames) {
                return audioFrames.reduce(0) { $0 + $1.duration }
            }
        }
    }

    @objc public var bufferedSubtitleDuration: TimeInterval {
        get {
            synchronized(subtitleFrames) {
                guard let first = subtitleFrames.first else { return 0 }
                var minPosition = first.position
                var maxPosition = first.position + first.duration

                for frame in subtitleFrames {
                    minPosition = min(minPosition, frame.position)
                    maxPosition = max(maxPosition, frame.position + frame.duration)
                }

                return maxPosition - minPosition
            }
        }
    }

    @objc public var bufferedVideoFramesCount: Int {
        get {
            synchronized(videoFrames) {
                return videoFrames.count
            }
        }
    }

    @objc public var bufferedAudioFramesCount: Int {
        get {
            synchronized(audioFrames) {
                return audioFrames.count
            }
        }
    }

    @objc public var bufferedSubtitleFramesCount: Int {
        get {
            synchronized(subtitleFrames) {
                return subtitleFrames.count
            }
        }
    }

    @objc public var nextVideoFrame: RDMPEGVideoFrame? {
        get {
            synchronized(videoFrames) {
                return videoFrames.first
            }
        }
    }

    @objc public var nextAudioFrame: RDMPEGAudioFrame? {
        get {
            synchronized(audioFrames) {
                return audioFrames.first
            }
        }
    }

    @objc public var nextSubtitleFrame: RDMPEGSubtitleFrame? {
        get {
            synchronized(subtitleFrames) {
                return subtitleFrames.first
            }
        }
    }

    @objc public private(set) var artworkFrame: RDMPEGArtworkFrame?

    private var videoFrames: [RDMPEGVideoFrame] = []
    private var audioFrames: [RDMPEGAudioFrame] = []
    private var subtitleFrames: [RDMPEGSubtitleFrame] = []

    class var l4Logger: L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGFramebuffer")
    }

    @objc public func pushFrames(_ frames: [RDMPEGFrame]) {
        for frame in frames {
            switch frame.type {
            case .video:
                let videoFrame = frame as! RDMPEGVideoFrame
                #if RD_DEBUG_MPEG_PLAYER
                log4Debug("Pushed video frame: \(frame.position) \(frame.duration)")
                #endif
                synchronized(videoFrames) {
                    videoFrames.append(videoFrame)
                }
            case .audio:
                let audioFrame = frame as! RDMPEGAudioFrame
                #if RD_DEBUG_MPEG_PLAYER
                log4Debug("Pushed audio frame: \(frame.position) \(frame.duration)")
                #endif
                synchronized(audioFrames) {
                    audioFrames.append(audioFrame)
                }
            case .subtitle:
                let subtitleFrame = frame as! RDMPEGSubtitleFrame
                #if RD_DEBUG_MPEG_PLAYER
                log4Debug("Pushed subtitle frame: \(subtitleFrame.position) \(subtitleFrame.duration) \(subtitleFrame.text ?? "")")
                #endif
                synchronized(subtitleFrames) {
                    subtitleFrames.append(subtitleFrame)
                }
            case .artwork:
                #if RD_DEBUG_MPEG_PLAYER
                log4Debug("Pushed artwork frame: \(frame.position) \(frame.duration)")
                #endif
                artworkFrame = frame as? RDMPEGArtworkFrame
            @unknown default:
                break
            }
        }
    }

    @objc public func popVideoFrame() -> RDMPEGVideoFrame? {
        synchronized(videoFrames) {
            guard !videoFrames.isEmpty else { return nil }
            return videoFrames.removeFirst()
        }
    }

    @objc public func popAudioFrame() -> RDMPEGAudioFrame? {
        synchronized(audioFrames) {
            guard !audioFrames.isEmpty else { return nil }
            return audioFrames.removeFirst()
        }
    }

    @objc @discardableResult public func popSubtitleFrame() -> RDMPEGSubtitleFrame? {
        synchronized(subtitleFrames) {
            guard !subtitleFrames.isEmpty else { return nil }
            return subtitleFrames.removeFirst()
        }
    }

    @objc public func atomicVideoFramesAccess(_ accessBlock: () -> Void) {
        synchronized(videoFrames) {
            accessBlock()
        }
    }

    @objc public func atomicAudioFramesAccess(_ accessBlock: () -> Void) {
        synchronized(audioFrames) {
            accessBlock()
        }
    }

    @objc public func atomicSubtitleFramesAccess(_ accessBlock: () -> Void) {
        synchronized(subtitleFrames) {
            accessBlock()
        }
    }

    @objc public func purge() {
        purgeVideoFrames()
        purgeAudioFrames()
        purgeSubtitleFrames()
        purgeArtworkFrame()
    }

    @objc public func purgeVideoFrames() {
        synchronized(videoFrames) {
            videoFrames.removeAll()
        }
    }

    @objc public func purgeAudioFrames() {
        synchronized(audioFrames) {
            audioFrames.removeAll()
        }
    }

    @objc public func purgeSubtitleFrames() {
        synchronized(subtitleFrames) {
            subtitleFrames.removeAll()
        }
    }

    @objc public func purgeArtworkFrame() {
        artworkFrame = nil
    }

    private func synchronized<T>(_ lock: Any, _ closure: () -> T) -> T {
        objc_sync_enter(lock)
        defer { objc_sync_exit(lock) }
        return closure()
    }
}
