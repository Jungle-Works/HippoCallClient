//
//  CallKitHandler.swift
//  HippoCallClient
//
//  Created by soc-admin on 31/12/21.
//

import Foundation
import CallKit
#if canImport(HippoCallClient)
import HippoCallClient
#endif

#if canImport(HippoCallClient)

class CallKitManager: NSObject, CXProviderDelegate {
    
    static var shared = CallKitManager()
    
    // MARK: - Properties
    private static var provider: CXProvider = {
        let nameOfApp = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Hippo"
        let configuration = CXProviderConfiguration(localizedName: nameOfApp)
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        //        configuration.ringtoneSound = "incoming_call.mp3"
        let provider = CXProvider(configuration: configuration)
        return provider
    }()
    
    private var provider = CallKitManager.provider
    
    
    // MARK: - Intializer
    override init() {
        super.init()
        
        provider.setDelegate(self, queue: nil)
    }
    
    
    
    func providerDidReset(_ provider: CXProvider) {
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        CallManager.shared.actionFromCallKit(isAnswered: true) { status in
            status ? action.fulfill() : action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        CallManager.shared.actionFromCallKit(isAnswered: false) { _ in }
        action.fulfill()
    }
    
    // MARK: - Methods
    func reportIncomingCallWith(request: PresentCallRequest, completion: @escaping () -> Void) {
        let update = CXCallUpdate()
        update.hasVideo = request.callType == .audio ? false : true
        update.supportsDTMF = false
        update.supportsHolding = false
        update.supportsUngrouping = false
        update.supportsGrouping = false
        update.localizedCallerName = request.peer.name
        update.remoteHandle = CXHandle(type: .generic, value: "I am calling you!")
        
        provider.reportNewIncomingCall(with: UUID(uuidString: request.callUuid) ?? UUID() , update: update, completion: {
            error in
            print("Call Kit Error in starting call -> \(error.debugDescription)")
            completion()
            return
        })
        
        completion()
    }
}
#endif
