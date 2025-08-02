import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The URL of the IEEE OUI file.
public let ieeeOUIURL: URL = .init(string: "https://standards-oui.ieee.org/oui/oui.txt")!

/// A type that represents a MAC address and provides utilities for working with MAC addresses.
public struct MACAddress: Hashable, Codable, CustomStringConvertible, Sendable {
    /// The raw bytes of the MAC address.
    public let bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    /// A string representation of the MAC address in the format "XX:XX:XX:XX:XX:XX".
    public var description: String {
        String(
            format: "%02X:%02X:%02X:%02X:%02X:%02X",
            bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5)
    }

    // MARK: - Equatable

    public static func == (lhs: MACAddress, rhs: MACAddress) -> Bool {
        lhs.bytes.0 == rhs.bytes.0 && lhs.bytes.1 == rhs.bytes.1 && lhs.bytes.2 == rhs.bytes.2
            && lhs.bytes.3 == rhs.bytes.3 && lhs.bytes.4 == rhs.bytes.4
            && lhs.bytes.5 == rhs.bytes.5
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
    /// Returns the OUI in the format "001122" (without colons).
    public var oui: String {
        String(format: "%02X%02X%02X", bytes.0, bytes.1, bytes.2)
    }

    /// Indicates whether this MAC address is locally administered.
    /// A MAC address is locally administered if the second bit of the first octet is set to 1.
    public var isLocallyAdministered: Bool {
        return (bytes.0 & 0x02) != 0
    }

    /// Creates a MAC address from a string representation.
    /// - Parameter string: A string containing a MAC address in common formats (e.g., "00:11:22:33:44:55" or "00-11-22-33-44-55").
    /// - Throws: `MACLookupError.invalidMACAddress` if the string cannot be parsed as a valid MAC address.
    public init(string: String) throws {
        let normalized =
            string
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

    /// A dictionary containing all the raw data from the source.
    public let rawData: [String: String]

    /// Creates a new MACVendorInfo instance with the specified values.
    /// - Parameters:
    ///   - prefix: The MAC address prefix (OUI).
    ///   - companyName: The name of the company.
    ///   - companyAddress: The company's address. Defaults to an empty string.
    ///   - countryCode: The country code. Defaults to an empty string.
    ///   - blockType: The block type (e.g., "MA-L"). Defaults to "MA-L".
    ///   - updated: The last updated timestamp. Defaults to an empty string.
    ///   - isPrivate: Whether the record is private. Defaults to false.
    ///   - rawData: Additional raw data. If nil, it will be generated from the other parameters.
    public init(
        prefix: String,
        companyName: String,
        companyAddress: String = "",
        countryCode: String = "",
        blockType: String = "MA-L",
        updated: String = "",
        isPrivate: Bool = false,
        rawData: [String: String]? = nil
    ) {
        self.prefix = prefix
        self.companyName = companyName
        self.companyAddress = companyAddress
        self.countryCode = countryCode
        self.blockType = blockType
        self.updated = updated
        self.isPrivate = isPrivate

        if let rawData = rawData {
            self.rawData = rawData
        } else {
            self.rawData = [
                "oui": prefix,
                "company": companyName,
                "address": companyAddress,
                "country": countryCode,
                "type": blockType,
                "updated": updated,
                "private": isPrivate ? "true" : "false",
            ]
        }
    }

    private enum CodingKeys: String, CodingKey {
        case prefix = "oui"
        case companyName = "company"
        case companyAddress = "address"
        case countryCode = "country"
        case blockType = "type"
        case updated
        case isPrivate = "private"
    }

    // Helper to decode a value that might be a String or a Bool as a String
    private static func decodeStringOrBool(
        from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
    ) throws -> String {
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return boolValue ? "true" : "false"
        }
        return try container.decodeIfPresent(String.self, forKey: key) ?? ""
    }

    /// Initializes a MACVendorInfo instance from a decoder.
    /// - Parameter decoder: The decoder to use for decoding.
    /// - Throws: An error if the decoding fails.
    public init(from decoder: Decoder) throws {
        // First decode all known fields
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode required fields
        prefix = try container.decode(String.self, forKey: .prefix)
        companyName = try container.decode(String.self, forKey: .companyName)

        // Decode optional fields with defaults
        companyAddress = try container.decodeIfPresent(String.self, forKey: .companyAddress) ?? ""
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode) ?? ""
        blockType = try container.decodeIfPresent(String.self, forKey: .blockType) ?? ""
        updated = try container.decodeIfPresent(String.self, forKey: .updated) ?? ""

        // Handle private field that might be a string or a boolean
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .isPrivate) {
            isPrivate = boolValue
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .isPrivate)
        {
            isPrivate = stringValue.lowercased() == "true"
        } else {
            isPrivate = false
        }

