//
//  JitsiConferenceNotification.swift
//  Fugu
//
//  Created by Rishi pal on 17/01/20.
//  Copyright © 2020 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import Foundation
import UserNotifications


class JitsiConferenceNotification {
    static let notifiID = "b92fe9990692a1c62cc414a0iOSFugu"
    static let timeIntervalsforLocalNotification:[TimeInterval] = [7,14,21,28]
    
    static func  clearAllLocalNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notifiID])
        center.removeDeliveredNotifications(withIdentifiers: [notifiID])
    }
    
    static func addThreeLocalNotification(for userInfo:[String : Any]) {
      //  clearAllLocalNotification()
       //setLocalNotification(for: userInfo)
    }
}


extension JitsiConferenceNotification {
    static func setLocalNotification(for userInfo: [String : Any]) {
        let callTypeInMessage = "🎥 Conference Call"
        let title = "Fugu Call"
        let soundName = "ringing.mp3"
        let message = "\(callTypeInMessage) "
        var newData = userInfo
        newData["is_local_nofication"] = true
        
         addLocalNotificationWith(message: message, title: title, soundName: soundName, identifier: notifiID, userInfo: newData, timeInterval: 5)
//        for i in timeIntervalsforLocalNotification {
//
//        }
        
    }
    
    static func addLocalNotificationWith(message: String, title: String, soundName: String?, identifier: String , userInfo: [String : Any], timeInterval: TimeInterval) {
        let content = UNMutableNotificationContent()
        if let someSound = soundName {
          //  let name =  UNNotificationSoundName(someSound)
          // content.sound = UNNotificationSound.init(named: name)
        }
        content.title = title
        content.body = message
        content.subtitle = ""
        content.userInfo = userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let notificationRequest = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if error != nil {
                NSLog("Notification service %@", error?.localizedDescription ?? "error")
                print(error.debugDescription)
            }
        }
    }
}


