import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A type that represents a MAC address and provides utilities for working with MAC addresses.
public struct MACAddress: Hashable, Codable, CustomStringConvertible, Sendable {
    /// The raw bytes of the MAC address.
    public let bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    
    /// A string representation of the MAC address in the format "XX:XX:XX:XX:XX:XX".
    public var description: String {
        String(format: "%02X:%02X:%02X:%02X:%02X:%02X",
               bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5)
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: MACAddress, rhs: MACAddress) -> Bool {
        lhs.bytes.0 == rhs.bytes.0 &&
        lhs.bytes.1 == rhs.bytes.1 &&
        lhs.bytes.2 == rhs.bytes.2 &&
        lhs.bytes.3 == rhs.bytes.3 &&
        lhs.bytes.4 == rhs.bytes.4 &&
        lhs.bytes.5 == rhs.bytes.5
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes.0)
        hasher.combine(bytes.1)
        hasher.combine(bytes.2)
        hasher.combine(bytes.3)
        hasher.combine(bytes.4)
        hasher.combine(bytes.5)
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case byte0, byte1, byte2, byte3, byte4, byte5
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let byte0 = try container.decode(UInt8.self, forKey: .byte0)
        let byte1 = try container.decode(UInt8.self, forKey: .byte1)
        let byte2 = try container.decode(UInt8.self, forKey: .byte2)
        let byte3 = try container.decode(UInt8.self, forKey: .byte3)
        let byte4 = try container.decode(UInt8.self, forKey: .byte4)
        let byte5 = try container.decode(UInt8.self, forKey: .byte5)
        self.bytes = (byte0, byte1, byte2, byte3, byte4, byte5)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bytes.0, forKey: .byte0)
        try container.encode(bytes.1, forKey: .byte1)
        try container.encode(bytes.2, forKey: .byte2)
        try container.encode(bytes.3, forKey: .byte3)
        try container.encode(bytes.4, forKey: .byte4)
        try container.encode(bytes.5, forKey: .byte5)
    }
    
    /// The first three bytes of the MAC address, known as the OUI (Organizationally Unique Identifier).
    public var oui: String { String(description.prefix(8)) }
    
    /// Creates a MAC address from a string representation.
    /// - Parameter string: A string containing a MAC address in common formats (e.g., "00:11:22:33:44:55" or "00-11-22-33-44-55").
    /// - Throws: `MACLookupError.invalidMACAddress` if the string cannot be parsed as a valid MAC address.
    public init(string: String) throws {
        let normalized = string
            .replacingOccurrences(of: "-", with: ":")
            .replacingOccurrences(of: ".", with: ":")
            .lowercased()
        
        let pattern = #"^([0-9a-fA-F]{2}[:]?){5}([0-9a-fA-F]{2})$"#
        guard normalized.range(of: pattern, options: .regularExpression) != nil else {
            throw MACLookupError.invalidMACAddress(string)
        }
        
        let hexDigits = normalized.components(separatedBy: ":").joined()
        guard hexDigits.count == 12 else {
            throw MACLookupError.invalidMACAddress(string)
        }
        
        var index = hexDigits.startIndex
        var bytes: [UInt8] = []
        
        for _ in 0..<6 {
            let nextIndex = hexDigits.index(index, offsetBy: 2)
            let byteString = hexDigits[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                throw MACLookupError.invalidMACAddress(string)
            }
            bytes.append(byte)
            index = nextIndex
        }
        
        self.bytes = (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5])
    }
}

/// Information about a MAC address vendor.
public struct MACVendorInfo: Codable, Sendable {
    /// The MAC address prefix (OUI).
    public let prefix: String
    
    /// The name of the company that owns the MAC address block.
    public let companyName: String
    
    /// The full company address.
    public let companyAddress: String
    
    /// The country code of the company.
    public let countryCode: String
    
    /// The type of the MAC address block (e.g., MA-L, MA-M, MA-S).
    public let blockType: String
    
    /// The date when this record was last updated.
    public let updated: String
    
    /// Indicates if the record is private.
    public let isPrivate: Bool
    
    /// The raw data from the API response.
    public let rawData: [String: String]
    
    private enum CodingKeys: String, CodingKey {
        case prefix = "oui"
        case companyName = "company"
        case companyAddress = "address"
        case countryCode = "country"
        case blockType = "type"
        case updated
        case isPrivate = "private"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prefix = try container.decode(String.self, forKey: .prefix)
        companyName = try container.decode(String.self, forKey: .companyName)
        companyAddress = try container.decode(String.self, forKey: .companyAddress)
        countryCode = try container.decode(String.self, forKey: .countryCode)
        blockType = try container.decode(String.self, forKey: .blockType)
        updated = try container.decode(String.self, forKey: .updated)
        isPrivate = try container.decode(Bool.self, forKey: .isPrivate)
        
        // Store raw data for any additional fields
        rawData = try decoder.singleValueContainer().decode([String: String].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prefix, forKey: .prefix)
        try container.encode(companyName, forKey: .companyName)
        try container.encode(companyAddress, forKey: .companyAddress)
        try container.encode(countryCode, forKey: .countryCode)
        try container.encode(blockType, forKey: .blockType)
        try container.encode(updated, forKey: .updated)
        try container.encode(isPrivate, forKey: .isPrivate)
    }
}

/// Errors that can occur during MAC address lookup operations.
public enum MACLookupError: Error, LocalizedError, Sendable {
    /// The provided string is not a valid MAC address.
    case invalidMACAddress(String)
    
    /// The MAC address was not found in the database.
    case notFound(String)
    
