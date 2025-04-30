//
//  RDMPEGRenderScheduler.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa

class RDMPEGRenderScheduler: NSObject {
    private var timer: Timer?
    private var callback: (() -> Date?)?

    var isScheduling: Bool {
        return timer != nil
    }

    deinit {
        stop()
    }

    func start(with callback: @escaping () -> Date?) {
        guard isScheduling == false else {
            log4Assert(false, "Already scheduling")
            return
        }

        self.callback = callback

        let newTimer = Timer(timeInterval: 0.0, repeats: true) { [weak self] in
            self?.renderTimerFired($0)
        }

        RunLoop.main.add(newTimer, forMode: .common)

        timer = newTimer
    }

    func stop() {
        guard isScheduling else { return }

        timer?.invalidate()
        timer = nil
        callback = nil
    }

    private func renderTimerFired(_ timer: Timer) {
        let nextFireDate = callback?() ?? Date(timeIntervalSinceNow: 0.01)
        timer.fireDate = nextFireDate
    }
}

extension RDMPEGRenderScheduler {
    class var l4Logger: L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGRenderScheduler")
    }
}
