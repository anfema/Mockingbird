source 'https://cdn.cocoapods.org/'

use_frameworks!

def shared_pods
    pod 'Alamofire', '~> 4.7'
    pod 'DEjson', :git => 'https://github.com/anfema/DEjson', :branch => 'master'
end

target 'mockingbird_ios' do
	platform :ios, '13.0'
	shared_pods
end

target 'mockingbird_ios_host' do
	platform :ios, '13.0'
	shared_pods
end

target 'mockingbird_ios tests' do
	platform :ios, '13.0'
	shared_pods
end

target 'mockingbird_osx' do
	platform :osx, '11.0'
	shared_pods
end

target 'mockingbird_osx_host' do
	platform :osx, '11.0'
	shared_pods
end

target 'mockingbird_osx tests' do
	platform :osx, '11.0'
	shared_pods
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.name == 'Alamofire-iOS' || target.name == 'Alamofire-macOS'
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
      end
    end
  end
end