        // Store all the raw data as strings
        var rawData: [String: String] = [
            "oui": prefix,
            "company": companyName,
            "address": companyAddress,
            "country": countryCode,
            "type": blockType,
            "updated": updated,
            "private": isPrivate ? "true" : "false",
        ]

        // Try to decode any additional fields using a dynamic coding keys approach
        do {
            let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
            for key in dynamicContainer.allKeys {
                // Skip already processed keys
                if CodingKeys(stringValue: key.stringValue) != nil {
                    continue
                }

                // Try to decode the value as a string, bool, number, or null
                if let value = try? dynamicContainer.decodeIfPresent(String.self, forKey: key) {
                    rawData[key.stringValue] = value
                } else if let value = try? dynamicContainer.decodeIfPresent(Bool.self, forKey: key)
                {
                    rawData[key.stringValue] = value ? "true" : "false"
                } else if let value = try? dynamicContainer.decodeIfPresent(Int.self, forKey: key) {
                    rawData[key.stringValue] = String(value)
                } else if let value = try? dynamicContainer.decodeIfPresent(
                    Double.self, forKey: key)
                {
                    rawData[key.stringValue] = String(value)
                } else if (try? dynamicContainer.decodeNil(forKey: key)) == true {
                    rawData[key.stringValue] = "null"
                }
            }
        } catch {
            // Ignore errors in dynamic decoding - we already have the main fields
            print("Warning: Failed to decode additional fields: \(error)")
        }

        self.rawData = rawData
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

    // Helper struct for dynamic key decoding
    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}

/// Errors that can occur during MAC address lookup operations.
public enum MACLookupError: Error, LocalizedError, Sendable {
    /// The provided string is not a valid MAC address.
    case invalidMACAddress(String)

    /// The MAC address was not found in the database.
    case notFound(String)

    /// The MAC address is locally administered and has no vendor information.
    case locallyAdministered(String)

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
        case .locallyAdministered(let address):
            return "MAC address \(address) is locally administered and has no vendor information"
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

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public actor MACLookup {
    /// The URL session to use for network requests.
    private let session: URLSession

    /// The URL of the local database file.
    private let localDatabaseURL: URL

    /// The URL of the online OUI database.
    private let onlineURL: URL

    /// The in-memory cache of MAC address to vendor information.
    private var localDatabase: [String: MACVendorInfo] = [:]
    private let decoder = JSONDecoder()

    /// The date when the local database was last updated.
    public private(set) var lastUpdated: Date?

    /// Creates a new MACLookup instance with the specified database and configuration URLs.
    /// - Parameters:
    ///   - localDatabaseURL: The URL of the local database file. Defaults to a file named "macaddress-db.json" in the user's application support directory.
    ///   - onlineURL: The URL of the online OUI database. Defaults to the official IEEE OUI text file URL.
    ///   - session: The URLSession to use for network requests. Defaults to a new URLSession with default configuration.
    public init(
        localDatabaseURL: URL? = nil,
        onlineURL: URL = ieeeOUIURL,
        session: URLSession? = nil
    ) {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.maclookup"
        let appSupportDir = appSupport.appendingPathComponent(bundleID, isDirectory: true)

        // Create application support directory if it doesn't exist
        try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        self.localDatabaseURL =
            localDatabaseURL ?? appSupportDir.appendingPathComponent("macaddress-db.json")
        self.onlineURL = onlineURL

        // Use the provided session or create a new one
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.urlCache = nil
            self.session = URLSession(configuration: config)
        }
    }

