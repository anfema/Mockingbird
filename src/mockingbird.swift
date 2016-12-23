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
        guard case .jsonDictionary(let dict) = json, (dict["request"] != nil && dict["response"] != nil),
              case .jsonDictionary(let request) = dict["request"]!, request["url"] != nil,
              case .jsonDictionary(let response) = dict["response"]!, response["code"] != nil,
              case .jsonString(let url) = request["url"]!,
              case .jsonNumber(let code) = response["code"]!
            else {
            throw MockingBird.MBError.invalidBundleDescriptionFile
        }
        
        self.url = url
        self.responseCode = Int(code)

        if let q = request["parameters"],
           case .jsonDictionary(let query) = q {
                for item in query {
                    if case .jsonString(let value) = item.1 {
                        self.queryParameters[item.0] = value
                    } else if case .jsonNull = item.1 {
                        self.queryParameters[item.0] = nil as String?
                    } else {
                        print("Query parameter \(item.0) has invalid value!")
                    }
                }
        }
        
        if let q = request["method"],
            case .jsonString(let method) = q {
                self.requestMethod = method
        }

        if let q = response["headers"],
            case .jsonDictionary(let headers) = q {
                for item in headers {
                    if case .jsonString(let value) = item.1 {
                        self.responseHeaders[item.0] = value
                    }
                }
        }

        if let q = response["file"],
            case .jsonString(let file) = q {
                self.responseFile = file
        }
        
        if let q = response["mime_type"],
            case .jsonString(let mime) = q {
                self.responseMime = mime
        }
    }
}

open class MockingBird: URLProtocol {
    static var currentMockBundle: [MockBundleEntry]?
    static var currentMockBundlePath: String?
    
    // If this is true, we'll claim to answer all URL requests.
    // If this is false, URLs that don't match will be passed on
    //      through to normal handlers.
    open static var handleAllRequests: Bool = false

    public enum MBError: Error {
        case mockBundleNotFound
        case invalidMockBundle
        case invalidBundleDescriptionFile
    }
    
    /// Register MockingBird with a NSURLSession
    ///
    /// - parameter session: the session to mock
    open class func register(inSession session: URLSession) {
        self.register(inConfig: session.configuration)
    }

    /// Register MockingBird in a NSURLSessionConfiguration
    ///
    /// - parameter config: session configuration to mock
    open class func register(inConfig config: URLSessionConfiguration) {
        var protocolClasses = config.protocolClasses
        if protocolClasses == nil {
            protocolClasses = [AnyClass]()
        }
        protocolClasses!.insert(MockingBird.self, at: 0)
        config.protocolClasses = protocolClasses
    }

    /// Set mock bundle to use
    ///
    /// - parameter bundlePath: path to the bundle
    /// - throws: MockingBird.Error when bundle could not be loaded
    open class func setMockBundle(withPath bundlePath: String?) throws {
        guard let bundlePath = bundlePath else {
            self.currentMockBundle = nil
            self.currentMockBundlePath = nil
            return
        }
        
        do {
            var isDir = ObjCBool(false)
            if FileManager.default.fileExists(atPath: bundlePath, isDirectory: &isDir) && isDir.boolValue {
                let jsonString = try String(contentsOfFile: "\(bundlePath)/bundle.json")

                let jsonObject = JSONDecoder(jsonString).jsonObject
                if case .jsonArray(let array) = jsonObject {
                    self.currentMockBundle = try array.map { item -> MockBundleEntry in
                        return try MockBundleEntry(json: item)
                    }
                } else {
                    throw MockingBird.MBError.invalidBundleDescriptionFile
                }
            } else {
                throw MockingBird.MBError.mockBundleNotFound
            }
        } catch MockingBird.MBError.invalidBundleDescriptionFile {
            throw MockingBird.MBError.invalidBundleDescriptionFile
        } catch {
            throw MockingBird.MBError.invalidMockBundle
        }
        self.currentMockBundlePath = bundlePath
    }
}

// MARK: - URL Protocol overrides
extension MockingBird {
    open override class func canInit(with request: URLRequest) -> Bool {
        // we can only answer if we have a mockBundle
        if self.currentMockBundle == nil {
            return false
        }
        
        // we can answer all http and https requests
        if let _ = self.getBundleItem(inURL: request.url!, method: request.httpMethod!) {
            return true
        }
        return self.handleAllRequests
    }

    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // canonical request is same as request
        return request
    }

    open override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        // nothing is cacheable
        return false
    }
    
    open override func startLoading() {
        // fetch item
        guard let entry = MockingBird.getBundleItem(inURL: self.request.url!, method: self.request.httpMethod!) else {
            
            if MockingBird.handleAllRequests {
                // We're handling all requests, but no bundle item found
                // so reply with server error 501 and no data
                var headers = [String: String]()
                headers["Content-Type"] = "text/plain"
                
                let errorMsg = "Mockingbird response not available.  Please add a response to the bundle at \(MockingBird.currentMockBundlePath)."
                let data = errorMsg.data(using: String.Encoding.utf8)
                if let data = data {
                    headers["Content-Length"] = "\(data.count)"
                }
                let response = HTTPURLResponse(url: self.request.url!,
                                                 statusCode: 501,
                                                 httpVersion: "HTTP/1.1",
                                                 headerFields: headers)!
                
                // send response
                self.client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                
                // send response data if available
                if let data = data {
                    self.client!.urlProtocol(self, didLoad: data)
                }
                
                // finish up
                self.client!.urlProtocolDidFinishLoading(self)

            } else {
                self.client!.urlProtocol(self, didFailWithError: NSError.init(domain: "mockingbird", code: 1000, userInfo:nil))
            }
            return
        }
        
        // set mime type
        var mime: String? = nil
        if let m = entry.responseMime {
            mime = m
        }
        
        // load data
        var data: Data? = nil
        if let f = entry.responseFile {
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: "\(MockingBird.currentMockBundlePath!)/\(f)"), options: .mappedIfSafe)
            } catch {
                data = nil
            }
        }
        
        // construct response
        var headers = entry.responseHeaders
        headers["Content-Type"] = mime
        if let data = data {
            headers["Content-Length"] = "\(data.count)"
        }
        let response = HTTPURLResponse(url: self.request.url!, statusCode: entry.responseCode, httpVersion: "HTTP/1.1", headerFields: headers)!
        
        // send response
        self.client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        
        // send response data if available
        if let data = data {
            self.client!.urlProtocol(self, didLoad: data)
        }
        
        // finish up
        self.client!.urlProtocolDidFinishLoading(self)
    }
    
    open override func stopLoading() {
        // do nothing
    }
    
    fileprivate class func getBundleItem(inURL inUrl: URL, method: String) -> MockBundleEntry? {
        let url = URLComponents(url: inUrl, resolvingAgainstBaseURL: false)!
        
        // find entry that matches
        for entry in MockingBird.currentMockBundle! {
            // url match and request method match
            var urlPart = "://\(url.host!)\(url.path)"
            if let port = url.port {
                urlPart = "://\(url.host!):\(port)\(url.path)"
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
