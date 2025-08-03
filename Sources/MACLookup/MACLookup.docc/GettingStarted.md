# Getting Started

Learn the basics of looking up MAC address vendor information.

## Overview

This guide covers installation, basic usage patterns, and common scenarios for MAC address vendor lookups.

## Installation

Add MACLookup to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/rhx/swift-mac-lookup.git", branch: "main")
]
```

## Basic Lookup

Perform a simple vendor lookup:

```swift
import MACLookup

let resolver = MACLookup()
let vendorInfo = try await resolver.lookup("00:11:22:33:44:55")
print("Vendor: \(vendorInfo.companyName)")
```

## Working with MAC Addresses

Parse and validate MAC addresses:

```swift
let mac = try MACAddress(string: "00:11:22:33:44:55")
print("OUI: \(mac.oui)")
print("Formatted: \(mac.description)")
```

## Error Handling

Handle common failure cases:

```swift
do {
    let vendor = try await resolver.lookup(macAddress)
} catch MACLookupError.notFound {
    print("Vendor not found")
} catch MACLookupError.invalidMACAddress(let address) {
    print("Invalid MAC: \(address)")
}
```

## Database Management

The IEEE database is downloaded automatically on first use. For manual control:

```swift
// Force database update
try await resolver.updateDatabase()

// Local-only lookup
let vendor = try resolver.lookupLocal("00:11:22:33:44:55")
```
