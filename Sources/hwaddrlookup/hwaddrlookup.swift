import ArgumentParser
import Foundation
import MACLookup

/// Actor responsible for managing cache file operations for the command-line tool.
///
/// `FileCacheManager` provides thread-safe access to cache file operations including
/// directory management, file existence checks, and cache validation logic. The actor
/// pattern ensures safe concurrent access to file system operations.
///
/// ## Cache Location
///
/// The cache is stored in the user's standard cache directory under a subdirectory
/// specific to this application. The location varies by platform:
/// - **macOS**: `~/Library/Caches/com.github.rhx.maclookup/`
/// - **Linux**: `~/.cache/com.github.rhx.maclookup/`
///
/// ## Thread Safety
///
/// All file operations are actor-isolated to prevent race conditions when multiple
/// operations attempt to access the cache simultaneously.
actor FileCacheManager {
    /// Shared singleton instance for cache management.
    ///
    /// Provides a single point of access for cache operations throughout the
    /// command-line tool to ensure consistent behaviour and avoid duplicate
    /// directory creation or file conflicts.
    static let shared = FileCacheManager()

    /// File manager instance for performing file system operations.
    ///
    /// Private instance used for all file system interactions including
    /// directory creation, file existence checks, and attribute reading.
    private let fileManager = FileManager.default

    /// Name of the cache file for storing MAC vendor data.
    ///
    /// Fixed filename used consistently across all cache operations to
    /// store the downloaded and parsed IEEE OUI database.
    private let cacheFileName = "mac-vendors.json"

    /// The directory path where cache files are stored.
    ///
    /// Computed property that returns the application-specific cache directory
    /// within the user's standard cache location. The directory is created
    /// automatically when needed.
    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.github.rhx.maclookup")
    }

    /// Returns the full URL path for the cache file.
    ///
    /// Constructs the complete file URL by combining the cache directory
    /// path with the standard cache filename. This provides a consistent
    /// location for the MAC vendor database cache.
    ///
    /// - Returns: The URL where the cache file should be stored.
    func getCacheFileURL() -> URL {
        cacheDirectory.appendingPathComponent(cacheFileName)
    }

    /// Ensures the cache directory exists, creating it if necessary.
    ///
    /// Creates the cache directory structure if it doesn't already exist.
    /// Uses `withIntermediateDirectories: true` to create any missing
    /// parent directories in the path.
    ///
    /// This method is called before any cache operations to ensure the
    /// directory structure is properly set up.
    ///
    /// - Throws: File system errors if directory creation fails.
    func ensureCacheDirectory() throws {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    /// Checks whether a file exists at the specified URL.
    ///
    /// Simple wrapper around FileManager's existence check that provides
    /// a clean interface for cache validation operations.
    ///
    /// - Parameter url: The file URL to check for existence.
    /// - Returns: `true` if the file exists, `false` otherwise.
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    /// Determines whether the cache should be updated based on various conditions.
    ///
    /// Implements the logic for deciding when to download a fresh copy of the
    /// IEEE database. The decision considers user preferences, cache existence,
    /// and operational mode. When debug mode is enabled, detailed information
    /// about the decision process is printed.
    ///
    /// ## Decision Logic
    ///
    /// - If `forceUpdate` is true, always update (unless local-only mode)
    /// - If cache doesn't exist and `localOnly` is true, don't update
    /// - If cache doesn't exist and online mode, update
    /// - If cache exists, use existing cache
    ///
    /// Debug output includes cache file location, existence, size, age, and
    /// decision rationale for troubleshooting purposes.
    ///
    /// - Parameters:
    ///   - forceUpdate: Whether to force an update regardless of cache state.
    ///   - localOnly: Whether to operate in offline mode only.
    ///   - debug: Whether to print debug information. Defaults to `false`.
    /// - Returns: A tuple containing whether to update and whether cache exists.
    func shouldUpdateCache(forceUpdate: Bool, localOnly: Bool, debug: Bool = false) async -> (
        shouldUpdate: Bool, cacheExists: Bool
    ) {
        let cacheFile = getCacheFileURL()
        let exists = fileExists(at: cacheFile)

        if debug {
            print("DEBUG: Cache file: \(cacheFile.path) (exists: \(exists))")
            if exists {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: cacheFile.path)
                    if let modDate = attributes[.modificationDate] as? Date {
                        print("DEBUG: Cache file last modified: \(modDate)")
                        let age = Date().timeIntervalSince(modDate)
                        print("DEBUG: Cache age: \(Int(age / 3600)) hours")
                    }
                    if let size = attributes[.size] as? Int64 {
                        print("DEBUG: Cache file size: \(size) bytes")
                    }
                } catch {
                    fputs("DEBUG: Error reading cache attributes: \(error)\n", stderr)
                }
            }
            print("DEBUG: Force update: \(forceUpdate)")
            print("DEBUG: Local only: \(localOnly)")
        }

        if forceUpdate {
            if debug { print("DEBUG: Forcing update due to --update flag") }
            return (true, exists)
        } else if !exists && localOnly {
            if debug { print("DEBUG: No cache and local-only mode") }
            return (false, false)
        } else if !exists {
            if debug { print("DEBUG: No cache found, will download") }
            return (true, false)
        }
        if debug { print("DEBUG: Using existing cache") }
        return (false, true)
    }
}

