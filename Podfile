source 'https://github.com/CocoaPods/Specs'

use_frameworks!

def shared_pods
    pod 'Alamofire', '~> 4.2'
    pod 'DEjson', :git => 'https://github.com/anfema/DEjson', :branch => 'swift_3'
end

target 'mockingbird_ios' do
	platform :ios, '8.4'
	shared_pods
end

target 'mockingbird_ios_host' do
	platform :ios, '8.4'
	shared_pods
end

target 'mockingbird_ios tests' do
	platform :ios, '8.4'
	shared_pods
end

target 'mockingbird_osx' do
	platform :osx, '10.10'
	shared_pods
end

target 'mockingbird_osx_host' do
	platform :osx, '10.10'
	shared_pods
end

target 'mockingbird_osx tests' do
	platform :osx, '10.10'
	shared_pods
end
