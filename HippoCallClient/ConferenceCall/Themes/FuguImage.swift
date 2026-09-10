//
//  FuguImage.swift
//  HippoCallClient
//
//  Created by Shubham Sharma on 21/04/20.
//  Copyright © 2020 Vishal. All rights reserved.
//

import UIKit

class FuguImage {
    
    fileprivate class var bundle: Bundle? {

        let podBundle = Bundle(for: FuguImage.self)
        // Resources may sit in a nested `HippoCallClient.bundle` (resource_bundles) or,
        // depending on packaging, directly inside the framework bundle. Try the nested
        // one first, then fall back to the framework itself, then the main app bundle.
        if let bundleURL = podBundle.url(forResource: "HippoCallClient", withExtension: "bundle"),
           let fetchBundle = Bundle(url: bundleURL) {
            return fetchBundle
        }
        if podBundle.url(forResource: "connectCall", withExtension: "png") != nil
            || podBundle.path(forResource: "Assets", ofType: "car") != nil {
            return podBundle
        }
        if let mainNested = Bundle.main.url(forResource: "HippoCallClient", withExtension: "bundle"),
           let fetchBundle = Bundle(url: mainNested) {
            return fetchBundle
        }
        return podBundle
    }
    
    class var userImagePlaceholder:UIImage? {
        UIImage(named: "user_image_placeholder", in: self.bundle, compatibleWith: nil)
    }
    
    class var callAccept :UIImage? {
        UIImage(named: "connectCall", in: self.bundle, compatibleWith: nil)
    }
    
    class var callReject :UIImage? {
        UIImage(named: "disconnectCall", in: self.bundle, compatibleWith: nil)
    }

}
