//
//  FuguFont.swift
//  FuguShare
//
//  Created by Rishi pal on 24/11/19.
//  Copyright © 2019 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import UIKit

public class FuguFont: UIFont {
    
    
    public static func titilliumWebSemiBold(with size: CGFloat = 14) -> UIFont {
        return UIFont.init(name: "TitilliumWeb-SemiBold", size: size)!
    }
    
    public static func titilliumWebRegular(with size: CGFloat = 14) -> UIFont {
        return UIFont.init(name: "TitilliumWeb-Regular", size: size)!
    }

    public static func titilliumWebBold(with size: CGFloat = 14) -> UIFont {
        return UIFont.init(name: "TitilliumWeb-Bold", size: size)!
    }
    
    public static func titilliumWebItalic(with size: CGFloat = 14) -> UIFont {
        return UIFont.init(name: "TitilliumWeb-Italic", size: size)!
    }
    
   public func printAllFont() {
        UIFont.familyNames.forEach({ familyName in
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            print(familyName, fontNames)
        })
    }
    
}
