//
//  Extensions.swift
//  HippoCallClient
//
//  Created by SUSHIL SHARMA on 11/04/20.
//  Copyright © 2020 Vishal. All rights reserved.
//

import Foundation
import UIKit
//import Kingfisher

public extension UIColor {
   convenience init(hex: Int, alpha: CGFloat = 1.0) {
      let red = CGFloat((hex & 0xFF0000) >> 16) / 255.0
      let green = CGFloat((hex & 0xFF00) >> 8) / 255.0
      let blue = CGFloat((hex & 0xFF)) / 255.0
      self.init(red:red, green:green, blue:blue, alpha:alpha)
   }
   
class var themeColor: UIColor {
      return UIColor(hex: 0x00c8fe)
   }
class var forestgreen: UIColor {
        return UIColor(red: 0/255, green: 128/255, blue: 0/255, alpha: 1)
    }
  
class var textFieldBorderColor: UIColor {
     return UIColor(red: 203/255, green: 203/255, blue: 203/255, alpha: 1)
  }
  
class var screenBackgroundColor: UIColor {
    return UIColor(red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
  }
   
class var defaultTintColor: UIColor {
      return UIColor(red: 0, green: 128/255, blue: 1, alpha: 1)
   }
   
class var fuguRed: UIColor {
      return UIColor(red: 202/255, green: 59/255, blue: 52/255, alpha: 1)
   }
    
class func hexStringToUIColor (hex:String, alpha:CGFloat) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return UIColor.black
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: alpha
        )
    }
}

public extension UIWindow {
     var visibleViewController: UIViewController? {
        return UIWindow.getVisibleViewControllerFrom(self.rootViewController)
    }
    
    static func getVisibleViewControllerFrom(_ vc: UIViewController?) -> UIViewController? {
        if let nc = vc as? UINavigationController {
            return UIWindow.getVisibleViewControllerFrom(nc.visibleViewController)
        } else if let tab = vc as? UITabBarController {
            let moreNavigationController = tab.moreNavigationController
            if let top = moreNavigationController.topViewController, top.view.window != nil {
                return UIWindow.getVisibleViewControllerFrom(top)
            }else{
                return UIWindow.getVisibleViewControllerFrom(tab.selectedViewController)
            }
            
        } else {
            if let pvc = vc?.presentedViewController {
                return UIWindow.getVisibleViewControllerFrom(pvc)
            } else {
                return vc
            }
        }
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}
