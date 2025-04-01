//
//  VideoSdkView.swift
//  HippoCallClient
//
//  Created by soc-admin on 30/12/21.
//

import UIKit
import VideoSDKRTC

class VideoSdkView: UIViewController {
    
    var token = ""
    
    lazy var tfMeetId:UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Enter Meeting ID"
        textField.keyboardType = UIKeyboardType.default
        textField.returnKeyType = UIReturnKeyType.done
        textField.autocorrectionType = UITextAutocorrectionType.no
        textField.font = UIFont.systemFont(ofSize: 13)
        textField.borderStyle = UITextField.BorderStyle.roundedRect
        textField.clearButtonMode = UITextField.ViewMode.whileEditing;
        textField.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        return textField
    }()
    
    lazy var tfName:UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Enter Your Name"
        textField.keyboardType = UIKeyboardType.default
        textField.returnKeyType = UIReturnKeyType.done
        textField.autocorrectionType = UITextAutocorrectionType.no
        textField.font = UIFont.systemFont(ofSize: 13)
        textField.borderStyle = UITextField.BorderStyle.roundedRect
        textField.clearButtonMode = UITextField.ViewMode.whileEditing;
        textField.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        return textField
    }()
    
    lazy var btnJoin: UIButton = {
        let btn = UIButton()
        btn.setTitle("Join", for: .normal)
        btn.setTitleColor(UIColor.white, for: .normal)
        btn.backgroundColor = .darkGray
        return btn
    }()
    
    // meeting
    private var meeting: Meeting?
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tfMeetId.translatesAutoresizingMaskIntoConstraints = false
        tfName.translatesAutoresizingMaskIntoConstraints = false
        btnJoin.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tfMeetId)
        view.addSubview(tfName)
        view.addSubview(btnJoin)
        
        NSLayoutConstraint(item: tfMeetId, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1, constant: 20).isActive = true
        NSLayoutConstraint(item: tfMeetId, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1, constant: -20).isActive = true
        NSLayoutConstraint(item: tfMeetId, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: 140).isActive = true
        NSLayoutConstraint(item: tfMeetId, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 44).isActive = true
        
        NSLayoutConstraint(item: tfMeetId, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: tfName, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: -20).isActive = true
        NSLayoutConstraint(item: tfName, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1, constant: -20).isActive = true
        NSLayoutConstraint(item: tfName, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1, constant: 20).isActive = true
        NSLayoutConstraint(item: tfName, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 44).isActive = true
        
        NSLayoutConstraint(item: tfName, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: btnJoin, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: -40).isActive = true
        NSLayoutConstraint(item: btnJoin, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 120).isActive = true
        NSLayoutConstraint(item: btnJoin, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1, constant: 0).isActive = true
        
        btnJoin.addTarget(self, action: #selector(btnJoinTapped), for: .touchUpInside)
    }
    
    @objc func btnJoinTapped(){
        // create a new meeting instance
        
        VideoSDK.config(token: token)
        
        meeting = VideoSDK.initMeeting(
            meetingId: tfMeetId.text ?? "", // required
            participantName: tfName.text ?? "Test" // required
        )
        
        // listener
//        meeting?.addEventListener(self)
        
        meeting?.join()
    }
}
//
//}
