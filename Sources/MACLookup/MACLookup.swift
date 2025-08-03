import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The URL of the IEEE OUI file.
///
/// This constant provides the default URL for downloading the official IEEE
/// Organisationally Unique Identifier (OUI) database in text format. The database
/// contains manufacturer assignments for MAC address prefixes and is updated
/// regularly by the IEEE Registration Authority.
public let ieeeOUIURL: URL = .init(string: "https://standards-oui.ieee.org/oui/oui.txt")!

/// A type that represents a MAC address and provides utilities for working with MAC addresses.
///
/// `MACAddress` encapsulates a 6-byte Media Access Control address and provides
/// parsing, validation, and formatting capabilities. The type supports various
/// common MAC address formats and can determine whether an address is locally
/// administered.
///
/// ## Supported Formats
///
/// The initialiser accepts several common MAC address formats:
/// - Colon-separated: `"00:11:22:33:44:55"`
/// - Hyphen-separated: `"00-11-22-33-44-55"`
/// - Dot-separated: `"00.11.22.33.44.55"`
/// - Cisco format: `"0011.2233.4455"`
/// - Raw hex: `"001122334455"`
///
/// ## Thread Safety
///
/// `MACAddress` is a value type and inherently thread-safe. It conforms to
/// `Sendable` for use across actor boundaries.
public struct MACAddress: Hashable, Codable, CustomStringConvertible, Sendable {
    /// The raw bytes of the MAC address.
    ///
    /// Stored as a 6-tuple of unsigned 8-bit integers representing the
    /// 6 octets of the MAC address in network byte order.
    public let bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    /// A string representation of the MAC address in the format "XX:XX:XX:XX:XX:XX".
    ///
    /// Returns the MAC address formatted with uppercase hexadecimal digits
    /// separated by colons, which is the most common presentation format.
    public var description: String {
        String(
            format: "%02X:%02X:%02X:%02X:%02X:%02X",
            bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5)
    }

    // MARK: - Equatable

    /// Returns a Boolean value indicating whether two MAC addresses are equal.
    ///
    /// Two MAC addresses are considered equal if all six bytes match exactly.
    ///
    /// - Parameters:
    ///   - lhs: A MAC address to compare.
    ///   - rhs: Another MAC address to compare.
    /// - Returns: `true` if the MAC addresses are equal; otherwise, `false`.
    public static func == (lhs: MACAddress, rhs: MACAddress) -> Bool {
        lhs.bytes.0 == rhs.bytes.0 && lhs.bytes.1 == rhs.bytes.1 && lhs.bytes.2 == rhs.bytes.2
            && lhs.bytes.3 == rhs.bytes.3 && lhs.bytes.4 == rhs.bytes.4
            && lhs.bytes.5 == rhs.bytes.5
    }

    // MARK: - Hashable

