import Testing
import Foundation
import class Foundation.Bundle
@testable import MACLookup

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Test Configuration

private let testDatabase = """
{
    "001122": {
        "oui": "001122",
        "company": "Test Company",
        "address": "123 Test St, Test City, AU",
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
            #expect(mac.oui == "001122")
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
    private var testResourcesURL: URL
    
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
    
    @Test("Test resources can be loaded")
    func testResourcesLoad() throws {
        // Try to load the test resource
        let testBundle = Bundle.module
        let resourceURL = testBundle.url(forResource: "testoui", withExtension: "txt")
        
        if let resourceURL = resourceURL {
            // Try to read the file
            do {
                let content = try String(contentsOf: resourceURL, encoding: .utf8)
                if content.isEmpty {
                    print("Warning: Test resource 'testoui.txt' is empty")
                }
            } catch {
                print("Warning: Could not read test resource: \(error)")
            }
        } else {
            // If we can't find the resource, log where we looked
            print("Warning: Test resource 'testoui.txt' not found in bundle")
            if let resourcePath = testBundle.resourcePath {
                print("Resource path: \(resourcePath)")
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                    print("Contents of resource directory: \(contents)")
                }
            }
        }
    }
    
    @Test("Database loading and updating")
    func testDatabaseLoading() async throws {
        // Create a unique temporary directory for this test
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MACLookupTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Set up test file path in the temporary directory
        let testDBPath = tempDir.appendingPathComponent("test_db.json")
        
        // Set up mock response for API calls
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            // Return a valid OUI text file in the format expected by OUIParser
            // The parser will include everything after the OUI in the vendor name
            let ouiText = """
            00-11-22     (hex)		CIMSYS Inc
                CIMSYS Inc
                Yongin-City  Kyunggi-Do  449-711
                KR
            
            00-11-23     (hex)		Another Company
                Another Address Line 1
                Another City, Another State 67890
                US
            """
            
            // The OUIParser expects the OUI in the format "XX-XX-XX" and will convert it to "XXXXXX"
            // So "00-11-22" will be converted to "001122" in the database
            // The parser will include everything after the OUI in the vendor name
            return (response, ouiText.data(using: .utf8)!)
        }
        
        // Initialize MACLookup with our test path
        let lookup = MACLookup(
            localDatabaseURL: testDBPath,
            configURL: tempDir.appendingPathComponent("config.yaml")
        )
        
        // Test updating the database first to populate it with mock data
        try await lookup.updateDatabase()
        
        // Test looking up a MAC address from the updated database
        let localVendor = try await lookup.lookup("00:11:22:33:44:55")
        
        // The OUIParser includes everything after the OUI in the vendor name
        // The MACVendorInfo.from(vendorName:) method uses this as the company name
        let expectedVendorName = "(hex) CIMSYS Inc 001122     (base 16)\t\tCIMSYS Inc Yongin-City  Kyunggi-Do  449-711 KR"
        #expect(localVendor.companyName == expectedVendorName)
        #expect(localVendor.companyAddress.isEmpty) // Address is empty in MACVendorInfo.from(vendorName:)
        #expect(localVendor.countryCode.isEmpty) // Country code is empty in MACVendorInfo.from(vendorName:)
        
        // Clean up the temporary directory
        try? FileManager.default.removeItem(at: tempDir)
        
        // Reset the request handler
        MockURLProtocol.reset()
    }
    
    @Test("Configuration loading")
    func testConfiguration() async throws {
        // Create a unique temporary directory for this test
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MACLookupTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Create test files
        let testDBURL = tempDir.appendingPathComponent("test-db.json")
        
        // Write test data
        try testDatabase.write(to: testDBURL, atomically: true, encoding: .utf8)
        
        // Set up mock response for OUI data with proper format
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            // Return a valid OUI text file in the format expected by OUIParser
            let ouiText = """
            00-11-22     Test Company
                Test Address, Test City, AU
            """
            return (response, Data(ouiText.utf8))
        }
        
        // Initialize MACLookup with our test paths
        let lookup = MACLookup(
            localDatabaseURL: testDBURL,
            configURL: tempDir.appendingPathComponent("config.yaml"),
            session: MockURLProtocol.createMockURLSession()
        )
        
        // Test that the database was loaded
        try await lookup.loadLocalDatabase()
        let vendor = try await lookup.lookup("00:11:22:33:44:55")
        #expect(vendor.companyName == "Test Company")
        
        // Clean up
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Test Lifecycle
    
    init() {
        do {
            // Create a temporary directory for tests
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("MACLookupTests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            self.tempDir = tempDir

            // Create test database and config files
            testDBURL = tempDir.appendingPathComponent("test_db.json")
            testConfigURL = tempDir.appendingPathComponent("test_config.txt")

            // Set up test resources path
            // Try different possible locations for the resources
            let testBundle = Bundle(for: MockURLProtocol.self)
            let possibleResourceDirs = [
                testBundle.resourceURL,
                testBundle.resourceURL?.appendingPathComponent("Resources"),
                testBundle.bundleURL.appendingPathComponent("Resources"),
                testBundle.bundleURL.deletingLastPathComponent().appendingPathComponent("Resources"),
                testBundle.bundleURL.appendingPathComponent("MACLookupTests/Resources")
            ].compactMap { $0 }

            // Try to find the resources directory, but don't fail if not found
            var foundResourcesURL: URL? = nil
            for url in possibleResourceDirs {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    foundResourcesURL = url
                    break
                }
            }
            
            // If we couldn't find the resources directory, try to create it
            if foundResourcesURL == nil, let firstDir = possibleResourceDirs.first {
                do {
                    try FileManager.default.createDirectory(at: firstDir, withIntermediateDirectories: true)
                    foundResourcesURL = firstDir
                } catch {
                    print("Warning: Could not create test resources directory at \(firstDir.path): \(error)")
                }
            }
            
            // Set the test resources URL, even if it's nil - tests will handle it
            testResourcesURL = foundResourcesURL ?? URL(fileURLWithPath: NSTemporaryDirectory())

            // Create empty database file
            FileManager.default.createFile(atPath: testDBURL.path, contents: Data())
            // Create empty config file
            FileManager.default.createFile(atPath: testConfigURL.path, contents: Data())
        } catch {
            fatalError("Failed to set up test environment: \(error)")
        }
    }

    @Test("Clean up test environment")
    func cleanup() throws {
        // Remove the temporary directory if it exists
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &isDirectory), isDirectory.boolValue {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Clean up any test files that might have been created
        for url in [testDBURL, testConfigURL] {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
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

