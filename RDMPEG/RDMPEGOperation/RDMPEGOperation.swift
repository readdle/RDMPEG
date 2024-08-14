//
//  RDMPEGOperation.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 16/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation

open class RDMPEGOperation: Operation, @unchecked Sendable {
    private var _executing: Bool = false
    private var _finished: Bool = false

    override public var isAsynchronous: Bool {
        return true
    }

    override public var isExecuting: Bool {
        return _executing
    }

    override public var isFinished: Bool {
        return _finished
    }

    override public func start() {
        if isCancelled {
            willChangeValue(forKey: "isFinished")
            _finished = true
            didChangeValue(forKey: "isFinished")
            return
        }

        willChangeValue(forKey: "isExecuting")
        _executing = true
        main()
        didChangeValue(forKey: "isExecuting")
    }

    func completeOperation() {
        willChangeValue(forKey: "isFinished")
        willChangeValue(forKey: "isExecuting")

        _executing = false
        _finished = true

        didChangeValue(forKey: "isExecuting")
        didChangeValue(forKey: "isFinished")
    }
}
