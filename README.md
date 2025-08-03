# MACLookup

A Swift package for looking up vendor information from MAC addresses using the IEEE OUI (Organisationally Unique Identifier) database.

## Features

- Cross-platform support (macOS, iOS, tvOS, watchOS, Linux)
- Modern Swift concurrency with async/await and actors
- Local database caching for offline operation
- Flexible MAC address format support
- Command-line tool for terminal usage
- Thread-safe operations

## Requirements

- Swift 6.1+
- Linux / macOS 13.0+ / iOS 17.0+ / tvOS 17.0+ / watchOS 8.0+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rhx/swift-mac-lookup.git", branch: "main")
]
```

### Xcode

1. File → Add Package Dependencies
2. Enter: `https://github.com/rhx/swift-mac-lookup.git`

## Quick Start

### Library Usage

```swift
import MACLookup

let resolver = MACLookup()

do {
    let vendorInfo = try await lookup.lookup("00:11:22:33:44:55")
    print("Vendor: \(vendorInfo.companyName)")
    print("Address: \(vendorInfo.companyAddress)")
} catch {
    print("Lookup failed: \(error)")
}
```

### MAC Address Parsing

```swift
let mac = try MACAddress(string: "00:11:22:33:44:55")
print("OUI: \(mac.oui)")
print("Locally administered: \(mac.isLocallyAdministered)")
```

### Command-Line Tool

```bash
# Basic lookup
hwaddrlookup 00:11:22:33:44:55

# Multiple addresses
hwaddrlookup 00:11:22:33:44:55 aa:bb:cc:dd:ee:ff

# Update database first
hwaddrlookup --update 00:11:22:33:44:55

# Local-only mode
hwaddrlookup --local 00:11:22:33:44:55

# Terse output (company name only)
hwaddrlookup --terse 00:11:22:33:44:55

# Multiple options
hwaddrlookup --terse --local 8:b6:1f:d0:f5:d8
```

## Supported MAC Address Formats

- `00:11:22:33:44:55` (colon-separated)
- `00-11-22-33-44-55` (hyphen-separated)
- `00.11.22.33.44.55` (dot-separated)
- `0011.2233.4455` (Cisco format)
- `001122334455` (no separators)
- `8:b6:1f:0:f5:d8` (missing leading zeros)

## API Overview

### Core Types

- **`MACAddress`**: Represents and validates MAC addresses
- **`MACVendorInfo`**: Contains vendor information
- **`MACLookup`**: Actor for performing lookups
- **`MACLookupError`**: Error types for failure cases

### Key Methods

- `lookup(_:)`: Look up with online fallback
- `lookupLocal(_:)`: Local database only
- `updateDatabase()`: Download latest IEEE database
- `loadLocalDatabase()`: Load cached database

## Error Handling

```swift
do {
    let vendor = try await lookup.lookup(macAddress)
} catch MACLookupError.notFound {
    print("Vendor not found")
} catch MACLookupError.locallyAdministered {
    print("Locally administered address")
} catch MACLookupError.invalidMACAddress(let addr) {
    print("Invalid format: \(addr)")
}
```

## Database Management

The package automatically downloads and caches the IEEE OUI database (~2MB) on first use. The database is stored locally and can be updated manually:

```swift
try await lookup.updateDatabase()
```

## Testing

```bash
swift test
```

## Documentation

Full API documentation is available through DocC. Build documentation in Xcode:

Product → Build Documentation

## Contributing

Contributions welcome. Please ensure tests pass and follow Swift coding conventions.

## Licence

See LICENCE file for details.

## Acknowledgements

- IEEE Registration Authority for the OUI database
- Swift community for tooling and conventions
