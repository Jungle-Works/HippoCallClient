//
//  HippoCallClientDelegate.swift
//  HippoCallClient
//
//  Created by Vishal on 14/11/18.
//  Copyright © 2018 Vishal. All rights reserved.
//

import Foundation


/// Where the current call is in its lifecycle, as reported to the host app.
///
/// Jitsi exposes no way to read this back, so it is derived from the
/// `JitsiMeetViewDelegate` events and the connect watchdog.
public enum HippoCallState: String {
    /// `join` has been requested, waiting for the conference to come up.
    case connecting
    /// The conference was joined — the user is in the call.
    case connected
    /// Still connecting when `HippoCallClient.shared.callConnectTimeout` elapsed.
    /// The call has been torn down by the time this is delivered.
    case timedOut
    /// The conference ended, gracefully or otherwise.
    case ended
}

public protocol HippoCallClientDelegate: AnyObject {
    func loadCallPresenterView(request: CallPresenterRequest) -> CallPresenter?
    func callStarted(isCallStarted : Bool)
    func shareUrlApiCall(url : String)
    /// Called on the main thread every time the call moves to a new state.
    func callStateChanged(_ state: HippoCallState)
}

public extension HippoCallClientDelegate {
    /// Optional: existing conformers keep compiling without implementing it.
    func callStateChanged(_ state: HippoCallState) {}
}
