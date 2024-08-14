//
//  RDMobileFFmpegStatistics.swift
//  RDMPEG
//
//  Created by Max on 16/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import ffmpegkit

@objcMembers
public class RDMobileFFmpegStatistics: NSObject {
    private let statistics: Statistics

    public var frameNumber: Int {
        return Int(statistics.getVideoFrameNumber())
    }

    public var fps: Float {
        return statistics.getVideoFps()
    }

    public var quality: Float {
        return statistics.getVideoQuality()
    }

    public var size: Int {
        return statistics.getSize()
    }

    public var time: Int {
        return Int(statistics.getTime())
    }

    public var bitrate: Double {
        return statistics.getBitrate()
    }

    public var speed: Double {
        return statistics.getSpeed()
    }

    public init(statistics: Statistics) {
        self.statistics = statistics
    }
}