    /// Loads the local database from disk.
    ///
    /// - Throws: `MACLookupError.databaseError` if the database cannot be loaded.
    public func loadLocalDatabase() throws {
        let data = try Data(contentsOf: localDatabaseURL)
        let database = try decoder.decode([String: MACVendorInfo].self, from: data)
        self.localDatabase = database

        // Get the last modified date of the database file
        let attributes = try FileManager.default.attributesOfItem(atPath: localDatabaseURL.path)
        self.lastUpdated = attributes[.modificationDate] as? Date
    }

    /// Saves the local database to disk.
    /// - Throws: `MACLookupError.databaseError` if the database cannot be saved.
    public func saveLocalDatabase() async throws {
        let data = try JSONEncoder().encode(localDatabase)

        // Perform file I/O in a detached task
        try await Task.detached {
            try data.write(to: self.localDatabaseURL, options: [.atomic])
        }.value

        // Update the last modified date in the actor's context
        self.lastUpdated = Date()
    }

    /// Looks up vendor information for a MAC address in the local database only.
    /// - Parameter macAddress: The MAC address to look up.
    /// - Returns: The vendor information if found.
    /// - Throws: `MACLookupError.invalidMACAddress` if the MAC address is invalid.
    /// - Throws: `MACLookupError.locallyAdministered` if the MAC address is locally administered.
    /// - Throws: `MACLookupError.notFound` if no vendor information is found in the local database.
    public func lookupLocal(_ macAddress: String) throws -> MACVendorInfo {
        let address = try MACAddress(string: macAddress)

        // Check if the MAC address is locally administered
        if address.isLocallyAdministered {
            throw MACLookupError.locallyAdministered(macAddress)
        }

        guard let vendorInfo = localDatabase[address.oui] else {
            throw MACLookupError.notFound("No vendor found for MAC address: \(macAddress)")
        }
        return vendorInfo
    }

    /// Internal helper to get vendor info from local database without throwing
    private func getLocalVendorInfo(for address: MACAddress) -> MACVendorInfo? {
        return localDatabase[address.oui]
    }

    /// Looks up vendor information for a MAC address by downloading from the online database.
    /// - Parameters:
    ///   - macAddress: The MAC address to look up.
    ///   - updateLocal: Whether to update the local database with the results. Defaults to `true`.
    /// - Returns: The vendor information if found.
    /// - Throws: Errors related to network operations or parsing.
    public func lookupOnline(_ macAddress: String, updateLocal: Bool = true) async throws
        -> MACVendorInfo
    {
        let address = try MACAddress(string: macAddress)

        // Download and parse the OUI database
        let (data, _) = try await session.data(from: onlineURL)

        // Parse the OUI database
        let ouiDictionary = try OUIParser.parse(data)

        // Look up the vendor info for the OUI
        let oui = address.oui.prefix(6).uppercased()  // Use first 6 characters of OUI
        guard let vendorName = ouiDictionary[String(oui)] else {
            throw MACLookupError.notFound("No vendor found for MAC address: \(macAddress)")
        }

        // Create a MACVendorInfo instance from the vendor name
        let vendorInfo = MACVendorInfo.from(vendorName: vendorName)

        // Update local database if requested
        if updateLocal {
            localDatabase[String(oui)] = vendorInfo
            try await saveLocalDatabase()
        }

        return vendorInfo
    }

    /// Looks up vendor information for a MAC address, first checking the local database
    /// Looks up the vendor information for a MAC address.
    /// This method first checks if the MAC address is locally administered,
    /// then tries to find the vendor information in the local database,
    /// and then falling back to the online database if not found.
    /// - Parameter macAddress: The MAC address to look up.
    /// - Returns: The vendor information if found.
    /// - Throws: `MACLookupError` if the lookup fails.
    public func lookup(_ macAddress: String) async throws -> MACVendorInfo {
        let address = try MACAddress(string: macAddress)

        // Check if the MAC address is locally administered
        if address.isLocallyAdministered {
            throw MACLookupError.locallyAdministered(macAddress)
        }

        do {
            return try lookupLocal(macAddress)
        } catch MACLookupError.notFound {
            return try await lookupOnline(macAddress)
        } catch {
            throw error
        }
    }

