Pod::Spec.new do |s|
    s.name         = 'FuguConference'
    s.version      = '0.0.1'
    s.summary      = 'FuguConference'
    s.homepage     = 'https://github.com/Jungle-Works/Hippo-iOS-SDK'
    s.documentation_url = 'https://github.com/Jungle-Works/Hippo-iOS-SDK'
    
    s.license      = { :type => 'MIT', :file => 'FILE_LICENSE' }
    
    s.author             = { 'Vishal Jhanjhri' => 'jhanjhri.vishal@gmail.com' }
    
    s.source       = { :git => 'https://github.com/Jungle-Works/Hippo-iOS-SDK.git', :tag => s.version }
    s.ios.deployment_target = '9.0'
    s.source_files = 'ConferenceCall/**/*.{swift,h,m}'
    
    s.vendored_frameworks =  'ConferenceCall/JitsiMeet.framework'
   
    
end