    /// Hashes the essential components of this MAC address by feeding them into the given hasher.
    ///
    /// All six bytes of the MAC address contribute to the hash value to ensure
    /// proper distribution in hash-based collections.
    ///
    /// - Parameter hasher: The hasher to use when combining the components of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes.0)
        hasher.combine(bytes.1)
        hasher.combine(bytes.2)
        hasher.combine(bytes.3)
        hasher.combine(bytes.4)
        hasher.combine(bytes.5)
    }

    // MARK: - Codable

    /// Coding keys for JSON serialisation.
    ///
    /// Maps each byte of the MAC address to a separate JSON property for
    /// explicit encoding and decoding behaviour.
    private enum CodingKeys: String, CodingKey {
        case byte0, byte1, byte2, byte3, byte4, byte5
    }

    /// Creates a new instance by decoding from the given decoder.
    ///
    /// Decodes each byte individually to maintain precision and avoid
    /// platform-specific integer encoding issues.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the data is corrupted or invalid.
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

    /// Encodes this instance into the given encoder.
    ///
    /// Encodes each byte as a separate value to ensure consistent
    /// cross-platform serialisation.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if any value fails to encode.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bytes.0, forKey: .byte0)
        try container.encode(bytes.1, forKey: .byte1)
        try container.encode(bytes.2, forKey: .byte2)
        try container.encode(bytes.3, forKey: .byte3)
        try container.encode(bytes.4, forKey: .byte4)
        try container.encode(bytes.5, forKey: .byte5)
    }

    /// The Organisationally Unique Identifier (OUI) portion of the MAC address.
    ///
    /// Returns the first three bytes of the MAC address as a 6-character
    /// uppercase hexadecimal string. The OUI identifies the manufacturer
    /// or vendor of the network interface.
    public var oui: String {
        String(format: "%02X%02X%02X", bytes.0, bytes.1, bytes.2)
    }

    /// Indicates whether this MAC address is locally administered.
    ///
    /// A MAC address is locally administered if the second bit (the "locally
    /// administered" bit) of the first octet is set to 1. Locally administered
    /// addresses are assigned by network administrators rather than manufacturers
    /// and do not appear in the IEEE OUI database.
    ///
    /// This property is useful for determining whether a MAC address lookup
    /// is likely to succeed, as locally administered addresses will not have
    /// associated vendor information.
    public var isLocallyAdministered: Bool {
        return (bytes.0 & 0x02) != 0
    }

    /// Creates a MAC address from a string representation.
    ///
    /// Parses various common MAC address formats into a validated `MACAddress`
    /// instance. The parser is flexible and accepts different separator
    /// characters and formatting styles commonly used across different systems.
    ///
    /// The parser normalises input by:
    /// 1. Converting separators to a common format
    /// 2. Validating the overall structure
    /// 3. Ensuring exactly 12 hexadecimal digits
    /// 4. Converting to byte values
    ///
    /// ## Accepted Formats
    ///
    /// - `"00:11:22:33:44:55"` - Standard colon format
    /// - `"00-11-22-33-44-55"` - Windows-style hyphen format
    /// - `"00.11.22.33.44.55"` - Dot-separated format
    /// - `"0011.2233.4455"` - Cisco three-group format
    /// - `"001122334455"` - Raw hexadecimal string
    ///
    /// - Parameter string: A string containing a MAC address in any supported format.
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
///
/// `MACVendorInfo` encapsulates vendor information retrieved from the IEEE OUI
/// database or other sources. It contains both standardised fields and raw data
/// for extensibility.
///
/// ## Data Sources
///
/// Vendor information can come from:
/// - IEEE OUI database (primary source)
/// - Local overrides or customisations
/// - Cached API responses
/// - Third-party databases
///
/// The `rawData` property preserves the original source format for debugging
/// and future compatibility.
public struct MACVendorInfo: Codable, Sendable {
    /// The MAC address prefix (OUI).
    ///
    /// A 6-character hexadecimal string representing the Organisationally
    /// Unique Identifier assigned to the vendor. This typically corresponds
    /// to the first three bytes of MAC addresses from this vendor.
    public let prefix: String

    /// The name of the company that owns the MAC address block.
    ///
    /// The registered organisation name as recorded in the IEEE database.
    /// This may differ from commonly known brand names or subsidiaries.
    public let companyName: String

    /// The full company address.
    ///
    /// The registered business address of the organisation, including
    /// street address, city, state/province, postal code, and country
    /// as provided in the IEEE database.
    public let companyAddress: String

    /// The country code of the company.
    ///
    /// ISO 3166-1 alpha-2 country code (e.g., "US", "GB", "JP") indicating
    /// the country where the organisation is registered.
    public let countryCode: String

    /// The type of the MAC address block allocation.
    ///
    /// Indicates the size and type of MAC address allocation:
    /// - `"MA-L"` - Large allocation (24-bit OUI, 24-bit device identifier)
    /// - `"MA-M"` - Medium allocation (28-bit OUI, 20-bit device identifier)
    /// - `"MA-S"` - Small allocation (36-bit OUI, 12-bit device identifier)
    public let blockType: String

