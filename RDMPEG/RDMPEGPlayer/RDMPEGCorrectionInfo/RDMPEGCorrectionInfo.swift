//
//  RDMPEGCorrectionInfo.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 10/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa

class RDMPEGCorrectionInfo: NSObject {
    private let playbackStartDate: Date
    private let playbackStartTime: TimeInterval

    init(playbackStartDate: Date, playbackStartTime: TimeInterval) {
        self.playbackStartDate = playbackStartDate
        self.playbackStartTime = playbackStartTime
        super.init()
    }

    func correctionInterval(withCurrentTime currentTime: TimeInterval) -> TimeInterval {
        let continuousPlaybackRealTime = Date().timeIntervalSince(playbackStartDate)

        if continuousPlaybackRealTime < 0.0 {
            log4Assert(false, "Seems like playback start date is incorrect")
            return 0.0
        }

        let continuousPlaybackPlayedTime = currentTime - playbackStartTime

        let correctionInterval = continuousPlaybackPlayedTime - continuousPlaybackRealTime
        return correctionInterval
    }
}
