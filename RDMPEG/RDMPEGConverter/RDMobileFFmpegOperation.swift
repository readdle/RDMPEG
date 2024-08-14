//
//  RDMobileFFmpegOperation.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 16/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation
import ffmpegkit
import Log4Cocoa

@objcMembers
public class RDMobileFFmpegOperation: RDMPEGOperation, @unchecked Sendable {

    public typealias StatisticsBlock = (RDMobileFFmpegStatistics) -> Void
    public typealias ResultBlock = (Int32) -> Void
    public typealias LogBlock = (String, Int32) -> Void

    private let arguments: [String]
    private let resultBlock: ResultBlock
    private let statisticsBlock: StatisticsBlock
    private let logBlock: LogBlock?
    private var session: FFmpegSession?

    public init(arguments: [String], statisticsBlock: @escaping StatisticsBlock, resultBlock: @escaping ResultBlock) {
        self.arguments = arguments
        self.statisticsBlock = statisticsBlock
        self.resultBlock = resultBlock
        self.logBlock = nil
        super.init()
    }

    public init(
        arguments: [String],
        statisticsBlock: @escaping StatisticsBlock,
        resultBlock: @escaping ResultBlock,
        logBlock: LogBlock?
    ) {
        self.arguments = arguments
        self.statisticsBlock = statisticsBlock
        self.resultBlock = resultBlock
        self.logBlock = logBlock
        super.init()
    }

    override public func main() {
        assert(session == nil)

        session = FFmpegKit.execute(
            withArgumentsAsync: arguments,
            withExecuteCallback: { [weak self] session in
                guard let self, let session else { return }

                self.resultBlock(session.getReturnCode().getValue())
                self.completeOperation()
            },
            withLogCallback: { [weak self] log in
                guard let self, let log else { return }

                if let logBlock = self.logBlock {
                    logBlock(log.getMessage() ?? "", log.getLevel())
                }

                log4Debug("level: \(log.getLevel()), message: \(log.getMessage() ?? "")")
            },
            withStatisticsCallback: { [weak self] statistics in
                guard let self, let statistics else { return }

                self.statisticsBlock(RDMobileFFmpegStatistics(statistics: statistics))
            }
        )
    }

    override public func cancel() {
        super.cancel()

        if let sessionId = session?.getId() {
            FFmpegKit.cancel(sessionId)
        }
    }

    public class func isReturnCodeCancel(_ code: Int32) -> Bool {
        return code == ReturnCodeEnum.cancel.rawValue
    }

    public class func isReturnCodeSuccess(_ code: Int32) -> Bool {
        return code == ReturnCodeEnum.success.rawValue
    }
}
