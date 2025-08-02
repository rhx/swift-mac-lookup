import Foundation

/// A URLProtocol subclass that intercepts network requests for testing purposes.
final class MockURLProtocol: URLProtocol {
    private static let queue = DispatchQueue(
        label: "com.maclookup.test.protocol", attributes: .concurrent)
    nonisolated(unsafe) private static var _requestHandler:
        (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Thread-safe access to the request handler
    static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
        get {
            return queue.sync {
                _requestHandler
            }
        }
        set {
            queue.async(flags: .barrier) {
                _requestHandler = newValue
            }
        }
    }

    /// Whether the protocol can handle the given request.
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    /// Returns a canonical version of the request.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    /// Starts loading the request.
    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(
                self, didFailWithError: NSError(domain: "MockURLProtocol", code: -1))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    /// Stops loading the request.
    override func stopLoading() {}

    /// Resets the request handler.
    static func reset() {
        requestHandler = nil
    }

    /// Creates a URLSession with this protocol as its URL protocol class.
    /// - Returns: A configured URLSession instance.
    static func createMockURLSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
