//
//  RDMPEGRenderView.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 18/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import UIKit
import MetalKit
import Log4Cocoa

class RDMPEGRenderView: MTKView {
    var videoFrame: CGRect {
        return isAspectFillMode ? bounds : aspectFitVideoFrame
    }
    private(set) var aspectFitVideoFrame: CGRect = .zero
    var isAspectFillMode: Bool = false {
        didSet {
            if isAspectFillMode != oldValue {
                updateVertices()
                render(currentFrame)
            }
        }
    }

    private var isAbleToRender: Bool {
        return frameWidth > 0 && frameHeight > 0
    }
    private let frameWidth: Int
    private let frameHeight: Int
    private let textureSampler: RDMPEGTextureSampler
    private var vertexBuffer: MTLBuffer?
    private var pipelineState: MTLRenderPipelineState?
    private var commandQueue: MTLCommandQueue?
    private var currentFrame: RDMPEGVideoFrame?

    class var l4Logger: L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGRenderView")
    }

    init(frame: CGRect, textureSampler: RDMPEGTextureSampler, frameWidth: Int, frameHeight: Int) {
        self.textureSampler = textureSampler
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight

        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())

        contentMode = .scaleAspectFit
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true

        isPaused = true
        enableSetNeedsDisplay = false

        if isAbleToRender {
            setupRenderingPipeline()
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        drawableSize = CGSize(width: bounds.width * contentScaleFactor,
                              height: bounds.height * contentScaleFactor)

        updateVertices()
    }

    func render(_ videoFrame: RDMPEGVideoFrame?) {
        guard isAbleToRender else {
            log4Assert(videoFrame == nil, "Attempt to render frame in invalid state")
            return
        }

        currentFrame = videoFrame

        guard UIApplication.shared.applicationState == .active,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let renderPassDescriptor = currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = pipelineState,
              let vertexBuffer = vertexBuffer else {
            return
        }

        let viewport = MTLViewport(originX: 0, originY: 0,
                                   width: Double(drawableSize.width),
                                   height: Double(drawableSize.height),
                                   znear: -1, zfar: 1)

        var viewportSize = vector_uint2(UInt32(viewport.width), UInt32(viewport.height))

        renderEncoder.setViewport(viewport)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(RDMPEGVertexInputIndexVertices.rawValue))
        renderEncoder.setVertexBytes(
                &viewportSize,
                length: MemoryLayout<vector_uint2>.size,
                index: Int(RDMPEGVertexInputIndexViewportSize.rawValue)
            )

        if let videoFrame = videoFrame {
            textureSampler.updateTextures(with: videoFrame, renderEncoder: renderEncoder)
        }

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        draw()
    }

    private func setupRenderingPipeline() {
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true

        guard let defaultLibrary = try? device?.makeDefaultLibrary(bundle: Bundle(for: type(of: self))) else {
            log4Assert(false, "Unable to locate default library")
            return
        }

        guard let vertexShader = defaultLibrary.makeFunction(name: "vertexShader") else {
            log4Assert(false, "Loaded library does not have 'vertexShader' function...")
            return
        }

        guard let samplingFunction = textureSampler.newSamplingFunction(from: defaultLibrary) else {
            log4Assert(false, "Loaded library does not have sampling function...")
            return
        }

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexShader
        pipelineStateDescriptor.fragmentFunction = samplingFunction
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        textureSampler.setupTextures(with: device!, frameWidth: frameWidth, frameHeight: frameHeight)

        do {
            pipelineState = try device!.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        }
        catch {
            log4Assert(false, "Unable to create render pipeline: \(error)")
        }

        commandQueue = device!.makeCommandQueue()

        updateVertices()
        listenNotifications()
    }

    private func listenNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    private func updateVertices() {
        guard isAbleToRender else { return }

        let xScale = Double(drawableSize.width) / Double(frameWidth)
        let yScale = Double(drawableSize.height) / Double(frameHeight)
        let scale = isAspectFillMode ? max(xScale, yScale) : min(xScale, yScale)

        let halfWidth = Double(frameWidth) / 2.0
        let halfHeight = Double(frameHeight) / 2.0

        let adjustedWidth = halfWidth * scale
        let adjustedHeight = halfHeight * scale

        let quadVertices: [RDMPEGVertex] = [
            RDMPEGVertex(
                position: vector_float2( Float(adjustedWidth), -Float(adjustedHeight)),
                textureCoordinate: vector_float2(1.0, 1.0)
            ),
            RDMPEGVertex(
                position: vector_float2(-Float(adjustedWidth), -Float(adjustedHeight)),
                textureCoordinate: vector_float2(0.0, 1.0)
            ),
            RDMPEGVertex(
                position: vector_float2(-Float(adjustedWidth), Float(adjustedHeight)),
                textureCoordinate: vector_float2(0.0, 0.0)
            ),
            RDMPEGVertex(
                position: vector_float2( Float(adjustedWidth), -Float(adjustedHeight)),
                textureCoordinate: vector_float2(1.0, 1.0)
            ),
            RDMPEGVertex(
                position: vector_float2(-Float(adjustedWidth), Float(adjustedHeight)),
                textureCoordinate: vector_float2(0.0, 0.0)
            ),
            RDMPEGVertex(
                position: vector_float2( Float(adjustedWidth), Float(adjustedHeight)),
                textureCoordinate: vector_float2(1.0, 0.0)
            )
        ]

        vertexBuffer = device?.makeBuffer(bytes: quadVertices,
                                          length: MemoryLayout<RDMPEGVertex>.stride * quadVertices.count,
                                          options: .storageModeShared)

        updateAspectFitVideoFrame()
    }

    private func updateAspectFitVideoFrame() {
        guard frameWidth > 0, frameHeight > 0 else {
            aspectFitVideoFrame = bounds
            return
        }

        let horizontalAspectRatio = bounds.width / CGFloat(frameWidth)
        let verticalAspectRatio = bounds.height / CGFloat(frameHeight)
        let fitAspectRatio = min(horizontalAspectRatio, verticalAspectRatio)

        let aspectFitVideoSize = CGSize(width: CGFloat(frameWidth) * fitAspectRatio,
                                        height: CGFloat(frameHeight) * fitAspectRatio)

        let aspectFitFrame = CGRect(x: (bounds.width - aspectFitVideoSize.width) / 2.0,
                                    y: (bounds.height - aspectFitVideoSize.height) / 2.0,
                                    width: aspectFitVideoSize.width,
                                    height: aspectFitVideoSize.height)

        aspectFitVideoFrame = CGRect(x: round(aspectFitFrame.origin.x),
                                     y: round(aspectFitFrame.origin.y),
                                     width: round(aspectFitFrame.size.width),
                                     height: round(aspectFitFrame.size.height))

        log4Assert(bounds.contains(aspectFitVideoFrame), "Aspect fit frame should be contained within bounds")
    }

    @objc
    private func applicationDidBecomeActive() {
        render(currentFrame)
    }
}
