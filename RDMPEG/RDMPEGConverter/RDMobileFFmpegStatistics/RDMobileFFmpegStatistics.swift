//
//  RDMobileFFmpegStatistics.swift
//  RDMPEG
//
//  Created by Max on 16/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import ffmpegkit

class RDMobileFFmpegStatistics {
    private let statistics: Statistics

    var frameNumber: Int {
        return Int(statistics.getVideoFrameNumber())
    }

    var fps: Float {
        return statistics.getVideoFps()
    }

    var quality: Float {
        return statistics.getVideoQuality()
    }

    var size: Int {
        return statistics.getSize()
    }

    var time: Int {
        return Int(statistics.getTime())
    }

    var bitrate: Double {
        return statistics.getBitrate()
    }

    var speed: Double {
        return statistics.getSpeed()
    }

    init(statistics: Statistics) {
        self.statistics = statistics
    }
}
