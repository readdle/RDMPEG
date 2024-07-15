//
//  RDMPEGTextureSamplerBGRA.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Metal
import Log4Cocoa

@objc public class RDMPEGTextureSamplerBGRA: NSObject, RDMPEGTextureSampler {
    private var bgraTexture: MTLTexture?

    @objc public func newSamplingFunction(from library: MTLLibrary) -> MTLFunction? {
        return library.makeFunction(name: "samplingShaderBGRA")
    }

    @objc public func setupTextures(with device: MTLDevice, frameWidth: Int, frameHeight: Int) {
        guard bgraTexture == nil else {
            assertionFailure("Texture is already created")
            return
        }

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = frameWidth
        textureDescriptor.height = frameHeight

        bgraTexture = device.makeTexture(descriptor: textureDescriptor)
    }

    @objc public func updateTextures(with videoFrame: RDMPEGVideoFrame, renderEncoder: MTLRenderCommandEncoder) {
        guard let bgraTexture = bgraTexture else {
            assertionFailure("setupTextures(with:frameWidth:frameHeight:) must be called before updating textures")
            return
        }

        guard let bgraFrame = videoFrame as? RDMPEGVideoFrameBGRA else {
            assertionFailure("Invalid video frame type")
            return
        }

        guard bgraTexture.width == videoFrame.width,
              bgraTexture.height == videoFrame.height else {
            log4Assert(false, "Video frame size (\(videoFrame.width) \(videoFrame.height)) does not equal to texture size (\(bgraTexture.width) \(bgraTexture.height))")
            return
        }

        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(videoFrame.width), height: Int(videoFrame.height), depth: 1))

        bgraFrame.bgra.withUnsafeBytes { bgraBuffer in
            if let bgraBufferBasePointer = bgraBuffer.baseAddress {
                bgraTexture.replace(region: region, mipmapLevel: 0, withBytes: bgraBufferBasePointer, bytesPerRow: 4 * Int(videoFrame.width))
            }
        }

        renderEncoder.setFragmentTexture(bgraTexture, index: Int(RDMPEGTextureIndexBGRABaseColor.rawValue))
    }
}
