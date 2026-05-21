# Hippo Call Client

[![Swift Version](https://img.shields.io/badge/Swift-4.0.x-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platform-ios-lightgrey.svg)](https://cocoapods.org/pods/HippoCallClient)




- [Hippo Chat](https://git.clicklabs.in/publicrepos/Hippo-SDK-iOS) - Checkout Hippo Messaging feature and Video and Audio Call

## Installation

### CocoaPods

Make sure you are running the latest version of [CocoaPods](https://cocoapods.org) by running:

```bash
gem install cocoapods

# (or if the above fails)
sudo gem install cocoapods
```


Update your local specs repo by running:

```bash
pod repo update
```

**Note:** This step is optional, if you updated the specs repo recently.

Add the following lines to your Podfile:

```ruby
pod 'HippoCallClient'
```

Run `pod install` and you're all set!


## Steps 

### 1. Intialize HippoCallClient SDK :
Intialize the client by setting Turn and Stun server credentials:

Put the below in didFinishLaunchingWithOptions

```
HippoCallClient.shared.setCredentials(rawCredentials: <Raw credential json>)
```


### 2.   Assign HippoCallClient Protocol
You have to assign HippoCallClientDelegate to class and then set that class to "HippoCallClient.shared.registerHippoCallClient" function in "didFinishLaunchingWithOptions" and and in "didReceiveIncomingPushWith"
```
func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, forType type: PKPushType) {
HippoCallClient.shared.registerHippoCallClient"(delegate: < HippoCallClientDelegate >)
}
```
### 3.  Finally  Start call
To start call Function :
```
HippoCallClient.shared.startCall(call: Call, completion: @escaping (Bool) -> Void)
```

where "Call" is SDK Class, create variable and pass it to above function

```
: create object by:
Call.init(peer: <CallPeer>, signalingClient: <SignalingClient>, uID: <String>, currentUser: <CallPeer>, type: <CallType>)
```


## Voip notification recieved

When you recieve a voip notification Call the function 
```
HippoCallClient.shared.voipNotificationRecieved(dictionary: [AnyHashable: Any], peer: <CallPeer>, signalingClient: <SignalingClient>, currentUser: <CallPeer>)"
```

## Give Feedback

HippoCallClient SDK is still in development, and we would love to hear your thoughts and feedback on it.

- **Have an idea or feature request?** [Open an issue](https://github.com/Jungle-Works/hippocallclient/issues/new). Tell us more about the feature or an idea and why you think it's relevant.
- **Have a bug to report?** [Open an issue](https://github.com/Jungle-Works/hippocallclient/issues/new). If possible, include the version of the SDK you are using, and any technical details.
