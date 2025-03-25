//
//  RDMPEGPlayerView.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 18/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import UIKit
import Log4Cocoa

@objc
public class RDMPEGPlayerView: UIView {
    @objc public var videoFrame: CGRect {
        return renderView?.videoFrame ?? .zero
    }

    @objc public var isAspectFillMode: Bool = false {
        didSet {
            if isAspectFillMode != oldValue {
                renderView?.isAspectFillMode = isAspectFillMode
            }
        }
    }

    private let subtitleLabel: UILabel
    var renderView: RDMPEGRenderView? {
        didSet {
            if renderView !== oldValue {
                oldValue?.removeFromSuperview()

                if let renderView = renderView {
                    renderView.frame = bounds
                    renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    renderView.isAspectFillMode = isAspectFillMode
                    addSubview(renderView)
                    bringSubviewToFront(subtitleLabel)
                }
            }
        }
    }

    var subtitle: String? {
        get { return subtitleLabel.text }
        set {
            subtitleLabel.text = newValue
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        subtitleLabel = UILabel()
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textColor = .white
        subtitleLabel.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        subtitleLabel.clipsToBounds = true
        subtitleLabel.layer.cornerRadius = 2.0

        super.init(frame: frame)

        addSubview(subtitleLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        if subtitleLabel.text?.isEmpty ?? true {
            subtitleLabel.frame = .zero
        }
        else {
            let horizontalSubtitleOffset: CGFloat = 10.0
            let verticalSubtitleOffset: CGFloat = 10.0

            guard let aspectFitVideoFrame = renderView?.aspectFitVideoFrame else { return }

            let subtitleMinX = aspectFitVideoFrame.minX + horizontalSubtitleOffset
            let subtitleMaxY = aspectFitVideoFrame.maxY - verticalSubtitleOffset
            let subtitleMaxWidth = aspectFitVideoFrame.width - horizontalSubtitleOffset * 2.0
            let subtitleMaxHeight = aspectFitVideoFrame.height - verticalSubtitleOffset * 2.0
            let subtitleFitSize = CGSize(width: subtitleMaxWidth, height: subtitleMaxHeight)

            let subtitleSize = subtitleLabel.sizeThatFits(subtitleFitSize)

            let subtitleFrame = CGRect(
                x: subtitleMinX + (subtitleMaxWidth - subtitleSize.width) / 2.0,
                y: subtitleMaxY - subtitleSize.height,
                width: subtitleSize.width,
                height: subtitleSize.height
            )

            subtitleLabel.frame = subtitleFrame.integral
            subtitleLabel.isHidden = (bounds.width < 120.0)
        }
    }
}

extension RDMPEGPlayerView {
    override public class func l4Logger() -> L4Logger {
        return L4Logger(forName: "rd.mediaplayer.RDMPEGPlayerView")
    }
}
