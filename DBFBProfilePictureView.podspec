Pod::Spec.new do |s|
  s.name     = 'DBFBProfilePictureView'
  s.version  = '1.6'
  s.platform = :ios, '7.0'
  s.summary  = 'Improved Facebook profile picture view using AFNetworking2.'
  s.homepage = 'https://github.com/combinatorial/DBFBProfilePictureView'
  s.license  = 'Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)'
  s.author   = { 'David Brittain' => 'combinatorial@gmail.com' }
  s.social_media_url = 'https://twitter.com/combinatorial'
  s.source   = { :git => 'https://github.com/Rawrcoon/DBFBProfilePictureView.git', :tag => '1.6' }
  s.requires_arc = true
  s.source_files = 'DBFBProfilePictureView'
  s.dependency 'AFNetworking', '>= 2.2'
  s.dependency 'FBSDKCoreKit', '~> 4.3'
  s.compiler_flags = '-DUSE_AFNETWORKING_2'
  s.framework    = 'QuartzCore', 'MobileCoreServices', 'SystemConfiguration'

  s.prefix_header_contents = <<-EOS
    #import <SystemConfiguration/SystemConfiguration.h>
    #import <MobileCoreServices/MobileCoreServices.h>
  EOS

end
