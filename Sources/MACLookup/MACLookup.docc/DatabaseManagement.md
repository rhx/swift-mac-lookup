# Database Management

Control local database caching and updates.

## Overview

MACLookup maintains a local cache of the IEEE OUI database for fast, offline lookups. Understanding cache behaviour helps optimise performance and manage storage.

## Automatic Caching

The database is downloaded automatically on first lookup
or if a MAC address could not be found in the cached database:

```swift
let resolver = MACLookup()
// Database downloaded here if not cached
let vendor = try await resolver.lookup("00:11:22:33:44:55")
```

## Manual Updates

Force database updates when needed:

```swift
try await resolver.updateDatabase()
```

Check last update time:

```swift
if let lastUpdated = await resolver.lastUpdated {
    print("Database last updated: \(lastUpdated)")
}
```

## Local-Only Operation

For offline environments:

```swift
// Load cached database
try await resolver.loadLocalDatabase()

// Perform offline lookup
let vendor = try resolver.lookupLocal("00:11:22:33:44:55")
```

## Custom Locations

Specify custom database locations:

```swift
let customURL = URL(fileURLWithPath: "/path/to/database.json")
let resolver = MACLookup(localDatabaseURL: customURL)
```

## Database Size and Performance

- Database size: ~2MB compressed
- Memory usage: ~10MB when loaded
- Lookup time: <1ms for local cache
- Download time: varies by connection (~30 seconds typical)

## Storage Location

Default storage locations by platform:

- **macOS**: `~/Library/Application Support/[bundle-id]/macaddress-db.json`
- **Linux**: `~/.local/share/[bundle-id]/macaddress-db.json`
- **iOS/tvOS/watchOS**: App container application support directory