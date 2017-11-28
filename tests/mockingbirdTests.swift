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
    var alamofire: Alamofire.SessionManager! = nil
    
    override func setUp() {
        super.setUp()
        
        let configuration: URLSessionConfiguration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        
        MockingBird.register(inConfig: configuration)
        self.alamofire = Alamofire.SessionManager(configuration: configuration)
        
        let bundle = Bundle(for: type(of: self)).resourcePath! + "/bundles/httpbin"
        do {
            try MockingBird.setMockBundle(withPath: bundle)
        } catch {
            XCTFail("Could not reset mock bundle")
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testReal() {
        let expectation = self.expectation(description: "testReal")
        
        do {
            try MockingBird.setMockBundle(withPath: nil)
        } catch {
            XCTFail("Could not disable mock bundle")
        }

        self.alamofire.request("http://httpbin.org/ip", method: .get).response { (response) in
            if let data = response.data {
                let jsonString = String(data: data, encoding: String.Encoding.utf8)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .jsonDictionary(let dict) = json, dict["origin"] != nil,
                    case .jsonString(let ip) = dict["origin"]! else {
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
        
        self.waitForExpectations(timeout: 2.0, handler: nil)
    }
    
    func testHandleAll() {
        let expectation = self.expectation(description: "testHandleAll")

        MockingBird.handleAllRequests = true
        
        self.alamofire.request("http://httpbin.org/html", method: .get).response { (response) in
            XCTAssertTrue(response.response!.statusCode == 501)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testMock() {
        let expectation = self.expectation(description: "testMock")
        
        self.alamofire.request("http://httpbin.org/ip", method: .get).response { (response) in
            if let data = response.data {
                let jsonString = String(data: data, encoding: String.Encoding.utf8)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .jsonDictionary(let dict) = json, dict["origin"] != nil,
                    case .jsonString(let ip) = dict["origin"]! else {
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
        
        self.waitForExpectations(timeout: 2.0, handler: nil)
    }

    
    func testArguments() {
        let expectation = self.expectation(description: "testArguments")
        
        self.alamofire.request("http://httpbin.org/get", method: .get, parameters: ["arg1": "test", "arg2": "test"]).response { (response) in
            if let data = response.data {
                let jsonString = String(data: data, encoding: String.Encoding.utf8)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .jsonDictionary(let dict) = json, (dict["origin"] != nil && dict["args"] != nil),
                    case .jsonString(let ip) = dict["origin"]!,
                    case .jsonDictionary(let args) = dict["args"]! else {
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
        
        self.waitForExpectations(timeout: 2.0, handler: nil)
    }
    
    func testOtherArgument() {
        let expectation = self.expectation(description: "testArguments")
        
        self.alamofire.request("http://httpbin.org/get", method: .get, parameters: ["arg1": "foobar"]).response { (response) in
            if let data = response.data {
                let jsonString = String(data: data, encoding: String.Encoding.utf8)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .jsonDictionary(let dict) = json, (dict["origin"] != nil && dict["args"] != nil),
                    case .jsonString(let ip) = dict["origin"]!,
                    case .jsonDictionary(let args) = dict["args"]! else {
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
        
        self.waitForExpectations(timeout: 2.0, handler: nil)
    }
    
    func testNonMatchingArgument() {
        let expectation = self.expectation(description: "testArguments")
        
        self.alamofire.request("http://httpbin.org/get", method: .get, parameters: ["other": "foobar"]).response { (response) in
            if let data = response.data {
                let jsonString = String(data: data, encoding: String.Encoding.utf8)
                XCTAssertNotNil(jsonString)
                let json = JSONDecoder(jsonString!).jsonObject
                guard case .jsonDictionary(let dict) = json, (dict["origin"] != nil && dict["args"] != nil),
                    case .jsonString(let ip) = dict["origin"]!,
                    case .jsonDictionary(let args) = dict["args"]! else {
                        XCTFail("Invalid data returned: \(String(describing: jsonString))")
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
        
        self.waitForExpectations(timeout: 2.0, handler: nil)
    }

}
