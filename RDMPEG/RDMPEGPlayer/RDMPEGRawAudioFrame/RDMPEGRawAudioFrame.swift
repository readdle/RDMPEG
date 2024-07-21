//
//  RDMPEGRawAudioFrame.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation

class RDMPEGRawAudioFrame: NSObject {
    private(set) var rawAudioData: Data
    var rawAudioDataOffset: Int = 0

    init(rawAudioData: Data) {
        self.rawAudioData = rawAudioData
        super.init()
    }
}
