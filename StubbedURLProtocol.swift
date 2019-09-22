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
    
    fileprivate static var gofer: URLProtocolGofer = URLProtocolGofer()
    
    class func run() -> Bool
    {
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
        guard let data = StubbedURLProtocol.gofer.fetchResponseData(
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
            if (self.gofer.shouldRegisterRequestDataProvider())
            {
                let requestDataProvider = RequestDataProvider()
                StubbedURLProtocol.gofer.registerRequestDataProvider(
                    requestDataProvider
                )
            }
            
            if (self.gofer.shouldRegisterResponseDataProvider())
            {
                let responseDataProvider = ResponseDataProvider()
                StubbedURLProtocol.gofer.registerResponseDataProvider(
                    responseDataProvider
                )
            }
            
            // TODO:  Will be getting tagged to the same request
            let requestResourcePath =
                Bundle.main.path(
                    forResource: "",
                    ofType: "json",
                    inDirectory: "Requests"
            ) ?? ""

            self.gofer.registerResource(
                at: requestResourcePath,
                for: request,
                with: DataProviderType.RequestProvider
            )
            
            let responseResourcePath =
                Bundle.main.path(
                    forResource: "",
                    ofType: "json",
                    inDirectory: "Requests"
            ) ?? ""
            
           self.gofer.registerResource(
                at: responseResourcePath,
                for: request,
                with: DataProviderType.ResponseProvider
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
    
    func shouldRegisterRequestDataProvider() -> Bool
    {
        return self.requestDataProvider != nil ? true : false
    }
    
    func registerRequestDataProvider(_ requestDataProvider: DataProvider)
    {
        self.requestDataProvider = requestDataProvider
    }
    
    func shouldRegisterResponseDataProvider() -> Bool
    {
        return self.responseDataProvider != nil ? true : false
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
    
    func registerResource(
        at path: String,
        for request: URLRequest,
        with provider:DataProviderType
    )
    {
        switch provider {
        case .RequestProvider:
            self.requestDataProvider?.registerResource(
                at: path,
                for: request
            )
        case .ResponseProvider:
            self.responseDataProvider?.registerResource(
                at: path,
                for: request
            )
        }
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
