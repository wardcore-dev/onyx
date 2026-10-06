#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint onyx_tor.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'onyx_tor'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'onyx_tor/Sources/onyx_tor/**/*'
  s.dependency 'Flutter'
  # iOS forbids spawning subprocesses (sandbox), unlike every other platform
  # this app targets -- Tor.framework runs the real C tor implementation
  # in-process on a background thread instead. It's configured with the
  # exact same command-line-style flags (ControlPort/SocksPort/DataDirectory)
  # the desktop subprocess uses, so once it's up, the Dart-side control-port
  # client code is identical on every platform.
  s.dependency 'Tor'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'onyx_tor_privacy' => ['onyx_tor/Sources/onyx_tor/PrivacyInfo.xcprivacy']}
end
