//
//  FuguColor.swift
//  FuguShare
//
//  Created by Rishi pal on 24/11/19.
//  Copyright © 2019 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import UIKit

public extension UIColor {
    public static  var iDarkBlue: UIColor  {
        get {
           return UIColor.init(hex: 0x4facfe)
        }
    }
    
    public static var iLightBlue: UIColor {
        get {
            return UIColor.init(hex: 0x00c8fe)
        }
    }
    
    public static var iTealish : UIColor {
        get {
            return UIColor.init(hex: 0x3bd5b2)
        }
    }
    
    public static var iLightWhite: UIColor {
        get {
            return UIColor.init(hex: 0xf9f9f9)
        }
    }
    
    public static var iWhite: UIColor {
        get {
            return UIColor.init(hex: 0xffffff)
        }
    }
    
    public  static var iLightBlack: UIColor {
        get {
            return UIColor.init(hex: 0x2f2f2f)
        }
    }
    
    public static var iBlueyGrey: UIColor {
        get {
            return UIColor.init(hex: 0xb3bec9)
        }
    }
    
    public static var iRed: UIColor {
        get {
            return UIColor.init(hex: 0xd0021b)
        }
    }
    
    public static var iInTaggingColor: UIColor {
        get {
            return UIColor.init(hex: 0x064224)
        }
    }
    
    public static var iOutTaggingColor: UIColor {
        get {
            return UIColor.iLightBlue
        }
    }
    
    public static var iMediumPink : UIColor {
        get {
            return UIColor.init(hex: 0xed497c)
        }
    }
    
    public static var iCoolGrey : UIColor {
        get {
            return UIColor.init(hex: 0x8b98a5)
        }
    }
    
}


public struct OutGoingMessageTheme {
    public static var backGoundColor: UIColor {
        return UIColor.iLightWhite
    }
    public static var messageTextColor: UIColor {
        return UIColor.iLightBlack
    }
    public static var timeTextColr: UIColor {
        return UIColor.iBlueyGrey
    }
    public static var font: UIFont {
        return FuguFont.titilliumWebRegular(with: 16)
    }
    public static var imageAndVideoColor: UIColor {
        return UIColor.white
    }
}


public struct IncomingMessageTheme {
    public static var backGoundColor: UIColor {
        return UIColor.iLightBlue
    }
    public static var messageTextColor: UIColor {
        return UIColor.iWhite
    }
    public static var timeTextColr: UIColor {
        return UIColor.iWhite
    }
    
    public static var nochColor: UIColor {
        return UIColor.iDarkBlue
    }
    
    public static var font: UIFont {
        return   FuguFont.titilliumWebRegular(with: 16)
    }
    
    public static var timeFont: UIFont {
        return FuguFont.titilliumWebRegular(with: 14)
    }
    
    public static var sendNameFont: UIFont {
        return FuguFont.titilliumWebSemiBold(with: 15)
    }
    
    public static var imageAndVideoColor: UIColor {
        return UIColor.white
    }
}


public struct MessageSentStatusTheme {
    
    public static var unsentColor: UIColor {
        return UIColor.iBlueyGrey
    }
    
    public static var sentColor: UIColor {
        return UIColor.iBlueyGrey
    }
    
    public static var readColor: UIColor{
        return UIColor.iLightBlue
    }
}

public struct OutgoingCallTheme {
    public static var timeTextColor: UIColor {
        return UIColor.iBlueyGrey
    }
    
    public static var textColor: UIColor {
        return UIColor.iLightBlack
    }
    
    public static var callDurationColor: UIColor {
        return UIColor.iLightBlack
    }
    
    public static var missedCallTextColor: UIColor {
        return UIColor.iLightBlack
    }
    
   
}

public struct InComingCallTheme {
    public static var timeTextColor: UIColor {
        return UIColor.iLightWhite
    }
    
    public static var textColor: UIColor {
        return UIColor.iLightWhite
    }
    
    public static var callDurationColor: UIColor {
        return UIColor.iLightWhite
    }
    
    public static var missedCallTextColor: UIColor {
        return UIColor.iRed
    }
    
    public static var missedCallBGColor: UIColor {
        return UIColor.iMediumPink
    }
    public static var callBGColor: UIColor {
        return UIColor.iTealish
    }
}


public struct ConversationTheme {
    public static var titleColour: UIColor {
        return UIColor.black
    }
    
    public static var subtitleColor: UIColor {
        return UIColor.iBlueyGrey
    }
}




extension CGFloat {
    static func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}


public extension UIColor {
   public static func random() -> UIColor {
        return UIColor(red:   .random(),
                       green: .random(),
                       blue:  .random(),
                       alpha: 1.0)
    }
}