    /// The date when this record was last updated.
    ///
    /// Timestamp string indicating when the IEEE database entry was last
    /// modified. Format may vary depending on the data source.
    public let updated: String

    /// Indicates if the record is private.
    ///
    /// Boolean flag indicating whether this is a private allocation not
    /// intended for public use or registration.
    public let isPrivate: Bool

    /// A dictionary containing all the raw data from the source.
    ///
    /// Preserves the complete original data structure for debugging,
    /// extensibility, and compatibility with different data sources.
    /// Keys and values correspond to the source format.
    public let rawData: [String: String]

    /// Creates a new MACVendorInfo instance with the specified values.
    ///
    /// Constructs a vendor information record with the provided details.
    /// If no raw data is provided, a dictionary is automatically generated
    /// from the other parameters using standard field mappings.
    ///
    /// This initialiser is useful for creating vendor records from various
    /// data sources or for testing purposes.
    ///
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

    /// Decodes a value that might be either a String or Bool as a String.
    ///
    /// Helper method for handling the `private` field in IEEE database entries,
    /// which may be encoded as either a boolean value or a string representation.
    /// This provides flexibility when parsing data from different sources that
    /// may use different encoding strategies.
    ///
    /// - Parameters:
    ///   - container: The keyed decoding container to read from.
    ///   - key: The coding key for the field to decode.
    /// - Returns: String representation of the value ("true"/"false" for booleans, or the original string).
    /// - Throws: `DecodingError` if the value cannot be decoded as either type.
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

    /// Helper struct for dynamic key decoding during JSON parsing.
    ///
    /// `DynamicCodingKey` enables decoding of JSON objects with unknown or
    /// variable keys by implementing the `CodingKey` protocol. This is particularly
    /// useful for preserving arbitrary fields in the raw data dictionary whilst
    /// maintaining type safety for known fields.
    ///
    /// The struct supports both string-based and integer-based keys, making it
    /// suitable for various JSON structures that may contain either type of key.
    private struct DynamicCodingKey: CodingKey {
        /// The string representation of the coding key.
        ///
        /// Used as the primary key identifier for JSON field mapping.
        var stringValue: String

        /// The integer representation of the coding key, if applicable.
        ///
        /// Optional property that supports array-like JSON structures with
        /// numeric indices, though primarily used for object keys in this context.
        var intValue: Int?

        /// Creates a coding key from a string value.
        ///
        /// Primary initialiser for object keys in JSON structures. The integer
        /// value is set to `nil` as string keys typically don't have numeric equivalents.
        ///
        /// - Parameter stringValue: The string representation of the key.
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        /// Creates a coding key from an integer value.
        ///
        /// Alternative initialiser for numeric keys, converting the integer to
        /// its string representation for use in JSON field mapping.
        ///
        /// - Parameter intValue: The integer representation of the key.
        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}

/// Errors that can occur during MAC address lookups.
///
/// `MACLookupError` provides specific error cases for different failure scenarios,
/// enabling appropriate error handling and user feedback. Each error case includes
/// associated values with context about the specific failure.
///
/// ## Error Recovery
///
/// Different error types suggest different recovery strategies:
/// - `invalidMACAddress`: Validate input format before processing
/// - `notFound`: Accept that vendor is unknown or try alternative sources
/// - `locallyAdministered`: Handle as expected case for local addresses
/// - `networkError`: Implement retry logic or fall back to local cache
/// - `databaseError`: Check file permissions and storage availability
/// - `apiError`: Review API response and possibly update parsing logic
/// - `invalidConfiguration`: Verify configuration file format and content
public enum MACLookupError: Error, LocalizedError, Sendable {
    /// The provided string is not a valid MAC address format.
    ///
    /// Thrown when a string cannot be parsed as a MAC address due to
    /// invalid format, incorrect length, or non-hexadecimal characters.
    /// The associated value contains the invalid input string.
    case invalidMACAddress(String)

