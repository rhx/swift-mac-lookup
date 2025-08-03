import Foundation
import Testing

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
            "0011.2233.4455",
            "8:b6:1f:d0:f5:d8",  // Missing leading zeros
            "a:b:c:d:e:f",  // Single digit hex values
            "1:2:3:4:5:6",  // All single digits
        ]

        for macString in macStrings {
            let mac = try #require(try? MACAddress(string: macString))
            switch macString {
            case "8:b6:1f:d0:f5:d8":
                #expect(mac.description == "08:B6:1F:D0:F5:D8")
                #expect(mac.oui == "08B61F")
            case "a:b:c:d:e:f":
                #expect(mac.description == "0A:0B:0C:0D:0E:0F")
                #expect(mac.oui == "0A0B0C")
            case "1:2:3:4:5:6":
                #expect(mac.description == "01:02:03:04:05:06")
                #expect(mac.oui == "010203")
            default:
                #expect(mac.description == "00:11:22:33:44:55")
                #expect(mac.oui == "001122")
            }
        }
    }

    @Test("Invalid MAC address initialisation")
    func testInvalidMACAddress() throws {
        let invalidMACs = [
            "00:11:22:33:44:GG",  // Invalid character
            "00:11:22:33:44",  // Too short
            "00:11:22:33:44:55:66",  // Too long
            "not a mac address",  // Completely invalid
            "",  // Empty string
        ]

        for macString in invalidMACs {
            #expect(throws: (any Error).self) {
                _ = try MACAddress(string: macString)
            }
        }
    }

    @Test("Locally administered MAC address detection")
    func testLocallyAdministeredDetection() throws {
        // Test locally administered MAC addresses (second bit of first octet is 1)
        let locallyAdministeredMACs = [
            "02:00:00:00:00:00",  // 0x02 = 00000010
            "03:11:22:33:44:55",  // 0x03 = 00000011
            "06:aa:bb:cc:dd:ee",  // 0x06 = 00000110
            "07:ff:ff:ff:ff:ff",  // 0x07 = 00000111
            "52:24:97:0b:b8:ce",  // 0x52 = 01010010
            "82:6b:76:03:46:af",  // 0x82 = 10000010
        ]

        for macString in locallyAdministeredMACs {
            let mac = try #require(try? MACAddress(string: macString))
            #expect(
                mac.isLocallyAdministered == true,
                "MAC \(macString) should be detected as locally administered")
        }

        // Test universally administered MAC addresses (second bit of first octet is 0)
        let universallyAdministeredMACs = [
            "00:11:22:33:44:55",  // 0x00 = 00000000
            "01:aa:bb:cc:dd:ee",  // 0x01 = 00000001
            "04:ff:ff:ff:ff:ff",  // 0x04 = 00000100
            "05:12:34:56:78:90",  // 0x05 = 00000101
            "84:d6:c5:4e:f2:50",  // 0x84 = 10000100
            "f0:9e:9e:b0:13:30",  // 0xf0 = 11110000
        ]

        for macString in universallyAdministeredMACs {
            let mac = try #require(try? MACAddress(string: macString))
            #expect(
                mac.isLocallyAdministered == false,
                "MAC \(macString) should NOT be detected as locally administered")
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
    static let testURL = Bundle.module.url(forResource: "testoui", withExtension: "txt")
    private let tempDir: URL
    private let testDBURL: URL
    private let testConfigURL: URL
    private var testResourcesURL: URL

    @Test("Initialisation and setup")
    func testInitialisation() async throws {
        // The test just verifies that the files are created during init
        let lookup = MACLookup(localDatabaseURL: testDBURL, onlineURL: Self.testURL ?? ieeeOUIURL)
        let lastUpdated = await lookup.lastUpdated
        #expect(lastUpdated == nil)

        // Verify files were created
        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: testDBURL.path))
        #expect(fileManager.fileExists(atPath: testConfigURL.path))
    }

    @Test("Test resources can be loaded")
    func testResourcesLoad() throws {
        #expect(Self.testURL != nil)
        guard let resourceURL = Self.testURL else { return }
        do {
            let content = try String(contentsOf: resourceURL, encoding: .utf8)
            if content.isEmpty {
                fputs("Warning: Test resource 'testoui.txt' is empty\n", stderr)
            }
        } catch {
            fputs("Warning: Could not read test resource: \(error)\n", stderr)
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
                33-11-22     (hex)		Some Inc
                    Some Inc
                    Some City  Some State  123-456
                    AU

                44-11-23     (hex)		Another Company
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
        let lookup = MACLookup(localDatabaseURL: testDBPath, onlineURL: Self.testURL!)

        // Test updating the database first to populate it with mock data
        try await lookup.updateDatabase()

        // Test looking up a MAC address from the updated database
        let localVendor = try await lookup.lookup("00:11:22:33:44:55")

        // The OUIParser includes everything after the OUI in the vendor name
        // The MACVendorInfo.from(vendorName:) method uses this as the company name
        let expectedVendorName = "(hex) First"
        #expect(localVendor.companyName == expectedVendorName)
        #expect(localVendor.companyAddress.isEmpty)  // Address is empty in MACVendorInfo.from(vendorName:)
        #expect(localVendor.countryCode.isEmpty)  // Country code is empty in MACVendorInfo.from(vendorName:)

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
            localDatabaseURL: testDBURL, session: MockURLProtocol.createMockURLSession())

        // Test that the database was loaded
        try await lookup.loadLocalDatabase()
        let vendor = try await lookup.lookup("00:11:22:33:44:55")
        #expect(vendor.companyName == "Test Company")

        // Clean up
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Locally administered MAC address lookup")
    func testLocallyAdministeredLookup() async throws {
        // Create a unique temporary directory for this test
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MACLookupTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create test files
        let testDBURL = tempDir.appendingPathComponent("test-db.json")
        try testDatabase.write(to: testDBURL, atomically: true, encoding: .utf8)

        // Initialize MACLookup
        let lookup = MACLookup(localDatabaseURL: testDBURL)
        try await lookup.loadLocalDatabase()

        // Test locally administered MAC addresses should throw locallyAdministered error
        let locallyAdministeredMACs = [
            "02:00:00:00:00:00",
            "52:24:97:0b:b8:ce",
            "82:6b:76:03:46:af",
        ]

        for macString in locallyAdministeredMACs {
            await #expect(throws: (any Error).self) {
                do {
                    _ = try await lookup.lookup(macString)
                } catch let error as MACLookupError {
                    switch error {
                    case .locallyAdministered:
                        throw error  // Re-throw to satisfy the test expectation
                    default:
                        Issue.record("Expected locallyAdministered error but got \(error)")
                        throw error
                    }
                }
            }
        }

        // Test that universally administered MAC addresses still work normally
        await #expect(throws: Never.self) {
            _ = try await lookup.lookup("00:11:22:33:44:55")
        }

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
                testBundle.bundleURL.deletingLastPathComponent().appendingPathComponent(
                    "Resources"),
                testBundle.bundleURL.appendingPathComponent("MACLookupTests/Resources"),
            ].compactMap { $0 }

            // Try to find the resources directory, but don't fail if not found
            var foundResourcesURL: URL? = nil
            for url in possibleResourceDirs {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                    isDirectory.boolValue
                {
                    foundResourcesURL = url
                    break
                }
            }

            // If we couldn't find the resources directory, try to create it
            if foundResourcesURL == nil, let firstDir = possibleResourceDirs.first {
                do {
                    try FileManager.default.createDirectory(
                        at: firstDir, withIntermediateDirectories: true)
                    foundResourcesURL = firstDir
                } catch {
                    fputs(
                        "Warning: Could not create test resources directory at \(firstDir.path): \(error)\n",
                        stderr
                    )
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
        if FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        {
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
    static func `require`<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws
        -> T
    {
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
