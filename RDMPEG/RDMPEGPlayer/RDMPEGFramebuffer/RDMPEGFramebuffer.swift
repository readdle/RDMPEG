//
//  RDMPEGFramebuffer.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa

class RDMPEGFramebuffer {
    private(set) var artworkFrame: RDMPEGArtworkFrame?

    private var videoFrames: [RDMPEGVideoFrame] = []
    private var audioFrames: [RDMPEGAudioFrame] = []
    private var subtitleFrames: [RDMPEGSubtitleFrame] = []
    private var videoFramesLock = NSRecursiveLock()
    private var audioFramesLock = NSRecursiveLock()
    private var subtitleFramesLock = NSRecursiveLock()

    var bufferedVideoDuration: TimeInterval {
        videoFramesLock.withLock {
            return videoFrames.reduce(0) { $0 + $1.duration }
        }
    }

    var bufferedAudioDuration: TimeInterval {
        audioFramesLock.withLock {
            return audioFrames.reduce(0) { $0 + $1.duration }
        }
    }

    var bufferedSubtitleDuration: TimeInterval {
        subtitleFramesLock.withLock {
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

    var bufferedVideoFramesCount: Int {
        videoFramesLock.withLock {
            return videoFrames.count
        }
    }

    var bufferedAudioFramesCount: Int {
        audioFramesLock.withLock {
            return audioFrames.count
        }
    }

    var bufferedSubtitleFramesCount: Int {
        subtitleFramesLock.withLock {
            return subtitleFrames.count
        }
    }

    var nextVideoFrame: RDMPEGVideoFrame? {
        videoFramesLock.withLock {
            return videoFrames.first
        }
    }

    var nextAudioFrame: RDMPEGAudioFrame? {
        audioFramesLock.withLock {
            return audioFrames.first
        }
    }

    var nextSubtitleFrame: RDMPEGSubtitleFrame? {
        subtitleFramesLock.withLock {
            return subtitleFrames.first
        }
    }

    class var l4Logger: L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGFramebuffer")
    }

    func pushFrames(_ frames: [RDMPEGFrame]) {
        for frame in frames {
            switch frame.type {
            case .video:
                if let videoFrame = frame as? RDMPEGVideoFrame {
                    #if RD_DEBUG_MPEG_PLAYER
                    log4Debug("Pushed video frame: \(frame.position) \(frame.duration)")
                    #endif
                    videoFramesLock.withLock {
                        videoFrames.append(videoFrame)
                    }
                }
            case .audio:
                if let audioFrame = frame as? RDMPEGAudioFrame {
                    #if RD_DEBUG_MPEG_PLAYER
                    log4Debug("Pushed audio frame: \(frame.position) \(frame.duration)")
                    #endif
                    audioFramesLock.withLock {
                        audioFrames.append(audioFrame)
                    }
                }
            case .subtitle:
                if let subtitleFrame = frame as? RDMPEGSubtitleFrame {
                    #if RD_DEBUG_MPEG_PLAYER
                    log4Debug("""
                        Pushed subtitle frame:
                        \(subtitleFrame.position) \(subtitleFrame.duration) \(subtitleFrame.text ?? "")
                    """)
                    #endif
                    subtitleFramesLock.withLock {
                        subtitleFrames.append(subtitleFrame)
                    }
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
        videoFramesLock.withLock {
            guard !videoFrames.isEmpty else { return nil }
            return videoFrames.removeFirst()
        }
    }

    func popAudioFrame() -> RDMPEGAudioFrame? {
        audioFramesLock.withLock {
            guard !audioFrames.isEmpty else { return nil }
            return audioFrames.removeFirst()
        }
    }

    @discardableResult
    public func popSubtitleFrame() -> RDMPEGSubtitleFrame? {
        subtitleFramesLock.withLock {
            guard !subtitleFrames.isEmpty else { return nil }
            return subtitleFrames.removeFirst()
        }
    }

    func atomicVideoFramesAccess(_ accessBlock: () -> Void) {
        videoFramesLock.withLock {
            accessBlock()
        }
    }

    func atomicAudioFramesAccess(_ accessBlock: () -> Void) {
        audioFramesLock.withLock {
            accessBlock()
        }
    }

    func atomicSubtitleFramesAccess(_ accessBlock: () -> Void) {
        subtitleFramesLock.withLock {
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
        videoFramesLock.withLock {
            videoFrames.removeAll()
        }
    }

    func purgeAudioFrames() {
        audioFramesLock.withLock {
            audioFrames.removeAll()
        }
    }

    func purgeSubtitleFrames() {
        subtitleFramesLock.withLock {
            subtitleFrames.removeAll()
        }
    }

    func purgeArtworkFrame() {
        artworkFrame = nil
    }
}
