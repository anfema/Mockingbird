//
//  nsurlcache.swift
//  mockingbird
//
//  Created by Johannes Schriewer on 01/12/15.
//  Copyright © 2015 anfema. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the conditions of the 3-clause
// BSD license (see LICENSE.txt for full license text)

import Foundation
import DEjson

internal struct MockBundleEntry {
    var url:String!
    var queryParameters = [String:String?]()
    var requestMethod   = "GET"
    
    var responseCode:Int = 200
    var responseHeaders  = [String:String]()
    var responseFile:String?
    var responseMime:String?
    
    init(json: JSONObject) throws {
        guard case .JSONDictionary(let dict) = json where (dict["request"] != nil && dict["response"] != nil),
              case .JSONDictionary(let request) = dict["request"]! where request["url"] != nil,
              case .JSONDictionary(let response) = dict["response"]! where response["code"] != nil,
              case .JSONString(let url) = request["url"]!,
              case .JSONNumber(let code) = response["code"]!
            else {
            throw MockingBird.Error.InvalidBundleDescriptionFile
        }
        
        self.url = url
        self.responseCode = Int(code)

        if let q = request["parameters"],
           case .JSONDictionary(let query) = q {
                for item in query {
                    if case .JSONString(let value) = item.1 {
                        self.queryParameters[item.0] = value
                    } else if case .JSONNull = item.1 {
                        self.queryParameters[item.0] = nil as String?
                    } else {
                        print("Query parameter \(item.0) has invalid value!")
                    }
                }
        }
        
        if let q = request["method"],
            case .JSONString(let method) = q {
                self.requestMethod = method
        }

        if let q = response["headers"],
            case .JSONDictionary(let headers) = q {
                for item in headers {
                    if case .JSONString(let value) = item.1 {
                        self.responseHeaders[item.0] = value
                    }
                }
        }

        if let q = response["file"],
            case .JSONString(let file) = q {
                self.responseFile = file
        }
        
        if let q = response["mime_type"],
            case .JSONString(let mime) = q {
                self.responseMime = mime
        }
    }
}

public class MockingBird: NSURLProtocol {
    static var currentMockBundle: [MockBundleEntry]?
    static var currentMockBundlePath: String?
    
    // If this is true, we'll claim to answer all URL requests.
    // If this is false, URLs that don't match will be passed on
    //      through to normal handlers.
    public static var handleAllRequests: Bool = false

    public enum Error: ErrorType {
        case MockBundleNotFound
        case InvalidMockBundle
        case InvalidBundleDescriptionFile
    }
    
    /// Register MockingBird with a NSURLSession
    ///
    /// - parameter session: the session to mock
    public class func registerInSession(session: NSURLSession) {
        self.registerInConfig(session.configuration)
    }

    /// Register MockingBird in a NSURLSessionConfiguration
    ///
    /// - parameter config: session configuration to mock
    public class func registerInConfig(config: NSURLSessionConfiguration) {
        var protocolClasses = config.protocolClasses
        if protocolClasses == nil {
            protocolClasses = [AnyClass]()
        }
        protocolClasses!.insert(MockingBird.self, atIndex: 0)
        config.protocolClasses = protocolClasses
    }

    /// Set mock bundle to use
    ///
    /// - parameter bundlePath: path to the bundle
    /// - throws: MockingBird.Error when bundle could not be loaded
    public class func setMockBundle(bundlePath: String?) throws {
        guard let bundlePath = bundlePath else {
            self.currentMockBundle = nil
            self.currentMockBundlePath = nil
            return
        }
        
        do {
            var isDir:ObjCBool = false
            if NSFileManager.defaultManager().fileExistsAtPath(bundlePath, isDirectory: &isDir) && isDir {
                let jsonString = try String(contentsOfFile: "\(bundlePath)/bundle.json")

                let jsonObject = JSONDecoder(jsonString).jsonObject
                if case .JSONArray(let array) = jsonObject {
                    self.currentMockBundle = try array.map { item -> MockBundleEntry in
                        return try MockBundleEntry(json: item)
                    }
                } else {
                    throw MockingBird.Error.InvalidBundleDescriptionFile
                }
            } else {
                throw MockingBird.Error.MockBundleNotFound
            }
        } catch MockingBird.Error.InvalidBundleDescriptionFile {
            throw MockingBird.Error.InvalidBundleDescriptionFile
        } catch {
            throw MockingBird.Error.InvalidMockBundle
        }
        self.currentMockBundlePath = bundlePath
    }
}

