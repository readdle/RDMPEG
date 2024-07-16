//
//  RDMPEGFrames.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import UIKit

@objc public enum RDMPEGFrameType: UInt {
    case audio
    case video
    case artwork
    case subtitle
}

@objc public class RDMPEGFrame: NSObject {
    @objc public let type: RDMPEGFrameType
    @objc public var position: TimeInterval
    @objc public var duration: TimeInterval

    @objc public init(type: RDMPEGFrameType, position: TimeInterval, duration: TimeInterval) {
        self.type = type
        self.position = position
        self.duration = duration
        super.init()
    }
}

@objc public class RDMPEGAudioFrame: RDMPEGFrame {
    @objc public var samples: Data

    @objc public init(position: TimeInterval, duration: TimeInterval, samples: Data) {
        self.samples = samples
        super.init(type: .audio, position: position, duration: duration)
    }
}

@objc public class RDMPEGVideoFrame: RDMPEGFrame {
    @objc public var width: UInt
    @objc public var height: UInt

    @objc public init(position: TimeInterval, duration: TimeInterval, width: UInt, height: UInt) {
        self.width = width
        self.height = height
        super.init(type: .video, position: position, duration: duration)
    }
}

@objc public class RDMPEGVideoFrameBGRA: RDMPEGVideoFrame {
    @objc public var linesize: UInt
    @objc public var bgra: Data

    @objc public init(position: TimeInterval, duration: TimeInterval, width: UInt, height: UInt, bgra: Data, linesize: UInt) {
        self.bgra = bgra
        self.linesize = linesize
        super.init(position: position, duration: duration, width: width, height: height)
    }

    @objc public func asImage() -> UIImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let provider = CGDataProvider(data: bgra as CFData)

        guard let imageRef = CGImage(
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: Int(linesize),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider!,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return UIImage(cgImage: imageRef)
    }
}

@objc public class RDMPEGVideoFrameYUV: RDMPEGVideoFrame {
    @objc public var luma: Data
    @objc public var chromaB: Data
    @objc public var chromaR: Data

    @objc public init(position: TimeInterval, duration: TimeInterval, width: UInt, height: UInt, luma: Data, chromaB: Data, chromaR: Data) {
        self.luma = luma
        self.chromaB = chromaB
        self.chromaR = chromaR
        super.init(position: position, duration: duration, width: width, height: height)
    }
}

@objc public class RDMPEGArtworkFrame: RDMPEGFrame {
    @objc public var picture: Data

    @objc public init(picture: Data) {
        self.picture = picture
        super.init(type: .artwork, position: 0, duration: 0)
    }

    @objc public func asImage() -> UIImage? {
        guard let provider = CGDataProvider(data: picture as CFData) else { return nil }

        guard let imageRef = CGImage(jpegDataProviderSource: provider,
                                     decode: nil,
                                     shouldInterpolate: true,
                                     intent: .defaultIntent) else { return nil }

        return UIImage(cgImage: imageRef)
    }
}

@objc public class RDMPEGSubtitleFrame: RDMPEGFrame {
    @objc public var text: String

    @objc public init(position: TimeInterval, duration: TimeInterval, text: String) {
        self.text = text
        super.init(type: .subtitle, position: position, duration: duration)
    }
}
