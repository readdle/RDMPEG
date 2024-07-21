//
//  RDMPEGTextureSamplerYUV.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Metal
import Log4Cocoa

class RDMPEGTextureSamplerYUV: NSObject, RDMPEGTextureSampler {
    private var yTexture: MTLTexture?
    private var uTexture: MTLTexture?
    private var vTexture: MTLTexture?

    func newSamplingFunction(from library: MTLLibrary) -> MTLFunction? {
        return library.makeFunction(name: "samplingShaderYUV")
    }

    func setupTextures(with device: MTLDevice, frameWidth: Int, frameHeight: Int) {
        guard yTexture == nil, uTexture == nil, vTexture == nil else {
            assertionFailure("Textures are already created")
            return
        }

        let yTextureDescriptor = MTLTextureDescriptor()
        yTextureDescriptor.pixelFormat = .r8Unorm
        yTextureDescriptor.width = frameWidth
        yTextureDescriptor.height = frameHeight

        let uvTextureDescriptor = MTLTextureDescriptor()
        uvTextureDescriptor.pixelFormat = .r8Unorm
        uvTextureDescriptor.width = frameWidth / 2
        uvTextureDescriptor.height = frameHeight / 2

        yTexture = device.makeTexture(descriptor: yTextureDescriptor)
        uTexture = device.makeTexture(descriptor: uvTextureDescriptor)
        vTexture = device.makeTexture(descriptor: uvTextureDescriptor)
    }

    func updateTextures(with videoFrame: RDMPEGVideoFrame, renderEncoder: MTLRenderCommandEncoder) {
        guard let yTexture = yTexture, let uTexture = uTexture, let vTexture = vTexture else {
            assertionFailure("setupTextures(with:frameWidth:frameHeight:) must be called before updating textures")
            return
        }

        guard let yuvFrame = videoFrame as? RDMPEGVideoFrameYUV else {
            assertionFailure("Invalid video frame type")
            return
        }

        guard yTexture.width == videoFrame.width,
              yTexture.height == videoFrame.height,
              uTexture.width == videoFrame.width / 2,
              uTexture.height == videoFrame.height / 2,
              vTexture.width == videoFrame.width / 2,
              vTexture.height == videoFrame.height / 2 else {
            log4Assert(false, "Video frame size (\(videoFrame.width) \(videoFrame.height)) does not correspond to texture sizes Y(\(yTexture.width) \(yTexture.height)) U(\(uTexture.width) \(uTexture.height)) V(\(vTexture.width) \(vTexture.height))")
            return
        }

        let yRegion = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                size: MTLSize(width: Int(videoFrame.width), height: Int(videoFrame.height), depth: 1))

        let uvRegion = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                 size: MTLSize(width: Int(videoFrame.width) / 2, height: Int(videoFrame.height) / 2, depth: 1))

        yuvFrame.luma.withUnsafeBytes { lumaBuffer in
            if let lumaBufferBasePointer = lumaBuffer.baseAddress {
                yTexture.replace(region: yRegion, mipmapLevel: 0, withBytes: lumaBufferBasePointer, bytesPerRow: Int(videoFrame.width))
            }
        }
        
        yuvFrame.chromaB.withUnsafeBytes { chromaBBuffer in
            if let chromaBBufferBasePointer = chromaBBuffer.baseAddress {
                uTexture.replace(region: uvRegion, mipmapLevel: 0, withBytes: chromaBBufferBasePointer, bytesPerRow: Int(videoFrame.width) / 2)
            }
        }

        yuvFrame.chromaR.withUnsafeBytes { chromaRBuffer in
            if let chromaRBufferBasePointer = chromaRBuffer.baseAddress {
                vTexture.replace(region: uvRegion, mipmapLevel: 0, withBytes: chromaRBufferBasePointer, bytesPerRow: Int(videoFrame.width) / 2)
            }
        }

        renderEncoder.setFragmentTexture(yTexture, index: Int(RDMPEGTextureIndexY.rawValue))
        renderEncoder.setFragmentTexture(uTexture, index: Int(RDMPEGTextureIndexU.rawValue))
        renderEncoder.setFragmentTexture(vTexture, index: Int(RDMPEGTextureIndexV.rawValue))
    }
}
