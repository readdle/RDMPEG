//
//  RDMPEGCorrectionInfo.swift
//  RDMPEG
//
//  Created by Max on 10/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa

@objc public class RDMPEGCorrectionInfo: NSObject {
    let playbackStartDate: Date
    let playbackStartTime: TimeInterval

    @objc public init(playbackStartDate: Date, playbackStartTime: TimeInterval) {
        self.playbackStartDate = playbackStartDate
        self.playbackStartTime = playbackStartTime
        super.init()
    }

    @objc public func correctionInterval(withCurrentTime currentTime: TimeInterval) -> TimeInterval {
        let continuousPlaybackRealTime = Date().timeIntervalSince(playbackStartDate)

        if continuousPlaybackRealTime < 0.0 {
            log4Assert(false, "Seems like playback start date is incorrect")
            return 0.0
        }

        let continuousPlaybackPlayedTime = currentTime - playbackStartTime

        let correctionInterval = continuousPlaybackPlayedTime - continuousPlaybackRealTime
        return correctionInterval
    }

    class var l4Logger: L4Logger {
        L4Logger(forName: "rd.mediaplayer.RDMPEGCorrectionInfo")
    }
}