    /// An error occurred while accessing the local database.
    case databaseError(Error)
    
    /// A network error occurred.
    case networkError(Error)
    
    /// The API request failed.
    case apiError(String)
    
    /// The configuration file is missing or invalid.
    case invalidConfiguration(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidMACAddress(let address):
            return "Invalid MAC address format: \(address)"
        case .notFound(let address):
            return "No vendor information found for MAC address: \(address)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidConfiguration(let message):
            return "Configuration error: \(message)"
        }
    }
}

/// A type that provides functionality to look up MAC address vendor information.
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public actor MACLookup {
    /// The shared singleton instance.
    public static let shared = MACLookup()
    
    private let localDatabaseURL: URL
    private let configURL: URL
    private var localDatabase: [String: MACVendorInfo] = [:]
    private let session: URLSession
    private var apiKey: String?
    private let decoder = JSONDecoder()
    
    /// The date when the local database was last updated.
    public private(set) var lastUpdated: Date?
    
    /// Creates a new MACLookup instance with the specified database and configuration URLs.
    /// - Parameters:
    ///   - localDatabaseURL: The URL of the local database file. Defaults to "macaddress-db.json" in the application support directory.
    ///   - configURL: The URL of the configuration file. Defaults to "config.yaml" in the application support directory.
    public init(localDatabaseURL: URL? = nil, configURL: URL? = nil) {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.maclookup"
        let appSupportDir = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        
        // Create application support directory if it doesn't exist
        try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        
        self.localDatabaseURL = localDatabaseURL ?? appSupportDir.appendingPathComponent("macaddress-db.json")
        self.configURL = configURL ?? appSupportDir.appendingPathComponent("config.yaml")
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }
    
    /// Loads the local database into memory.
    /// - Throws: `MACLookupError.databaseError` if the database cannot be loaded.
    public func loadLocalDatabase() throws {
        let data = try Data(contentsOf: localDatabaseURL)
        let database = try decoder.decode([String: MACVendorInfo].self, from: data)
        self.localDatabase = database
        
        // Get the last modified date of the database file
        let attributes = try FileManager.default.attributesOfItem(atPath: localDatabaseURL.path)
        self.lastUpdated = attributes[.modificationDate] as? Date
    }
    
    /// Looks up vendor information for a MAC address.
    /// - Parameter macAddress: The MAC address to look up, either as a string or a `MACAddress` instance.
    /// - Returns: A `MACVendorInfo` instance containing the vendor information.
    /// - Throws: `MACLookupError` if the lookup fails for any reason.
    public func lookup(_ macAddress: String) async throws -> MACVendorInfo {
        let address = try MACAddress(string: macAddress)
        return try await lookup(address)
    }
    
    /// Looks up vendor information for a MAC address.
    /// - Parameter macAddress: The MAC address to look up.
    /// - Returns: A `MACVendorInfo` instance containing the vendor information.
    /// - Throws: `MACLookupError` if the lookup fails for any reason.
    public func lookup(_ macAddress: MACAddress) async throws -> MACVendorInfo {
        // First try local database
        if let vendor = localDatabase[macAddress.oui] {
            return vendor
        }
        
        // If not found locally, try the online API
        return try await lookupOnline(macAddress)
    }
    
    /// Updates the local database with the latest data from the online source.
    /// - Throws: `MACLookupError` if the update fails for any reason.
    private func updateDatabase() async throws {
        let url = URL(string: "https://maclookup.app/downloads/json-database")!
        
        // Use URLSession with completion handler for broader platform support
        let data: Data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let task = session.dataTask(with: url) { data, _, error in
                if let error = error {
                    continuation.resume(throwing: MACLookupError.networkError(error))
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: MACLookupError.networkError(
                        NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil)
                    ))
                }
            }
            task.resume()
        }
        
        // Parse the downloaded data to ensure it's valid JSON
        _ = try decoder.decode([String: MACVendorInfo].self, from: data)
        
        // Save the downloaded data to the local database file
        try data.write(to: localDatabaseURL)
        
        // Reload the local database
        try loadLocalDatabase()
    }
    
    // MARK: - Private Methods
    
    private func lookupOnline(_ macAddress: MACAddress) async throws -> MACVendorInfo {
        // Check if we have an API key
        guard let apiKey = try? String(contentsOf: configURL).trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            throw MACLookupError.invalidConfiguration("API key not found in config file")
        }
        
        let urlString = "https://api.maclookup.app/v2/macs/\(macAddress.oui)?apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw MACLookupError.invalidConfiguration("Invalid API URL")
        }
        
        // Make the API request
        let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let task = session.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: MACLookupError.networkError(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: MACLookupError.apiError("Invalid server response"))
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: MACLookupError.apiError("No data received"))
                    return
                }
                
                continuation.resume(returning: data)
            }
            task.resume()
        }
        
        // Parse the response
        do {
            var result = try JSONDecoder().decode([String: String].self, from: data)
            guard let company = result["company"], !company.isEmpty else {
                throw MACLookupError.notFound(macAddress.description)
            }
            
            // Update the result with the OUI from the MAC address
            result["oui"] = macAddress.oui
            
            // Convert the dictionary to JSON data and then decode into MACVendorInfo
            let vendorData = try JSONSerialization.data(withJSONObject: result, options: [])
            let decoder = JSONDecoder()
            return try decoder.decode(MACVendorInfo.self, from: vendorData)
        } catch {
            throw MACLookupError.apiError("Failed to decode API response: \(error.localizedDescription)")
        }
    }
}
