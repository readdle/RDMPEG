//
//  RDMPEGTextureSampler.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Metal

protocol RDMPEGTextureSampler {
    func newSamplingFunction(from library: MTLLibrary) -> MTLFunction?

    func setupTextures(with device: MTLDevice, frameWidth: Int, frameHeight: Int)

    func updateTextures(with videoFrame: RDMPEGVideoFrame, renderEncoder: MTLRenderCommandEncoder)
}
