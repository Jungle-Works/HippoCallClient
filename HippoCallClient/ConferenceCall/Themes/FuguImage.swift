//
//  FuguImage.swift
//  HippoCallClient
//
//  Created by Shubham Sharma on 21/04/20.
//  Copyright © 2020 Vishal. All rights reserved.
//

import UIKit

class FuguImage {

    /// Every bundle the call images can end up in, most likely first.
    ///
    /// Where the asset catalog lands depends on packaging: the nested
    /// `HippoCallClient.bundle` (resource_bundles) inside the framework with
    /// `use_frameworks!`, the framework root, or the main app bundle for static
    /// linking. `Bundle(identifier:)` comes first because it is the bundle the call
    /// nibs are loaded from, so it is known to resolve on device.
    private static let candidateBundles: [Bundle] = {
        let roots = [Bundle(identifier: "org.cocoapods.HippoCallClient"),
                     Bundle(for: FuguImage.self),
                     Bundle.main].compactMap { $0 }
        var result: [Bundle] = []
        for root in roots {
            if let url = root.url(forResource: "HippoCallClient", withExtension: "bundle"),
               let nested = Bundle(url: url) {
                result.append(nested)
            }
            result.append(root)
        }
        return result
    }()

    /// First real image named `name` across `candidateBundles`.
    ///
    /// When a nib references an image its own bundle cannot resolve, UIKit substitutes
    /// a 1x1 placeholder instead of nil — that placeholder is what left the call
    /// buttons blank (white, tappable, 1pt image). Anything that small is treated as
    /// missing so a later bundle gets its turn.
    class func image(named name: String) -> UIImage? {
        for bundle in candidateBundles {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil),
               image.size.width > 1, image.size.height > 1 {
                return image
            }
        }
        return nil
    }

    class var userImagePlaceholder:UIImage? {
        image(named: "user_image_placeholder")
    }

    class var callAccept :UIImage? {
        image(named: "connectCall")
            ?? drawnCallButton(symbol: "phone.fill", fill: UIColor(red: 0.20, green: 0.73, blue: 0.29, alpha: 1))
    }

    class var callReject :UIImage? {
        image(named: "disconnectCall")
            ?? drawnCallButton(symbol: "phone.down.fill", fill: UIColor(red: 0.82, green: 0.01, blue: 0.11, alpha: 1))
    }

    /// Last resort when no bundle yields the asset: a filled circle with a white SF
    /// Symbol, matching the asset's look, so the button is never invisible.
    private class func drawnCallButton(symbol: String, fill: UIColor) -> UIImage? {
        let side: CGFloat = 60
        let config = UIImage.SymbolConfiguration(pointSize: side * 0.4, weight: .semibold)
        guard let glyph = UIImage(systemName: symbol, withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) else { return nil }
        let canvas = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: canvas).image { ctx in
            fill.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: canvas))
            glyph.draw(at: CGPoint(x: (side - glyph.size.width) / 2,
                                   y: (side - glyph.size.height) / 2))
        }
    }

}