// MARK: - URL Protocol overrides
extension MockingBird {
    public override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        // we can only answer if we have a mockBundle
        if self.currentMockBundle == nil {
            return false
        }
        
        // we can answer all http and https requests
        if let _ = self.getBundleItem(request.URL!, method: request.HTTPMethod!) {
            return true
        }
        return self.handleAllRequests
    }

    public override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        // canonical request is same as request
        return request
    }

    public override class func requestIsCacheEquivalent(a: NSURLRequest, toRequest b: NSURLRequest) -> Bool {
        // nothing is cacheable
        return false
    }
    
    public override func startLoading() {
        // fetch item
        guard let entry = MockingBird.getBundleItem(self.request.URL!, method: self.request.HTTPMethod!) else {
            
            if MockingBird.handleAllRequests {
                // We're handling all requests, but no bundle item found
                // so reply with server error 501 and no data
                var headers = [String: String]()
                headers["Content-Type"] = "text/plain"
                
                let errorMsg = "Mockingbird response not available.  Please add a response to the bundle at \(MockingBird.currentMockBundlePath)."
                let data = errorMsg.dataUsingEncoding(NSUTF8StringEncoding)
                if let data = data {
                    headers["Content-Length"] = "\(data.length)"
                }
                let response = NSHTTPURLResponse(URL: self.request.URL!,
                                                 statusCode: 501,
                                                 HTTPVersion: "HTTP/1.1",
                                                 headerFields: headers)!
                
                // send response
                self.client!.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
                
                // send response data if available
                if let data = data {
                    self.client!.URLProtocol(self, didLoadData: data)
                }
                
                // finish up
                self.client!.URLProtocolDidFinishLoading(self)

            } else {
                self.client!.URLProtocol(self, didFailWithError: NSError.init(domain: "mockingbird", code: 1000, userInfo:nil))
            }
            return
        }
        
        // set mime type
        var mime: String? = nil
        if let m = entry.responseMime {
            mime = m
        }
        
        // load data
        var data: NSData? = nil
        if let f = entry.responseFile {
            do {
                data = try NSData(contentsOfFile: "\(MockingBird.currentMockBundlePath!)/\(f)", options: .DataReadingMappedIfSafe)
            } catch {
                data = nil
            }
        }
        
        // construct response
        var headers = entry.responseHeaders
        headers["Content-Type"] = mime
        if let data = data {
            headers["Content-Length"] = "\(data.length)"
        }
        let response = NSHTTPURLResponse(URL: self.request.URL!, statusCode: entry.responseCode, HTTPVersion: "HTTP/1.1", headerFields: headers)!
        
        // send response
        self.client!.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
        
        // send response data if available
        if let data = data {
            self.client!.URLProtocol(self, didLoadData: data)
        }
        
        // finish up
        self.client!.URLProtocolDidFinishLoading(self)
    }
    
    public override func stopLoading() {
        // do nothing
    }
    
    private class func getBundleItem(inUrl: NSURL, method: String) -> MockBundleEntry? {
        let url = NSURLComponents(URL: inUrl, resolvingAgainstBaseURL: false)!
        
        // find entry that matches
        for entry in MockingBird.currentMockBundle! {
            // url match and request method match
            var urlPart = "://\(url.host!)\(url.path!)"
            if let port = url.port {
                urlPart = "://\(url.host!):\(port)\(url.path!)"
            }
            
            if entry.url == urlPart && entry.requestMethod == method {
                
                // components
                var valid = true
                if let queryItems = url.queryItems {
                    for component in queryItems {
                        var found = false
                        for q in entry.queryParameters {
                            if component.name == q.0 && q.1 == nil {
                                found = true
                                break
                            } else if component.name == q.0 && component.value == q.1 {
                                found = true
                                break
                            }
                        }
                        if !found {
                            valid = false
                            break
                        }
                    }
                } else {
                    // no components
                    if entry.queryParameters.count != 0 {
                        valid = false
                    }
                }
                
                if valid {
                    return entry
                }
            }
        }
        
        return nil
    }
}
