#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint video_view_player.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'video_view_player'
  s.version          = '0.2.2'
  s.summary          = 'A high-performance, Reels-style short-form video player plugin.'
  s.description      = <<-DESC
A high-performance, Reels-style short-form video player plugin for Flutter, optimized with aggressive caching and native controller pooling.
                       DESC
  s.homepage         = 'https://github.com/Narukarudra10/video_view_player'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'video_view_player/Sources/video_view_player/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'video_view_player_privacy' => ['video_view_player/Sources/video_view_player/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.11'
  s.frameworks = 'AVFoundation', 'Network', 'MobileCoreServices'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