    /// Looks up the vendor information for a MAC address.
    /// - Parameter macAddress: The MAC address to look up.
    /// - Returns: The vendor information if found.
    /// - Throws: `MACLookupError` if the lookup fails.
    public func lookup(_ macAddress: MACAddress) async throws -> MACVendorInfo {
        // Check if the MAC address is locally administered
        if macAddress.isLocallyAdministered {
            throw MACLookupError.locallyAdministered(macAddress.description)
        }

        // First try local lookup
        if let vendorInfo = getLocalVendorInfo(for: macAddress) {
            return vendorInfo
        }

        // If not found locally, try online lookup
        do {
            return try await lookupOnline(macAddress.description)
        } catch MACLookupError.notFound {
            // Re-throw with a more specific error message
            throw MACLookupError.notFound("No vendor found for MAC address: \(macAddress)")
        } catch {
            throw error
        }
    }

    /// Update local database.
    ///
    /// This function updates the local database with the latest data
    /// from the given online source.
    ///
    /// - Parameter url: The URL of the online source to update from.
    ///
    /// - Throws: `MACLookupError` if the update fails for any reason.
    public func updateDatabase(from onlineURL: URL? = nil) async throws {
        let url = onlineURL ?? self.onlineURL
        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            data = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Data, Error>) in
                let task = session.dataTask(with: url) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: MACLookupError.networkError(error))
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse,
                        (200...299).contains(httpResponse.statusCode),
                        let data = data
                    else {
                        continuation.resume(
                            throwing: MACLookupError.networkError(
                                NSError(
                                    domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse,
                                    userInfo: nil)
                            ))
                        return
                    }

                    continuation.resume(returning: data)
                }
                @discardableResult let _ = task.resume()
            }
        }

        // Parse the OUI data
        let ouiDictionary = try OUIParser.parse(data)

        // Convert to MACVendorInfo format
        var vendorInfo: [String: MACVendorInfo] = [:]
        for (prefix, vendorName) in ouiDictionary {
            vendorInfo[prefix] = MACVendorInfo.from(vendorName: vendorName)
        }

        // Encode and save the data
        let jsonData = try JSONEncoder().encode(vendorInfo)
        try jsonData.write(to: localDatabaseURL)

        // Reload the local database
        try loadLocalDatabase()
    }

    /// Online entry lookup.
    ///
    /// This function looks up vendor information for a MAC address online.
    ///
    /// - Parameters:
    ///     - macAddress: The MAC address to look up.
    ///     - url: The URL of the online source to look up from. Defaults to the IEEE OUI URL.
    /// - Returns: A `MACVendorInfo` instance containing the vendor information.
    public func lookupOnline(_ macAddress: MACAddress, at onlineURL: URL? = nil) async throws
        -> MACVendorInfo
    {
        let url = onlineURL ?? self.onlineURL

        // Download the latest OUI data and perform the lookup
        let oui = macAddress.oui

        // First try to find in local database
        if let vendor = localDatabase[oui] {
            return vendor
        }

        // If not found, try to update the database
        try await updateDatabase(from: url)

        // Try again after update
        if let vendor = localDatabase[oui] {
            return vendor
        }

        // If still not found, try with shorter prefixes (OUI-36 and OUI-28)
        let prefixes = [
            String(oui.prefix(6)),  // OUI-36 (28-bit)
            String(oui.prefix(4)),  // OUI-28 (20-bit)
        ]

        for prefix in prefixes {
            if let vendor = localDatabase[prefix] {
                return vendor
            }
        }

        throw MACLookupError.notFound("No vendor found for MAC address: \(macAddress.description)")
    }
}
