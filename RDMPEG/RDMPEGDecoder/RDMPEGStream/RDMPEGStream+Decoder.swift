//
//  RDMPEGStream+Decoder.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 18/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import Log4Cocoa

extension RDMPEGStream {
    @objc
    public convenience init(stream: UnsafeMutablePointer<AVStream>, atIndex streamIndex: UInt) {
        self.init()
        self.stream = stream
        self.streamIndex = streamIndex

        if let codec = avcodec_find_decoder(stream.pointee.codecpar.pointee.codec_id) {
            var codecContext = avcodec_alloc_context3(codec)
            if let codecContextUnwrapped = codecContext {
                let parametersToContextStatus = avcodec_parameters_to_context(
                    codecContextUnwrapped,
                    stream.pointee.codecpar
                )

                if parametersToContextStatus >= 0 {
                    codecContextUnwrapped.pointee.pkt_timebase = stream.pointee.time_base
                    self.codec = UnsafePointer(codec)
                    self.codecContext = codecContext
                }
                else {
                    let libAVError = LibAVFormatHelpers.errorToString(errorCode: parametersToContextStatus)
                    log4Error("Parameters to context error: \(libAVError)")

                    avcodec_free_context(&codecContext)
                }
            }
            else {
                log4Error("Unable to allocate codec context")
            }
        }
    }

    @objc
    public func openCodec() -> Bool {
        guard let codec = codec, let codecContext = codecContext else {
            return false
        }

        if let subtitleEncoding = subtitleEncoding, !subtitleEncoding.isEmpty {
            if let subCharEnc = codecContext.pointee.sub_charenc {
                free(UnsafeMutableRawPointer(mutating: subCharEnc))
            }

            let encoding = strdup(subtitleEncoding)
            codecContext.pointee.sub_charenc = encoding
        }

        let codecOpenStatus = avcodec_open2(codecContext, codec, nil)
        if codecOpenStatus < 0 {
            log4Error("Codec open error: \(LibAVFormatHelpers.errorToString(errorCode: codecOpenStatus))")
            return false
        }

        return true
    }

    @objc
    public func closeCodec() {
        if let codecContext = codecContext {
            if let subCharEnc = codecContext.pointee.sub_charenc {
                free(UnsafeMutableRawPointer(mutating: subCharEnc))
                codecContext.pointee.sub_charenc = nil
            }

            avcodec_close(codecContext)
        }
    }
}
