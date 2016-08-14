//
//  mockingbirdTests.swift
//  mockingbirdTests
//
//  Created by Johannes Schriewer on 02/12/15.
//  Copyright © 2015 anfema. All rights reserved.
//

import XCTest
@testable import mockingbird
import Alamofire
import DEjson

class mockingbirdTests: XCTestCase {
    var alamofire: Alamofire.Manager! = nil
    
    override func setUp() {
        super.setUp()
        
        let configuration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.requestCachePolicy = .ReloadIgnoringLocalCacheData
        configuration.HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders
        configuration.HTTPCookieAcceptPolicy = .Never
        configuration.HTTPShouldSetCookies = false
        
        MockingBird.registerInConfig(configuration)
        self.alamofire = Alamofire.Manager(configuration: configuration)

        let bundle = NSBundle(forClass: self.dynamicType).resourcePath! + "/bundles/httpbin"
        do {
            try MockingBird.setMockBundle(bundle)
        } catch {
            XCTFail("Could not reset mock bundle")
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testReal() {
        let expectation = self.expectationWithDescription("testReal")
        
        do {
            try MockingBird.setMockBundle(nil)
        } catch {
            XCTFail("Could not disable mock bundle")
        }

        self.alamofire.request(.GET, "http://httpbin.org/ip").response { (request, response, data, error) in
            if let data = data {
                let jsonString = String(data: data, encoding: NSUTF8StringEncoding)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .JSONDictionary(let dict) = json where dict["origin"] != nil,
                      case .JSONString(let ip) = dict["origin"]! else {
                        XCTFail("Invalid data returned")
                        expectation.fulfill()
                        return
                }
                
                XCTAssert(ip != "127.0.0.1")
                expectation.fulfill()
            } else {
                XCTFail("No data returned")
                expectation.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testHandleAll() {
        let expectation = self.expectationWithDescription("testHandleAll")

        MockingBird.handleAllRequests = true
        
        self.alamofire.request(.GET, "http://httpbin.org/html").response { (request, response, data, error) in
            XCTAssertTrue(response!.statusCode == 501)
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2.0, handler: nil)
    }

    func testMock() {
        let expectation = self.expectationWithDescription("testMock")
        
        self.alamofire.request(.GET, "http://httpbin.org/ip").response { (request, response, data, error) in
            if let data = data {
                let jsonString = String(data: data, encoding: NSUTF8StringEncoding)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .JSONDictionary(let dict) = json where dict["origin"] != nil,
                    case .JSONString(let ip) = dict["origin"]! else {
                        XCTFail("Invalid data returned")
                        expectation.fulfill()
                        return
                }
                
                XCTAssert(ip == "127.0.0.1")
                expectation.fulfill()
            } else {
                XCTFail("No data returned")
                expectation.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(2.0, handler: nil)
    }

    
    func testArguments() {
        let expectation = self.expectationWithDescription("testArguments")
        
        self.alamofire.request(.GET, "http://httpbin.org/get", parameters:["arg1": "test", "arg2": "test"]).response { (request, response, data, error) in
            if let data = data {
                let jsonString = String(data: data, encoding: NSUTF8StringEncoding)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .JSONDictionary(let dict) = json where (dict["origin"] != nil && dict["args"] != nil),
                      case .JSONString(let ip) = dict["origin"]!,
                      case .JSONDictionary(let args) = dict["args"]! else {
                        XCTFail("Invalid data returned")
                        expectation.fulfill()
                        return
                }
                
                XCTAssert(ip == "127.0.0.1")
                XCTAssertNotNil(args["arg1"])
                XCTAssertNotNil(args["arg2"])
                
                expectation.fulfill()
            } else {
                XCTFail("No data returned")
                expectation.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testOtherArgument() {
        let expectation = self.expectationWithDescription("testArguments")
        
        self.alamofire.request(.GET, "http://httpbin.org/get", parameters:["arg1": "foobar"]).response { (request, response, data, error) in
            if let data = data {
                let jsonString = String(data: data, encoding: NSUTF8StringEncoding)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .JSONDictionary(let dict) = json where (dict["origin"] != nil && dict["args"] != nil),
                    case .JSONString(let ip) = dict["origin"]!,
                    case .JSONDictionary(let args) = dict["args"]! else {
                        XCTFail("Invalid data returned")
                        expectation.fulfill()
                        return
                }
                
                XCTAssert(ip == "127.0.0.1")
                XCTAssertNotNil(args["arg1"])
                XCTAssertNil(args["arg2"])
                
                expectation.fulfill()
            } else {
                XCTFail("No data returned")
                expectation.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testNonMatchingArgument() {
        let expectation = self.expectationWithDescription("testArguments")
        
        self.alamofire.request(.GET, "http://httpbin.org/get", parameters:["other": "foobar"]).response { (request, response, data, error) in
            if let data = data {
                let jsonString = String(data: data, encoding: NSUTF8StringEncoding)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .JSONDictionary(let dict) = json where (dict["origin"] != nil && dict["args"] != nil),
                    case .JSONString(let ip) = dict["origin"]!,
                    case .JSONDictionary(let args) = dict["args"]! else {
                        XCTFail("Invalid data returned: \(jsonString)")
                        expectation.fulfill()
                        return
                }
                
                XCTAssert(ip != "127.0.0.1")
                XCTAssertNotNil(args["other"])
                XCTAssertNil(args["arg1"])
                XCTAssertNil(args["arg2"])
                
                expectation.fulfill()
            } else {
                XCTFail("No data returned")
                expectation.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(2.0, handler: nil)
    }

}
