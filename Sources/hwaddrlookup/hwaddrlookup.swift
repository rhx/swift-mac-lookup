import Foundation
import ArgumentParser
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
    
    func shouldUpdateCache(forceUpdate: Bool, localOnly: Bool) async -> (shouldUpdate: Bool, cacheExists: Bool) {
        let cacheFile = getCacheFileURL()
        let exists = fileExists(at: cacheFile)
        
        if forceUpdate {
            return (true, exists)
        } else if !exists && localOnly {
            return (false, false)
        } else if !exists {
            return (true, false)
        }
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
    
    @Argument(help: "One or more MAC addresses to look up (e.g., 00:11:22:33:44:55)", transform: { address in
        // Remove common separators and convert to uppercase
        let cleaned = address.replacingOccurrences(of: "[^0-9A-Fa-f]", with: "", options: .regularExpression).uppercased()
        
        // Validate the cleaned MAC address format (6 bytes = 12 hex digits)
        guard cleaned.count == 12,
              cleaned.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789ABCDEF").inverted) == nil else {
            throw ValidationError("Invalid MAC address format: \(address)")
        }
        
        // Format as MAC address with colons
        return String(cleaned.enumerated().map { $0 > 0 && $0 % 2 == 0 ? [":", $1] : [$1] }.joined())
    })
    var macAddresses: [String]
    
    func run() async throws {
        let fileManager = FileCacheManager.shared
        try await fileManager.ensureCacheDirectory()
        
        // Get cache file URL from the actor
        let cacheFileURL = await fileManager.getCacheFileURL()
        
        // Initialize MACLookup with cache file
        let lookup = MACLookup(localDatabaseURL: cacheFileURL)
        
        // Check if we need to update the cache
        let (shouldUpdate, cacheExists) = await fileManager.shouldUpdateCache(forceUpdate: update, localOnly: local)
        
        if shouldUpdate {
            print("Updating MAC address database...")
            try await lookup.updateDatabase()
        } else if local && !cacheExists {
            throw CleanExit.message("No local cache available and --local flag was specified")
        } else {
            // Load the local database
            try await lookup.loadLocalDatabase()
        }
        
        // Process each MAC address
        for mac in macAddresses {
            do {
                let vendorInfo = try await lookup.lookup(mac)
                print("\(mac): \(vendorInfo.companyName)")
                if !vendorInfo.companyAddress.isEmpty {
                    print("   \(vendorInfo.companyAddress)")
                }
            } catch MACLookupError.notFound {
                print("\(mac): Vendor not found")
            } catch {
                print("\(mac): Error - \(error.localizedDescription)")
            }
        }
    }
}
