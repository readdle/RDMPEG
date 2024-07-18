//
//  RDMobileFFmpegStatistics.swift
//  RDMPEG
//
//  Created by Max on 16/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import ffmpegkit

@objc public class RDMobileFFmpegStatistics: NSObject {
    private let statistics: Statistics

    @objc public var frameNumber: Int {
        return Int(statistics.getVideoFrameNumber())
    }

    @objc public var fps: Float {
        return statistics.getVideoFps()
    }

    @objc public var quality: Float {
        return statistics.getVideoQuality()
    }

    @objc public var size: Int {
        return statistics.getSize()
    }

    @objc public var time: Int {
        return Int(statistics.getTime())
    }

    @objc public var bitrate: Double {
        return statistics.getBitrate()
    }

    @objc public var speed: Double {
        return statistics.getSpeed()
    }

    @objc public init(statistics: Statistics) {
        self.statistics = statistics
        super.init()
    }
}
