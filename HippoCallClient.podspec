Pod::Spec.new do |s|
    s.name         = 'HippoCallClient'
    s.version      = '0.0.7'
    s.summary      = 'Hippo Call Client'
    s.description  = <<-DESC
                    Hippo Call Client to start video call and audio call
                    DESC

    s.homepage     = 'https://git.clicklabs.in/hippo-public/HippoCallClient'
    s.license      = { :type => 'MIT', :file => 'FILE_LICENSE' }
    s.author       = { 'Vishaljhanjhri' => 'vishal.jhanjhri@jungleworks.com' }

    s.ios.deployment_target = '9.0'
    s.source       = { :git => 'https://git.clicklabs.in/hippo-public/HippoCallClient.git', :tag => s.version}


    s.source_files  = 'HippoCallClient/**/*.{h,m,swift}'
    s.exclude_files = 'Classes/Exclude'
    s.static_framework = false
    s.preserve_paths = 'README.md'
    s.dependency 'GoogleWebRTC', '1.1.24717'

    s.pod_target_xcconfig = { 'ENABLE_BITCODE' => 'No' }
end
