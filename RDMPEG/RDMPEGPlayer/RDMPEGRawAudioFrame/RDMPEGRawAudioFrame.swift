//
//  RDMPEGRawAudioFrame.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation

@objc public class RDMPEGRawAudioFrame: NSObject {
    @objc public private(set) var rawAudioData: Data
    @objc public var rawAudioDataOffset: Int = 0

    @objc public init(rawAudioData: Data) {
        self.rawAudioData = rawAudioData
        super.init()
    }
}
