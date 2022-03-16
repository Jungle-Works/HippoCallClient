//
//  SetUrk.swift
//  HippoCallClient
//
//  Created by soc-admin on 03/12/21.
//

import Foundation


@objcMembers public class HippoCallClientUrl : NSObject{
    
    public static var shared = HippoCallClientUrl()
    
    public static var baseUrl = ""
    public static var urlType: Environment = Environment.dev
    
    public var id: Int!
    public var enUserId: String!
    public var appSecretKey: String!
    public var channelId: String!
    public var userName: String!
    public var callingType = 2
    public var agentToken: String!
    public var userType: userType = .customer
    
}

public enum Environment {
    case live, dev, beta
}

public enum userType {
    case customer
    case agent
}
