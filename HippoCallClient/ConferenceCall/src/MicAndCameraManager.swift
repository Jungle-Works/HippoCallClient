//
//  MicAndCameraManager.swift
//  OfficeChat
//
//  Created by Rishi pal on 09/05/19.
//  Copyright © 2019 Fugu-Click Labs Pvt. Ltd. All rights reserved.
//

import Foundation
import AVFoundation
import UserNotifications
import UIKit

struct MicAndCameraPermissionResponse {
    var isDenied: Bool = false
    var message: String = ""
}

enum CallType: Int {
    case `in`
    case `out`
}

enum PermissionType: Int {
    case mic
    case camera
    case both
}

class  FUGUMicAndCameraManager {
    var premissionType: PermissionType = .mic
    var callType: CallType = .out
    
     init() {
        
    }
    
    init(with permission: PermissionType, call type: CallType) {
        premissionType = permission
        callType = type
    }
    
    let micMessageToInCall = "TO answer calls, FUGU needs access to your iphone's microphone. tap settings and turn on microphone."
    let micMessageToInOutCall = "TO place calls, FUGU needs access to your iPhone's microphone. Tap settings and turn on microphone."
    let cameraMessageToOutCall = "To Place calls, FUGU needs access to your iPhone's camera. Tap setting and turn on camera."
    let cameraMessageeToInCall = "TO answer calls, FUGU needs access to your iPhone's camera. Tap setting and turn on camera."
    
    func checkPermission() -> MicAndCameraPermissionResponse {
       
        var message: String
        var mark: Bool
        
        switch (callType , premissionType) {
        case (.in , .mic):
          mark = isRecordPermissionDenied
          message = micMessageToInCall
        case (.in , .camera):
            mark = isCameraPermissionDenied
            message = cameraMessageeToInCall
        case (.in , .both):
            mark = isRecordPermissionDenied
            if mark {
                message = micMessageToInCall
            }else {
                mark = isCameraPermissionDenied
                message = cameraMessageeToInCall
            }
        case (.out , .mic):
            mark = isRecordPermissionDenied
            message = micMessageToInOutCall
        case (.out , .camera):
            mark = isCameraPermissionDenied
            message = cameraMessageToOutCall
        case (.out , .both):
            mark = isRecordPermissionDenied
            if mark {
                message = micMessageToInOutCall
            }else {
                mark = isCameraPermissionDenied
                message = cameraMessageToOutCall
            }
        }
        return MicAndCameraPermissionResponse(isDenied: mark, message: message)
    }
    
    private var isRecordPermissionDenied: Bool {
        get {
            return AVAudioSession.sharedInstance().recordPermission == AVAudioSession.RecordPermission.denied
        }
    }
    
    private  var isCameraPermissionDenied: Bool {
        get {
            return AVCaptureDevice.authorizationStatus(for: .video) == AVAuthorizationStatus.denied
        }
    }
    
    func showSettingAlert(for response: MicAndCameraPermissionResponse) {
        let alertController = UIAlertController (title: "", message: response.message , preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (_) -> Void in
            
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                    print("Settings opened: \(success)") // Prints true
                })
            }
        }
        alertController.addAction(settingsAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let lastViewController = UIApplication.shared.windows.first?.visibleViewController
        if let someVC = lastViewController {
            someVC.present(alertController, animated: true, completion: nil)
        }
    
    }
    
    
    
    
    class func isShowLocalNotificationForAudioCall()->Bool {
        let state =  UIApplication.shared.applicationState
        let recordPermission =  AVAudioSession.sharedInstance().recordPermission
        
        if recordPermission == .granted {
            return false
        }else if state == .active {
            return false
        }else {
            return true
        }
    }
    
}

