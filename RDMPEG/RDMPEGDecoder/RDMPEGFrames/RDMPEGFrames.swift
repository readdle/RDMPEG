//
//  RDMPEGFrames.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

// swiftlint:disable file_types_order

import UIKit

@objc
public enum RDMPEGFrameType: UInt {
    case audio
    case video
    case artwork
    case subtitle
}

@objcMembers
public class RDMPEGFrame: NSObject {
    public let type: RDMPEGFrameType
    public var position: TimeInterval
    public var duration: TimeInterval

    public init(type: RDMPEGFrameType, position: TimeInterval, duration: TimeInterval) {
        self.type = type
        self.position = position
        self.duration = duration
        super.init()
    }
}

@objcMembers
public class RDMPEGAudioFrame: RDMPEGFrame {
    public var samples: Data

    public init(position: TimeInterval, duration: TimeInterval, samples: Data) {
        self.samples = samples
        super.init(type: .audio, position: position, duration: duration)
    }
}

@objcMembers
public class RDMPEGVideoFrame: RDMPEGFrame {
    public var width: UInt
    public var height: UInt

    public init(position: TimeInterval, duration: TimeInterval, width: UInt, height: UInt) {
        self.width = width
        self.height = height
        super.init(type: .video, position: position, duration: duration)
    }
}

@objcMembers
public class RDMPEGVideoFrameBGRA: RDMPEGVideoFrame {
    public var linesize: UInt
    public var bgra: Data

    public init(position: TimeInterval, duration: TimeInterval, width: UInt, height: UInt, bgra: Data, linesize: UInt) {
        self.bgra = bgra
        self.linesize = linesize
        super.init(position: position, duration: duration, width: width, height: height)
    }

    public func asImage() -> UIImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let provider = CGDataProvider(data: bgra as CFData)

        guard let imageRef = CGImage(
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: Int(linesize),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ),
            provider: provider!,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return UIImage(cgImage: imageRef)
    }
}

@objcMembers
public class RDMPEGVideoFrameYUV: RDMPEGVideoFrame {
    public var luma: Data
    public var chromaB: Data
    public var chromaR: Data

    public init(
        position: TimeInterval,
        duration: TimeInterval,
        width: UInt,
        height: UInt,
        luma: Data,
        chromaB: Data,
        chromaR: Data
    ) {
        self.luma = luma
        self.chromaB = chromaB
        self.chromaR = chromaR
        super.init(position: position, duration: duration, width: width, height: height)
    }
}

@objcMembers
public class RDMPEGArtworkFrame: RDMPEGFrame {
    public var picture: Data

    public init(picture: Data) {
        self.picture = picture
        super.init(type: .artwork, position: 0, duration: 0)
    }

    public func asImage() -> UIImage? {
        guard let provider = CGDataProvider(data: picture as CFData) else { return nil }

        guard let imageRef = CGImage(jpegDataProviderSource: provider,
                                     decode: nil,
                                     shouldInterpolate: true,
                                     intent: .defaultIntent) else { return nil }

        return UIImage(cgImage: imageRef)
    }
}

@objcMembers
public class RDMPEGSubtitleFrame: RDMPEGFrame {
    public var text: String

    public init(position: TimeInterval, duration: TimeInterval, text: String) {
        self.text = text
        super.init(type: .subtitle, position: position, duration: duration)
    }
}

// swiftlint:enable file_types_order
