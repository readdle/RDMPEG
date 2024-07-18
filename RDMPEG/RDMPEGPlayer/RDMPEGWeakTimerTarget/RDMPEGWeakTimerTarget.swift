//
//  RDMPEGWeakTimerTarget.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 11/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation

@objc public class RDMPEGWeakTimerTarget: NSObject {
    private weak var target: AnyObject?
    private var action: Selector

    @objc public init(target: AnyObject, action: Selector) {
        self.target = target
        self.action = action
        super.init()
    }

    @objc public func timerFired(_ timer: Timer) {
        guard let target else { return }

        let _ = target.perform(action, with: timer)
    }
}
