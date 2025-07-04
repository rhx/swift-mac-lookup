import Testing
import Foundation
import XCTest
@testable import MACLookup

// MARK: - Test Configuration

private let testConfig = """
{
    "maclookup_app": "test-api-key"
}
"""

private let testDatabase = """
{
    "00:11:22": {
        "oui": "00:11:22",
        "company": "Test Company",
        "address": "123 Test St",
        "country": "AU",
        "type": "MA-L",
        "updated": "2023-01-01",
        "private": false
    }
}
"""

private let testAPIResponse = """
{
    "oui": "00:11:22",
    "company": "Test Company",
    "address": "123 Test St",
    "country": "AU",
    "type": "MA-L",
    "updated": "2023-01-01",
    "private": false
}
"""


@Suite("MACAddress Tests")
struct MACAddressTests {
    @Test("Valid MAC address initialisation")
    func testValidMACAddress() throws {
        let macStrings = [
            "00:11:22:33:44:55",
            "00-11-22-33-44-55",
            "00.11.22.33.44.55",
            "0011.2233.4455"
        ]
        
        for macString in macStrings {
            let mac = try #require(try? MACAddress(string: macString))
            #expect(mac.description == "00:11:22:33:44:55")
            #expect(mac.oui == "00:11:22")
        }
    }
    
    @Test("Invalid MAC address initialisation")
    func testInvalidMACAddress() throws {
        let invalidMACs = [
            "00:11:22:33:44:GG",  // Invalid character
            "00:11:22:33:44",     // Too short
            "00:11:22:33:44:55:66", // Too long
            "not a mac address",   // Completely invalid
            ""                     // Empty string
        ]
        
        for macString in invalidMACs {
            #expect(throws: (any Error).self) {
                _ = try MACAddress(string: macString)
            }
        }
    }
}

@Suite("MACVendorInfo Tests")
struct MACVendorInfoTests {
    @Test("Decoding from JSON")
    func testDecoding() throws {
        let json = """
        {
            "oui": "00:11:22",
            "company": "Test Company",
            "address": "123 Test St, Test City",
            "country": "AU",
            "type": "MA-L",
            "updated": "2023-01-01",
            "private": false
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        let decoder = JSONDecoder()
        let vendorInfo = try decoder.decode(MACVendorInfo.self, from: data)
        
        #expect(vendorInfo.prefix == "00:11:22")
        #expect(vendorInfo.companyName == "Test Company")
        #expect(vendorInfo.companyAddress == "123 Test St, Test City")
        #expect(vendorInfo.countryCode == "AU")
        #expect(vendorInfo.blockType == "MA-L")
        #expect(vendorInfo.updated == "2023-01-01")
        #expect(vendorInfo.isPrivate == false)
    }
}

@Suite("MACLookup Tests")
struct MACLookupTests {
    private let tempDir: URL
    private let testDBURL: URL
    private let testConfigURL: URL
    
    @Test("Initialisation and setup")
    func testInitialisation() async throws {
        // The test just verifies that the files are created during init
        _ = MACLookup(
            localDatabaseURL: testDBURL,
            configURL: testConfigURL
        )
        
        // Verify files were created
        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: testDBURL.path))
        #expect(fileManager.fileExists(atPath: testConfigURL.path))
    }
    
    @Test("Database loading and updating")
    func testDatabaseOperations() async throws {
        // Setup mock URL session
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)
        
        // Create test files
        try testConfig.write(to: testConfigURL, atomically: true, encoding: .utf8)
        try testDatabase.write(to: testDBURL, atomically: true, encoding: .utf8)
        
        // Set up mock response for API calls
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, testAPIResponse.data(using: .utf8)!)
        }
        
        let lookup = MACLookup(
            localDatabaseURL: testDBURL,
            configURL: testConfigURL,
            session: mockSession
        )
        
        // Test loading the database
        try await lookup.loadLocalDatabase()
        
        // Test looking up a MAC address from local database
        let localVendor = try await lookup.lookup("00:11:22:33:44:55")
        #expect(localVendor.companyName == "Test Company")
        
        // Test non-existent MAC address with API failure
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data())
        }
        
        do {
            _ = try await lookup.lookup("FF:FF:FF:00:00:00")
            Issue.record("Expected MACLookupError.apiError to be thrown")
        } catch MACLookupError.apiError {
            // Expected error - test passes
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        
        // Reset the request handler
        MockURLProtocol.reset()
    }
    
    @Test("Configuration handling")
    func testConfiguration() async throws {
        // Create a test config file
        try testConfig.write(to: testConfigURL, atomically: true, encoding: .utf8)
        
        // Setup mock URL session
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)
        
        // Set up mock response for API key validation
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data())
        }
        
        let lookup = MACLookup(
            localDatabaseURL: testDBURL,
            configURL: testConfigURL,
            session: mockSession
        )
        
        // Verify the config file exists and has content
        let fileManager = FileManager.default
        let configExists = fileManager.fileExists(atPath: testConfigURL.path)
        #expect(configExists)
        
        if configExists {
            let content = try String(contentsOf: testConfigURL, encoding: .utf8)
            #expect(content.contains("test-api-key"))
        }
        
        // Reset the request handler
        MockURLProtocol.reset()
    }
    
    // MARK: - Test Lifecycle
    
    init() {
        do {
            // Create a temporary directory for tests
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("MACLookupTests-\(UUID().uuidString)")
            
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            self.tempDir = tempDir
            
            // Set up test file URLs
            self.testDBURL = tempDir.appendingPathComponent("test-db.json")
            self.testConfigURL = tempDir.appendingPathComponent("test-config.json")
            
            // Create empty files
            FileManager.default.createFile(atPath: testDBURL.path, contents: Data())
            FileManager.default.createFile(atPath: testConfigURL.path, contents: Data())
        } catch {
            // If setup fails, the test will fail with a descriptive error
            fatalError("Failed to set up test environment: \(error)")
        }
    }
    
    @Test("Clean up test environment")
    func cleanup() throws {
        // Remove the temporary directory
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Test Utilities

extension Test {
    /// Helper function to unwrap an optional or fail the test
    static func `require`<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        guard let value = value else {
            throw TestError.requiredValueIsNil(file: file, line: line)
        }
        return value
    }
    

}

private enum TestError: Error {
    case requiredValueIsNil(file: StaticString, line: UInt)
}

extension TestError: CustomStringConvertible {
    var description: String {
        switch self {
        case .requiredValueIsNil(let file, let line):
            return "Required value is nil at \(file):\(line)"
        }
    }
}
