//
//  RDMPEGFramebuffer.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa

class RDMPEGFramebuffer: NSObject {
    var bufferedVideoDuration: TimeInterval {
        get {
            synchronized(videoFrames) {
                return videoFrames.reduce(0) { $0 + $1.duration }
            }
        }
    }

    var bufferedAudioDuration: TimeInterval {
        get {
            synchronized(audioFrames) {
                return audioFrames.reduce(0) { $0 + $1.duration }
            }
        }
    }

    var bufferedSubtitleDuration: TimeInterval {
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

    var bufferedVideoFramesCount: Int {
        get {
            synchronized(videoFrames) {
                return videoFrames.count
            }
        }
    }

    var bufferedAudioFramesCount: Int {
        get {
            synchronized(audioFrames) {
                return audioFrames.count
            }
        }
    }

    var bufferedSubtitleFramesCount: Int {
        get {
            synchronized(subtitleFrames) {
                return subtitleFrames.count
            }
        }
    }

    var nextVideoFrame: RDMPEGVideoFrame? {
        get {
            synchronized(videoFrames) {
                return videoFrames.first
            }
        }
    }

    var nextAudioFrame: RDMPEGAudioFrame? {
        get {
            synchronized(audioFrames) {
                return audioFrames.first
            }
        }
    }

    var nextSubtitleFrame: RDMPEGSubtitleFrame? {
        get {
            synchronized(subtitleFrames) {
                return subtitleFrames.first
            }
        }
    }

    private(set) var artworkFrame: RDMPEGArtworkFrame?

    private var videoFrames: [RDMPEGVideoFrame] = []
    private var audioFrames: [RDMPEGAudioFrame] = []
    private var subtitleFrames: [RDMPEGSubtitleFrame] = []

    class var l4Logger: L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGFramebuffer")
    }

    func pushFrames(_ frames: [RDMPEGFrame]) {
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

    func popVideoFrame() -> RDMPEGVideoFrame? {
        synchronized(videoFrames) {
            guard !videoFrames.isEmpty else { return nil }
            return videoFrames.removeFirst()
        }
    }

    func popAudioFrame() -> RDMPEGAudioFrame? {
        synchronized(audioFrames) {
            guard !audioFrames.isEmpty else { return nil }
            return audioFrames.removeFirst()
        }
    }

    @discardableResult public func popSubtitleFrame() -> RDMPEGSubtitleFrame? {
        synchronized(subtitleFrames) {
            guard !subtitleFrames.isEmpty else { return nil }
            return subtitleFrames.removeFirst()
        }
    }

    func atomicVideoFramesAccess(_ accessBlock: () -> Void) {
        synchronized(videoFrames) {
            accessBlock()
        }
    }

    func atomicAudioFramesAccess(_ accessBlock: () -> Void) {
        synchronized(audioFrames) {
            accessBlock()
        }
    }

    func atomicSubtitleFramesAccess(_ accessBlock: () -> Void) {
        synchronized(subtitleFrames) {
            accessBlock()
        }
    }

    func purge() {
        purgeVideoFrames()
        purgeAudioFrames()
        purgeSubtitleFrames()
        purgeArtworkFrame()
    }

    func purgeVideoFrames() {
        synchronized(videoFrames) {
            videoFrames.removeAll()
        }
    }

    func purgeAudioFrames() {
        synchronized(audioFrames) {
            audioFrames.removeAll()
        }
    }

    func purgeSubtitleFrames() {
        synchronized(subtitleFrames) {
            subtitleFrames.removeAll()
        }
    }

    func purgeArtworkFrame() {
        artworkFrame = nil
    }

    private func synchronized<T>(_ lock: Any, _ closure: () -> T) -> T {
        objc_sync_enter(lock)
        defer { objc_sync_exit(lock) }
        return closure()
    }
}
