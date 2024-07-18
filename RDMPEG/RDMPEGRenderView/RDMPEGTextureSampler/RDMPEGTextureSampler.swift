//
//  RDMPEGTextureSampler.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Metal

@objc public protocol RDMPEGTextureSampler: NSObjectProtocol {
    @objc func newSamplingFunction(from library: MTLLibrary) -> MTLFunction?

    @objc func setupTextures(with device: MTLDevice, frameWidth: Int, frameHeight: Int)

    @objc func updateTextures(with videoFrame: RDMPEGVideoFrame, renderEncoder: MTLRenderCommandEncoder)
}
