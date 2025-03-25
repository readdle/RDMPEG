//
//  libavformat+Helpers.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 18/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

enum LibAVFormatHelpers {
    static func errorToString(errorCode: Int32) -> String {
        String(cString: [Int8](unsafeUninitializedCapacity: Int(AV_ERROR_MAX_STRING_SIZE)) { buffer, initializedCount in
            av_make_error_string(buffer.baseAddress, Int(AV_ERROR_MAX_STRING_SIZE), errorCode)
            initializedCount = Int(AV_ERROR_MAX_STRING_SIZE)
        })
    }
}
