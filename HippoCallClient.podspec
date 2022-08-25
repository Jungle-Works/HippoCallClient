Pod::Spec.new do |s|
    s.name         = 'HippoCallClient'
    s.version      = '1.0.9'
    s.summary      = 'Hippo Call Client'
    s.description  = <<-DESC
                    Hippo Call Client to perform high quality video call and audio call
                    DESC

    s.homepage     = 'https://github.com/Jungle-Works/HippoCallClient.git'
    s.license      = { :type => 'MIT', :file => 'FILE_LICENSE' }
    s.author       = { 'Vishal Jhanjhri' => 'jhanjhri.vishal@gmail.com' }

    s.ios.deployment_target = '12.0'
    s.source       = { :git => 'https://github.com/Jungle-Works/HippoCallClient.git', :tag => s.version}

    s.swift_version = '4.2'
    s.source_files  = 'HippoCallClient/**/*.{h,m,swift,xib,storyboard}'
    
    s.resource_bundles = {
      'HippoCallClient' =>
      ['HippoCallClient/Assets/**/*.imageset', 'HippoCallClient/ConferenceCall/NewConferenceViewAndLogic/**/*.xib']
    }
    s.resources = ['HippoCallClient/*.xcassets']
    s.exclude_files = 'Classes/Exclude'
    s.static_framework = false
    s.preserve_paths = 'README.md'
    s.dependency 'JitsiMeetSDK', '5.1.0'
#    s.vendored_frameworks =  ['Conference/ConferenceCall/ConferenceCall/JitsiMeetSDK.framework',
#                              'Conference/ConferenceCall/ConferenceCall/WebRTC.framework',
#                              'Conference/ConferenceCall/ConferenceCall/GiphyUISDK.framework']
   # s.dependency 'Kingfisher'

    s.pod_target_xcconfig = { 'ENABLE_BITCODE' => 'No' }
end
