Pod::Spec.new do |s|
  s.name         = "anfema-mockingbird"
  s.version      = "2.0.0"
  s.summary      = "HTTP-Response mocking for iOS and OS X."
  s.description  = <<-DESC
                   HTTP-Response mocking for iOS and OS X

                   Features:
                   - Intercepts all requests going through the NSURLSession interface
                   - Allows to send binary files
                   - Mocking dataset may be changed at all times to mock server data changes
                   - Data is organized in bundles that are easy to maintain
                   DESC

  s.homepage     = "https://github.com/anfema/Mockingbird"
  s.license      = { :type => "BSD", :file => "LICENSE.txt" }
  s.author             = { "Johannes Schriewer" => "j.schriewer@anfe.ma" }
  s.social_media_url   = "http://twitter.com/dunkelstern"

  s.ios.deployment_target = "8.4"
  s.osx.deployment_target = "10.10"

  s.source       = { :git => "https://github.com/anfema/Mockingbird.git", :tag => "2.0.0" }
  s.source_files  = "src/*.swift"
  
  s.framework  = "Alamofire", "DEjson"

  s.dependency "Alamofire", "~> 4.2"
  s.dependency "DEjson"
end
