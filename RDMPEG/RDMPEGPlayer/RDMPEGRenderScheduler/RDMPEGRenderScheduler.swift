//
//  RDMPEGRenderScheduler.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa

@objc public class RDMPEGRenderScheduler: NSObject {

    private var timer: Timer?
    private var callback: (() -> Date?)?

    @objc public var isScheduling: Bool {
        return timer != nil
    }

    deinit {
        stop()
    }

    @objc public func start(with callback: @escaping () -> Date?) {
        guard !isScheduling else {
            log4Assert(false, "Already scheduling")
            return
        }

        self.callback = callback

        let timerTarget = RDMPEGWeakTimerTarget(target: self, action: #selector(renderTimerFired(_:)))
        let newTimer = Timer(timeInterval: 0.0, target: timerTarget, selector: #selector(RDMPEGWeakTimerTarget.timerFired(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(newTimer, forMode: .common)

        timer = newTimer
    }

    @objc public func stop() {
        guard isScheduling else { return }

        timer?.invalidate()
        timer = nil
        callback = nil
    }

    @objc private func renderTimerFired(_ timer: Timer) {
        autoreleasepool {
            let nextFireDate = callback?() ?? Date(timeIntervalSinceNow: 0.01)
            timer.fireDate = nextFireDate
        }
    }
}

extension RDMPEGRenderScheduler {
    class var l4Logger: L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGRenderScheduler")
    }
}
