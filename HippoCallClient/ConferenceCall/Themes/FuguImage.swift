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
        guard let bundleURL = podBundle.url(forResource: "HippoCallClient", withExtension: "bundle"), let fetchBundle = Bundle(url: bundleURL) else {
            return nil
        }
        return fetchBundle
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