    /// The MAC address was not found in the database.
    ///
    /// Indicates that the OUI (first three bytes) of the MAC address
    /// is not present in the IEEE database. This may occur for newer
    /// allocations or private/experimental addresses.
    case notFound(String)

    /// The MAC address is locally administered and has no vendor information.
    ///
    /// Thrown when the MAC address has the locally administered bit set,
    /// indicating it was assigned by a network administrator rather than
    /// a manufacturer. Such addresses do not appear in vendor databases.
    case locallyAdministered(String)

    /// An error occurred while accessing the local database.
    ///
    /// Indicates problems with local file operations such as reading,
    /// writing, or parsing the cached database. The underlying error
    /// provides specific details about the failure.
    case databaseError(Error)

    /// A network error occurred during online lookup or database update.
    ///
    /// Represents failures in network communication, including connection
    /// timeouts, DNS resolution failures, or HTTP errors. The underlying
    /// error contains specific network failure details.
    case networkError(Error)

    /// The API request failed with an error response.
    ///
    /// Indicates that the online service returned an error response or
    /// the response format was unexpected. The associated string provides
    /// details about the specific API failure.
    case apiError(String)

    /// The configuration file is missing or invalid.
    ///
    /// Thrown when configuration data cannot be loaded or parsed correctly.
    /// This typically indicates file format issues or missing required fields.
    case invalidConfiguration(String)

