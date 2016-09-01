# MockingBird HTTP mocking

MockingBird is a relatively simple and powerful HTTP/HTTPS response mocking library written in swift to be used in unit-tests for OSX and iOS apps.

## What can it do

MockingBird can intercept all calls to HTTP and HTTPS urls in a running App and return predefined answers.

Answers are packages in so called Mock-Bundles (just a directory and some files) and you can switch between different Mock-Bundles at all times. This can be used for simulating state on the server.

## How to integrate

MockingBird is essentially only one Swift file (`mockingbird.swift`) but needs some Mock-Bundles to work.

### CocoaPods

Just include `pod 'anfema-mockingbird', '~> 1.0'` in your `Podfile`

### Manual

Just drop `mockingbird.swift` into your project.

### Registering MockingBird with the URL loading system

MockingBird makes it easy for you to register in `NSURLSession` objects, just call:

~~~swift
let session:NSURLSession = ...
MockingBird.registerInSession(session)
~~~

If you're using _Alamofire_ you likely have access to the session configuration when creating your `Alamofire.Manager`:

~~~swift
let configuration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
MockingBird.registerInConfig(configuration)
~~~

## How to mock

To mock responses you'll have to define which requests match to which answers, this is done in a Mock-Bundle which has the following structure on disk:

- `bundle.json`
- ... files referenced in `bundle.json` ...

### `bundle.json`

Bundle JSON is a JSON Array with Objects that contain two base objects, `request` and `response`:

#### request

- `method`: (optional) HTTP method, defaults to `GET`
- `url`: URL to mock, start with `://` (skip the http)
- `parameters`: (optional) JSON object with key-value items for query parameters, defaults to empty, if the parameter value is `null` it just checks if the parameter is available but not which value it has

#### response

- `code`: HTTP response code
- `headers`: (optional) Additional response headers, defaults to empty
- `file`: (optional) filename of data to send, defaults to "do not send additional data"
- `mime_type`: (optional) MIME type of the response body, defaults to `application/octet-stream`

#### Example `bundle.json`

~~~json
[
	{
		"request": {
			"url": "://httpbin.org/ip"
		},

		"response" : {
			"code": 200,
			"file": "ip.json",
			"mime_type": "application/json"
		}
	}
]
~~~

### Setting up a mock bundle

To include a Mock-Bundle into an unit test, create your bundle somewhere and add it as a folder reference (not a group) to your Xcode project and set the Target for the files to your unit test (so do __not__ include a mock bundle into your app-target)

#### Alamofire example 

Then add the following code to your test (example for _Alamofire_):

~~~swift
import anfema_mockingbird  // needed only for install via cocoapods
import Alamofire

class mockingbirdTests: XCTestCase {
    var alamofire: Alamofire.Manager! = nil
    
    override func setUp() {
        super.setUp()
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        MockingBird.registerInConfig(configuration)
        self.alamofire = Alamofire.Manager(configuration: configuration)

        let bundle = NSBundle(forClass: self.dynamicType).resourcePath! + "/bundles/httpbin"
        do {
            try MockingBird.setMockBundle(bundle)
        } catch {
            XCTFail("Could not reset mock bundle")
        }
    }
}
~~~

The interesting thing here is how to get to the Mock-Bundle path:

~~~swift
let bundle = NSBundle(forClass: self.dynamicType).resourcePath! + "/bundles/httpbin"
~~~

`bundles/httpbin` is the name of your bundle folder reference you included.

Now every HTTP(S) request that will be sent through `self.alamofire` will be checked for a match in the Mocking-Bundle, if there is a match it will return the predefined answer, else the request goes through to the network as usual.

#### Default URL-Loading system

You can register the MockingBird on an even lower level if you have not converted to using `NSURLSession` yet:

~~~swift
NSURLProtocol.registerClass(MockingBird)
~~~

But beware, if you're using an `NSURLSession` with this set, it will not work for the sessions, this one works only for the old version without `NSURLSession`

#### Handle all requests

By default, if a request does not match an entry in the current Mocking-Bundle, the request is passed through to the network as usual.  If you would like any request that does not match to fail, set the `handleAllRequests` property to true.

~~~swift
MockingBird.handleAllRequests = true
~~~

When this property is set to true, requests that do not match the current Mocking-Bundle will fail with an HTTP error status of 501.
