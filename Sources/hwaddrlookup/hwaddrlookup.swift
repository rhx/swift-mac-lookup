import ArgumentParser
import Foundation
import MACLookup

@available(macOS 12.0, *)
actor FileCacheManager {
    static let shared = FileCacheManager()
    private let fileManager = FileManager.default
    private let cacheFileName = "mac-vendors.json"

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.github.rhx.maclookup")
    }

    func getCacheFileURL() -> URL {
        cacheDirectory.appendingPathComponent(cacheFileName)
    }

    func ensureCacheDirectory() throws {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func shouldUpdateCache(forceUpdate: Bool, localOnly: Bool, debug: Bool = false) async -> (
        shouldUpdate: Bool, cacheExists: Bool
    ) {
        let cacheFile = getCacheFileURL()
        let exists = fileExists(at: cacheFile)

        if debug {
            print("DEBUG: Cache file path: \(cacheFile.path)")
            print("DEBUG: Cache file exists: \(exists)")
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
                    print("DEBUG: Error reading cache file attributes: \(error)")
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

@available(macOS 12.0, *)
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

    @Flag(name: .shortAndLong, help: "Update the local cache before looking up addresses")
    var update = false

    @Flag(name: .shortAndLong, help: "Only use local cache, fail if not available")
    var local = false

    @Flag(name: .shortAndLong, help: "Enable debug output for troubleshooting")
    var debug = false

    @Argument(
        help: "One or more MAC addresses to look up (e.g., 00:11:22:33:44:55)",
        transform: { address in
            // Remove common separators and convert to uppercase
            let cleaned = address.replacingOccurrences(
                of: "[^0-9A-Fa-f]", with: "", options: .regularExpression
            ).uppercased()

            // Validate the cleaned MAC address format (6 bytes = 12 hex digits)
            guard cleaned.count == 12,
                cleaned.rangeOfCharacter(
                    from: CharacterSet(charactersIn: "0123456789ABCDEF").inverted) == nil
            else {
                throw ValidationError("Invalid MAC address format: \(address)")
            }

            // Format as MAC address with colons
            return String(
                cleaned.enumerated().map { $0 > 0 && $0 % 2 == 0 ? [":", $1] : [$1] }.joined())
        })
    var macAddresses: [String]

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
            if debug { print("DEBUG: Starting database update...") }
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
                if debug { print("DEBUG: Local database loaded successfully") }
            } catch {
                if debug { print("DEBUG: Failed to load local database: \(error)") }
                throw error
            }
        }

        // Process each MAC address
        for mac in macAddresses {
            if debug { print("DEBUG: Looking up MAC address: \(mac)") }
            do {
                let vendorInfo = try await lookup.lookup(mac)
                print("\(mac): \(vendorInfo.companyName)")
                if !vendorInfo.companyAddress.isEmpty {
                    print("   \(vendorInfo.companyAddress)")
                }
                if debug {
                    print(
                        "DEBUG: Found vendor info - Prefix: \(vendorInfo.prefix), Type: \(vendorInfo.blockType)"
                    )
                }
            } catch MACLookupError.notFound {
                print("\(mac): Vendor not found")
                if debug { print("DEBUG: No vendor found for MAC \(mac)") }
            } catch {
                print("\(mac): Error - \(error.localizedDescription)")
                if debug { print("DEBUG: Lookup error for \(mac): \(error)") }
            }
        }
    }
}