    /// Provides a localised description of the error for user presentation.
    ///
    /// Returns a human-readable error message that describes the specific
    /// failure condition. The messages are designed to be helpful for both
    /// end users and developers, providing context about what went wrong
    /// and the associated data when applicable.
    ///
    /// Each error case includes relevant details such as the invalid input
    /// or the underlying system error to aid in debugging and user feedback.
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

/// An actor that provides thread-safe MAC address vendor lookup capabilities.
///
/// `MACLookup` manages both local database caching and online lookups from the IEEE
/// OUI database. The actor pattern ensures thread-safe access to the shared database
/// state whilst supporting concurrent lookup operations.
///
/// ## Database Management
///
/// The actor maintains a local cache of vendor information downloaded from the IEEE
/// database. This cache is automatically managed:
/// - Downloaded on first lookup if not present
/// - Stored persistently for offline operation
/// - Updated manually or automatically as needed
///
/// ## Thread Safety
///
/// All operations are actor-isolated to ensure thread safety when accessing the
/// shared database state. Multiple concurrent lookups are supported safely.
///
/// ## Performance
///
/// Local lookups are optimised for speed (~1ms), whilst online lookups may take
/// longer depending on network conditions. The actor balances performance with
/// data freshness through intelligent caching strategies.
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public actor MACLookup {
    /// The URL session used for network requests.
    ///
    /// Configured for reliable downloads of the IEEE database with appropriate
    /// timeout settings and cache policies.
    private let session: URLSession

    /// The URL of the local database cache file.
    ///
    /// Points to the persistent storage location where the downloaded IEEE
    /// database is cached. Defaults to the application support directory.
    private let localDatabaseURL: URL

    /// The URL of the online OUI database source.
    ///
    /// The remote location from which to download the IEEE OUI database.
    /// Typically points to the official IEEE standards server.
    private let onlineURL: URL

    /// The in-memory cache of OUI to vendor information mappings.
    ///
    /// Stores parsed vendor records indexed by OUI for fast lookup operations.
    /// Populated from the local database file or online source.
    private var localDatabase: [String: MACVendorInfo] = [:]

    /// JSON decoder for parsing vendor information.
    ///
    /// Configured decoder instance used for parsing cached database files
    /// and API responses into `MACVendorInfo` objects.
    private let decoder = JSONDecoder()

    /// The date when the local database was last updated.
    ///
    /// Tracks the timestamp of the most recent database update operation.
    /// Used to determine when a refresh may be needed and for diagnostics.
    public private(set) var lastUpdated: Date?

    /// Creates a new MACLookup instance with the specified configuration.
    ///
    /// Initialises the lookup service with custom database locations and network
    /// configuration. If no parameters are provided, sensible defaults are used
    /// including automatic directory creation and standard IEEE database URL.
    ///
    /// The initialiser sets up the directory structure needed for local caching
    /// and configures networking for reliable database downloads.
    ///
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

    /// Loads the local database from disk into memory.
    ///
    /// Reads the cached IEEE OUI database from the local file system and loads
    /// it into the in-memory cache for fast lookups. The method also updates
    /// the last modified timestamp based on the file's modification date.
    ///
    /// This operation is typically performed automatically when needed, but can
    /// be called explicitly to ensure the database is loaded before performing
    /// local-only operations.
    ///
    /// - Throws: `MACLookupError.databaseError` if the database file cannot be read or parsed.
    public func loadLocalDatabase() throws {
        let data = try Data(contentsOf: localDatabaseURL)
        let database = try decoder.decode([String: MACVendorInfo].self, from: data)
        self.localDatabase = database

        // Get the last modified date of the database file
        let attributes = try FileManager.default.attributesOfItem(atPath: localDatabaseURL.path)
        self.lastUpdated = attributes[.modificationDate] as? Date
    }

    /// Saves the in-memory database to persistent storage.
    ///
    /// Writes the current in-memory vendor database to the local cache file
    /// in JSON format. The operation is performed atomically to prevent
    /// corruption and updates the last modified timestamp.
    ///
    /// File I/O is performed in a detached task to avoid blocking the actor
    /// whilst maintaining thread safety for the timestamp update.
    ///
    /// - Throws: `MACLookupError.databaseError` if the database cannot be serialised or written to disk.
    public func saveLocalDatabase() async throws {
        let data = try JSONEncoder().encode(localDatabase)

        // Perform file I/O in a detached task
        try await Task.detached {
            try data.write(to: self.localDatabaseURL, options: [.atomic])
        }.value

        // Update the last modified date in the actor's context
        self.lastUpdated = Date()
    }

    /// Looks up vendor information using only the local database cache.
    ///
    /// Performs a fast lookup against the in-memory database without any
    /// network access. This method is ideal for offline operation or when
    /// network latency must be avoided.
    ///
    /// The lookup process:
    /// 1. Parses and validates the MAC address format
    /// 2. Checks for locally administered addresses (which have no vendor)
    /// 3. Extracts the OUI and searches the local database
    /// 4. Returns vendor information if found
    ///
    /// - Parameter macAddress: The MAC address string to look up in any supported format.
    /// - Returns: The vendor information if found in the local database.
    /// - Throws: `MACLookupError.invalidMACAddress` if the MAC address format is invalid.
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

    /// Retrieves vendor information from the local database without throwing errors.
    ///
    /// Internal helper method that performs a simple lookup in the in-memory
    /// database cache. Unlike `lookupLocal`, this method returns `nil` instead
    /// of throwing when the vendor is not found, making it suitable for use
    /// in fallback scenarios.
    ///
    /// This method is used internally by other lookup methods to check for
    /// cached data before attempting more expensive operations.
    ///
    /// - Parameter address: The MAC address to look up.
    /// - Returns: The vendor information if found in the local cache, or `nil` if not present.
    private func getLocalVendorInfo(for address: MACAddress) -> MACVendorInfo? {
        return localDatabase[address.oui]
    }

    /// Looks up vendor information by downloading from the online IEEE database.
    ///
    /// Downloads the complete IEEE OUI database and searches for the vendor
    /// information corresponding to the MAC address. This method always performs
    /// a network request and provides the most up-to-date information available.
    ///
    /// The lookup process:
    /// 1. Downloads the complete IEEE OUI database
    /// 2. Parses the text format into structured data
    /// 3. Searches for the MAC address OUI
    /// 4. Optionally updates the local cache
    ///
    /// Use this method when you need the latest vendor information or when
    /// the local database may be outdated.
    ///
    /// - Parameters:
    ///   - macAddress: The MAC address to look up in any supported format.
    ///   - updateLocal: Whether to update the local database with the downloaded data. Defaults to `true`.
    /// - Returns: The vendor information if found in the online database.
    /// - Throws: `MACLookupError.invalidMACAddress` if the MAC address format is invalid.
    /// - Throws: `MACLookupError.notFound` if no vendor information is found.
    /// - Throws: `MACLookupError.networkError` if the download fails.
    /// - Throws: `MACLookupError.apiError` if the response cannot be parsed.
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

    /// Looks up vendor information with intelligent fallback strategy.
    ///
    /// This is the primary lookup method that balances performance with accuracy.
    /// It uses a multi-stage lookup strategy to find vendor information efficiently:
    ///
    /// 1. Validates the MAC address format
    /// 2. Checks for locally administered addresses (returns error immediately)
    /// 3. Searches the local database cache (fast, offline)
    /// 4. Falls back to online lookup if not found locally
    /// 5. Updates local cache with online results
    ///
    /// This approach provides fast results when cached data is available whilst
    /// ensuring comprehensive coverage through online fallback.
    ///
    /// - Parameter macAddress: The MAC address to look up in any supported format.
    /// - Returns: The vendor information from either local cache or online source.
    /// - Throws: `MACLookupError.invalidMACAddress` if the MAC address format is invalid.
    /// - Throws: `MACLookupError.locallyAdministered` if the MAC address is locally administered.
    /// - Throws: `MACLookupError.notFound` if no vendor information is found in any source.
    /// - Throws: `MACLookupError.networkError` if online lookup fails and no local data exists.
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

    /// Looks up vendor information for a pre-parsed MAC address with intelligent fallback.
    ///
    /// This overload accepts a `MACAddress` instance directly, avoiding the need
    /// to re-parse the address string. It follows the same intelligent lookup
    /// strategy as the string-based method:
    ///
    /// 1. Checks for locally administered addresses (returns error immediately)
    /// 2. Searches the local database cache (fast, offline)
    /// 3. Falls back to online lookup if not found locally
    /// 4. Updates local cache with online results
    ///
    /// This method is particularly useful when you already have a parsed
    /// `MACAddress` instance or need to avoid repeated parsing overhead.
    ///
    /// - Parameter macAddress: The parsed MAC address to look up.
    /// - Returns: The vendor information from either local cache or online source.
    /// - Throws: `MACLookupError.locallyAdministered` if the MAC address is locally administered.
    /// - Throws: `MACLookupError.notFound` if no vendor information is found in any source.
    /// - Throws: `MACLookupError.networkError` if online lookup fails and no local data exists.
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

    /// Updates the local database with the latest IEEE OUI data.
    ///
    /// Downloads the complete IEEE OUI database from the specified source,
    /// parses the text format into structured vendor information, and replaces
    /// the local cache entirely. This operation ensures the local database
    /// contains the most current vendor assignments.
    ///
    /// The update process:
    /// 1. Downloads the OUI database from the specified URL
    /// 2. Parses the text format into structured data
    /// 3. Replaces the entire local database with new data
    /// 4. Saves the updated database to persistent storage
    /// 5. Updates the last modified timestamp
    ///
    /// This operation is network-intensive and may take time depending on
    /// connection speed. The database is approximately 2MB in size.
    ///
    /// - Parameter onlineURL: The URL of the online source to update from. Defaults to the IEEE OUI database.
    /// - Throws: `MACLookupError.networkError` if the download fails.
    /// - Throws: `MACLookupError.apiError` if the response format is invalid.
    /// - Throws: `MACLookupError.databaseError` if the local database cannot be saved.
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
