//
//  StubbedURLProtocol.swift
//  MockAPIWIthURLProtocol
//
//  Created by carvak on 18/09/2019.
//  Copyright © 2019 0. All rights reserved.
//

import UIKit

enum DataProviderType: String
{
    case RequestProvider
    case ResponseProvider
}

enum MIMEtype: String
{
    case json = "application/json"
    case xml = "application/xml"
    case plaintext = "text/plain"
    case html = "text/html"
}

protocol StubDataProvider: DataProvider {
    var headers: [String:String] {get set}
    var resourceMap: [URL: [String:String]] { get }
    func registerResource(at path: String ,for URL: String)
}

protocol StubRequestProvider: StubDataProvider {
    
}

protocol StubResponseProvider: StubDataProvider {
    
}

protocol DataProvider {
    var resourceMap: [ URL : Data ] {get}
    func getContent(for resource: URL) -> Data
    func setContent(_ content: Data, for resource: URL)
    func contentSize(for url: URL) -> Int
    func registerResource(at path: String ,for request: URLRequest)
}

class StubbedURLProtocol: URLProtocol  {
    
    fileprivate static var gofer: URLProtocolGofer?
    
    class func run() -> Bool
    {
        self.gofer = URLProtocolGofer()
        return URLProtocol .registerClass(self)
    }
    
    class func stop()
    {
        URLProtocol.unregisterClass(self)
    }
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }
    
    convenience init(task: URLSessionTask, cachedResponse: CachedURLResponse?, client: URLProtocolClient?)
    {
        self.init(request: task.currentRequest!, cachedResponse: cachedResponse, client: client)
    }
    
    open override class func canInit(with request: URLRequest) -> Bool
    {
        // check if request
        return self.shouldInit(with:request)
    }
    
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest
    {
        return request;
    }
    
    override func startLoading() {
        
        /// get data
        guard let data = StubbedURLProtocol.gofer?.fetchResponseData(
            for: self.request.url!
            ) else {
                
                // for error
                self.client?.urlProtocol(
                    self,
                    didFailWithError: NSError.init(
                        domain: "com.mockurlprotocol.eroor.domian",
                        code: 99999,
                        userInfo: [:]
                    )
                )
                
                return
                
        }
        
        /// make success Response
        guard let response = self.makeSuccessResponse() else { return  }
        
        /// send success response
        self.client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: URLCache.StoragePolicy.notAllowed
        )
        
        /// send data
        self.client?.urlProtocol(self, didLoad: data)
        
        /// send finish loading
        self.client?.urlProtocolDidFinishLoading(self);
        
        
        
    }
    
    override func stopLoading() {
        
    }
}

/// More methods to configure the Protocol
private extension StubbedURLProtocol
{
    class func shouldInit(with request: URLRequest) -> Bool
    {
        func prepareGofer(forRequest request: URLRequest)
        {
            let requestDataProvider = RequestDataProvider()
            let requestResourcePaths =
                Bundle.main.paths(
                    forResourcesOfType: "json",
                    inDirectory: "Requests"
            )
            requestResourcePaths.forEach { (path) in
                requestDataProvider.registerResource(
                    at: Bundle.main.path(
                        forResource: "",
                        ofType: ".json"
                        ) ?? "",
                    for: request
                )
            }
            
            let responseDataProvider = ResponseDataProvider()
            let responseResourcePaths =
                Bundle.main.paths(
                    forResourcesOfType: "json",
                    inDirectory: "Responses"
            )
            responseResourcePaths.forEach { (path) in
                responseDataProvider.registerResource(
                    at: Bundle.main.path(
                        forResource: "",
                        ofType: ".json"
                        ) ?? "",
                    for: request
                )
            }
            
            StubbedURLProtocol.gofer?.registerRequestDataProvider(
                requestDataProvider
            )
            StubbedURLProtocol.gofer?.registerResponseDataProvider(
                responseDataProvider
            )
        }
        
        prepareGofer(forRequest: request)
        
        return true
    }
    
    func makeSuccessResponse() -> URLResponse?
    {
        return HTTPURLResponse.init(
            url: self.request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields:
            [:]
        )
    }
    
    func makeErrorResponse() -> URLResponse?
    {
        return HTTPURLResponse.init(
            url: self.request.url!,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields:
            [:]
        )
    }
}


private final class URLProtocolGofer
{
    private(set) var requestDataProvider: DataProvider?
    private(set) var responseDataProvider: DataProvider?
    
    func registerRequestDataProvider(_ requestDataProvider: DataProvider)
    {
        self.requestDataProvider = requestDataProvider
    }
    
    func registerResponseDataProvider(_ responseDataProvider: DataProvider)
    {
        self.responseDataProvider = responseDataProvider
    }
    
    func fetchResponseData(for url:URL)-> Data?
    {
        return self.responseDataProvider?.getContent(for: url)
    }
    
    func fetchRequesteData(for url:URL)-> Data?
    {
        return self.requestDataProvider?.getContent(for: url)
    }
    
}

typealias DataProviderImplementation = DataProvider
extension DataProviderImplementation {
    
    func getContent(for resource: URL) -> Data
    {
        return self.resourceMap[resource] ?? Data()
    }
    
    func contentSize(for url: URL) -> Int {
        return (self.resourceMap[url] ?? Data()).count
    }
    
    func registerResource(at path: String, for request: URLRequest) {
        
        guard let resourcePathURL: URL = URL(string: path),
            let requestURL = request.url,
            let resourceContents = try? Data.init(contentsOf: resourcePathURL)
            else { return }
        
        self.setContent(resourceContents, for: requestURL)
    }
    
}

final class RequestDataProvider: DataProvider
{
    private(set) var resourceMap: [ URL : Data ] = [:]
    
    func setContent(_ content: Data, for resource: URL)
    {
        self.resourceMap[resource] = content
    }
    
}

final class ResponseDataProvider: DataProvider
{
    private(set) var resourceMap: [ URL : Data ] = [:]
    
    func setContent(_ content: Data, for resource: URL)
    {
        
    }
}
