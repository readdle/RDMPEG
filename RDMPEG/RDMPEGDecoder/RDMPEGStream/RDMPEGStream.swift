//
//  RDMPEGStream.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 18/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa

@objc
public enum RDMPEGStreamCodecType: UInt {
    case unknown
    case h264
    case mp3
    case flac
    case aac
    case opus
    case vorbis
    case wav
}

@objc
public class RDMPEGStream: NSObject {
    @objc public var stream: UnsafeMutablePointer<AVStream>?
    @objc public var streamIndex: UInt = 0
    @objc public var codec: UnsafePointer<AVCodec>?
    @objc public var codecContext: UnsafeMutablePointer<AVCodecContext>?
    @objc public var subtitleEncoding: String?

    @objc public private(set) lazy var languageCode: String? = {
        guard let stream = stream,
              let language = av_dict_get(stream.pointee.metadata, "language", nil, 0),
              let value = language.pointee.value else {
            return nil
        }
        return String(cString: value)
    }()

    @objc public private(set) lazy var info: String? = {
        guard let codecContext = codecContext else {
            return nil
        }

        var buffer = [Int8](repeating: 0, count: 256)
        avcodec_string(&buffer, Int32(buffer.count), codecContext, 1)

        var streamInfo = String(cString: buffer)

        let prefixesToRemove = ["Video: ", "Audio: ", "Subtitle: "]
        for prefix in prefixesToRemove where streamInfo.hasPrefix(prefix) {
            streamInfo = streamInfo.replacingOccurrences(of: prefix, with: "")
            break
        }

        return streamInfo
    }()

    @objc public var canBeDecoded: Bool { codec != nil }

    @objc public var codecType: RDMPEGStreamCodecType {
        switch codecID {
        case AV_CODEC_ID_H264: return .h264
        case AV_CODEC_ID_MP3: return .mp3
        case AV_CODEC_ID_FLAC: return .flac
        case AV_CODEC_ID_AAC: return .aac
        case AV_CODEC_ID_OPUS: return .opus
        case AV_CODEC_ID_VORBIS: return .vorbis
        case AV_CODEC_ID_WAVPACK: return .wav
        default: return .unknown
        }
    }

    deinit {
        avcodec_free_context(&codecContext)
    }

    @objc
    override public class func l4Logger() -> L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGStream")
    }

    private var codecID: AVCodecID {
        return stream?.pointee.codecpar.pointee.codec_id ?? AV_CODEC_ID_NONE
    }
}