/// Command-line interface for MAC address vendor lookups.
///
/// `HWAddrLookup` provides a terminal-based interface to the MACLookup library,
/// supporting both single and batch MAC address processing. The tool maintains
/// a local cache of the IEEE OUI database for fast offline operation whilst
/// providing options for online updates when needed.
///
/// ## Usage Patterns
///
/// The tool supports several common usage patterns:
/// - Single address lookup with automatic cache management
/// - Batch processing of multiple addresses
/// - Offline operation using cached data only
/// - Forced database updates for current information
/// - Debug mode for troubleshooting and diagnostics
///
/// ## Cache Management
///
/// The tool automatically manages a local cache of vendor information:
/// - Downloads database on first use if not present
/// - Uses cached data for fast subsequent lookups
/// - Provides options to force updates or operate offline only
/// - Stores cache in platform-appropriate user directories
@main
struct HWAddrLookup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hwaddrlookup",
        abstract: "Look up vendor information for MAC addresses",
        discussion: """
            By default, looks up MAC addresses using a local cache. If no cache is available,
            it will be downloaded from the IEEE standards database.
            """
    )

    /// Forces an update of the local database before performing lookups.
    ///
    /// When enabled, the tool downloads the latest IEEE OUI database before
    /// processing any MAC addresses. This ensures the most current vendor
    /// information but requires network access and additional time.
    @Flag(name: .shortAndLong, help: "Update the local cache before looking up addresses")
    var update = false

    /// Restricts operation to local cache only, preventing network access.
    ///
    /// When enabled, the tool will only use the locally cached database and
    /// will fail if no cache is available. This is useful for offline environments
    /// or when consistent results are required.
    @Flag(name: .shortAndLong, help: "Only use local cache, fail if not available")
    var local = false

    /// Enables detailed debug output for troubleshooting and diagnostics.
    ///
    /// When enabled, the tool prints detailed information about cache operations,
    /// file locations, lookup timing, and error details. This is useful for
    /// troubleshooting issues or understanding the tool's behaviour.
    @Flag(name: .shortAndLong, help: "Enable debug output for troubleshooting")
    var debug = false

    /// Enables terse output that shows only the company name.
    ///
    /// When enabled, the tool outputs only the company name without the MAC address,
    /// company address, or other formatting. This is useful for scripting or when
    /// only the vendor name is needed.
    @Flag(name: .shortAndLong, help: "Show only company name in terse format")
    var terse = false

    /// MAC addresses to look up, accepting various common formats.
    ///
    /// The argument accepts one or more MAC addresses in any of the commonly
    /// used formats and automatically normalises them to a standard colon-separated
    /// format for processing. Invalid formats will cause the command to fail with
    /// a clear error message.
    ///
    /// The transformation process:
    /// 1. Removes all non-hexadecimal characters using regex
    /// 2. Validates the result contains exactly 12 hex digits
    /// 3. Converts to uppercase for consistency
    /// 4. Formats with colons for standard presentation
    ///
    /// Supported input formats include colon, hyphen, dot, and Cisco notation
    /// as well as raw hexadecimal strings.
    @Argument(
        help: "One or more MAC addresses to look up (e.g., 00:11:22:33:44:55)",
        transform: { address in
            // Normalize separators to colons
            let normalized =
                address
                .replacingOccurrences(of: "-", with: ":")
                .replacingOccurrences(of: ".", with: ":")
                .lowercased()

            // Split into components and handle different formats
            let components = normalized.components(separatedBy: ":")

            let hexComponents: [String]
            if components.count == 1 {
                // Raw hex string - must be exactly 12 characters
                let rawHex = components[0]
                guard rawHex.count == 12,
                    rawHex.rangeOfCharacter(
                        from: CharacterSet(charactersIn: "0123456789abcdef").inverted) == nil
                else {
                    throw ValidationError("Invalid MAC address format: \(address)")
                }
                // Split into 6 pairs
                hexComponents = stride(from: 0, to: rawHex.count, by: 2).map {
                    String(
                        rawHex[
                            rawHex.index(
                                rawHex.startIndex, offsetBy: $0)..<rawHex.index(
                                    rawHex.startIndex, offsetBy: $0 + 2)])
                }
            } else if components.count == 3 {
                // Cisco three-group format (e.g., "0011.2233.4455" -> "0011:2233:4455")
                var expandedComponents: [String] = []
                for component in components {
                    guard component.count == 4,
                        component.rangeOfCharacter(
                            from: CharacterSet(charactersIn: "0123456789abcdef").inverted) == nil
                    else {
                        throw ValidationError("Invalid MAC address format: \(address)")
                    }
                    // Split each 4-character component into two 2-character components
                    let first = String(component.prefix(2))
                    let second = String(component.suffix(2))
                    expandedComponents.append(first)
                    expandedComponents.append(second)
                }
                hexComponents = expandedComponents
            } else if components.count == 6 {
                // Components separated by colons - validate and pad with leading zeros if needed
                var validatedComponents: [String] = []
                for component in components {
                    guard component.count >= 1 && component.count <= 2,
                        component.rangeOfCharacter(
                            from: CharacterSet(charactersIn: "0123456789abcdef").inverted) == nil
                    else {
                        throw ValidationError("Invalid MAC address format: \(address)")
                    }
                    validatedComponents.append(component.count == 1 ? "0" + component : component)
                }
                hexComponents = validatedComponents
            } else {
                throw ValidationError("Invalid MAC address format: \(address)")
            }

            // Format as standard MAC address with colons and uppercase
            return hexComponents.map { $0.uppercased() }.joined(separator: ":")
        })
    var macAddresses: [String]

    /// Executes the main command logic for MAC address lookups.
    ///
    /// This method orchestrates the complete lookup process including cache
    /// management, database updates, and individual address processing. The
    /// execution flow adapts based on the provided command-line flags to
    /// support various operational modes.
    ///
    /// ## Execution Flow
    ///
    /// 1. Sets up cache directory structure
    /// 2. Determines if database update is needed based on flags and cache state
    /// 3. Updates or loads the local database as appropriate
    /// 4. Processes each MAC address with appropriate lookup strategy
    /// 5. Outputs results in a consistent format with error handling
    ///
    /// The method handles both single and batch address processing whilst
    /// providing detailed error messages and optional debug output.
    ///
    /// - Throws: `CleanExit.message` for user-facing error conditions.
    /// - Throws: `MACLookupError` for lookup-specific failures.
    /// - Throws: File system or network errors from underlying operations.
    func run() async throws {
        let fileManager = FileCacheManager.shared
        try await fileManager.ensureCacheDirectory()

        // Get cache file URL from the actor
        let cacheFileURL = await fileManager.getCacheFileURL()

        if debug {
            print("DEBUG: Cache directory: \(cacheFileURL.deletingLastPathComponent().path)")
            print("DEBUG: Arguments - update: \(update), local: \(local), debug: \(debug)")
        }

        // Initialize MACLookup with cache file
        let lookup = MACLookup(localDatabaseURL: cacheFileURL)

        // Check if we need to update the cache
        let (shouldUpdate, cacheExists) = await fileManager.shouldUpdateCache(
            forceUpdate: update, localOnly: local, debug: debug)

        if debug {
            print("DEBUG: Should update: \(shouldUpdate), Cache exists: \(cacheExists)")
        }

        if shouldUpdate {
            print("Updating MAC address database...")
            try await lookup.updateDatabase()
            if debug { print("DEBUG: Database update completed") }
        } else if local && !cacheExists {
            throw CleanExit.message("No local cache available and --local flag was specified")
        } else {
            if debug { print("DEBUG: Loading local database...") }
            // Load the local database
            do {
                try await lookup.loadLocalDatabase()
            } catch {
                if debug {
                    fputs("DEBUG: Failed to load local database: \(error)\n", stderr)
                }
                throw error
            }
        }

        // Process each MAC address
        for mac in macAddresses {
            if debug { print("DEBUG: Looking up MAC address: \(mac)") }
            do {
                let vendorInfo: MACVendorInfo
                if local {
                    // Use local-only lookup when --local flag is specified
                    vendorInfo = try await lookup.lookupLocal(mac)
                } else {
                    // Use normal lookup with fallback to online
                    vendorInfo = try await lookup.lookup(mac)
                }

                if terse {
                    print("\(vendorInfo.companyName)")
                } else {
                    print("\(mac): \(vendorInfo.companyName)")
                    if !vendorInfo.companyAddress.isEmpty {
                        print("   \(vendorInfo.companyAddress)")
                    }
                }

            } catch MACLookupError.notFound {
                if terse {
                    fputs("Vendor not found\n", stderr)
                } else {
                    fputs("\(mac): Vendor not found\n", stderr)
                }
            } catch MACLookupError.locallyAdministered {
                if terse {
                    fputs("Locally administered (no vendor information)\n", stderr)
                } else {
                    fputs("\(mac): Locally administered (no vendor information)\n", stderr)
                }
            } catch {
                if terse {
                    fputs("Error - \(error.localizedDescription)\n", stderr)
                } else {
                    fputs("\(mac): Error - \(error.localizedDescription)\n", stderr)
                }
            }
        }
    }
}
