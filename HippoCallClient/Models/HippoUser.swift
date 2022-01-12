//
//  HippoUser.swift
//  HippoCallClient
//
//  Created by Vishal on 30/10/18.
//

import Foundation

public class HippoUser {
    var fullName: String
    var imageThunbnailUrl: String
    var userId: Int?
    
    
    public init?(json: [String: Any]) {
        fullName = json["full_name"] as? String ?? json["label"] as? String ?? ""
        imageThunbnailUrl = json["thumbnail_url"] as? String ?? json["user_image"] as? String ?? json["image_url"] as? String ?? json["user_thumbnail_image"] as? String ?? ""
        userId = json["user_id"] as? Int ?? -222
        
        fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if fullName.isEmpty {
            fullName = "Visitor"
        }
    }
    
    public init?(name: String, userID: Int, imageURL: String?) {
        fullName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        imageThunbnailUrl = imageURL ?? ""
        userId = userID
        
        if fullName.isEmpty {
            fullName = "Visitor"
        }
    }
    
}

extension HippoUser: CallPeer {
    public var name: String {
        get {
            return fullName
        }
        set {
        }
    }
    
    public var image: String {
        get {
            return imageThunbnailUrl
        }
        set {
        }
    }
    
    
    public var peerId: String {
        return (userId ?? -1).description
    }
    
}
