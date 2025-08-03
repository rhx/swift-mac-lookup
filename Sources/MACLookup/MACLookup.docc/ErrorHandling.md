# Error Handling

Handle failures gracefully in MAC address lookups.

## Overview

MACLookup provides specific error types for different failure scenarios, enabling appropriate error handling and user feedback.

## Error Types

### Invalid MAC Address

Thrown when MAC address format is invalid:

```swift
catch MACLookupError.invalidMACAddress(let address) {
    print("Invalid format: \(address)")
}
```

### MAC Address Not Found

Vendor not in database:

```swift
catch MACLookupError.notFound(let address) {
    print("No vendor found for: \(address)")
}
```

### Locally Administered Address

Address has no vendor (locally administered):

```swift
catch MACLookupError.locallyAdministered(let address) {
    print("Locally administered: \(address)")
}
```

### Network Errors

Network request failures:

```swift
catch MACLookupError.networkError(let error) {
    print("Network failed: \(error.localizedDescription)")
}
```

### Database Errors

Local database issues:

```swift
catch MACLookupError.databaseError(let error) {
    print("Database error: \(error.localizedDescription)")
}
```

## Error Recovery

### Retry Logic

Implement retry for network failures:

```swift
func lookupWithRetry(_ address: String, using resolver: MACLookup, retries: Int = 3) async throws -> MACVendorInfo {
    for attempt in 0..<retries {
        do {
            return try await resolver.lookup(address)
        } catch MACLookupError.networkError {
            if attempt == retries - 1 { throw }
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    throw MACLookupError.networkError(NSError())
}
```

### Fallback Strategies

Use local cache when online fails:

```swift
func robustLookup(_ address: String, using resolver: MACLookup) async throws -> MACVendorInfo {
    do {
        return try await resolver.lookup(address)
    } catch MACLookupError.networkError {
        return try resolver.lookupLocal(address)
    }
}
```

## Validation

Pre-validate MAC addresses:

```swift
func validateAndLookup(_ addressString: String, using resolver: MACLookup) async -> Result<MACVendorInfo, Error> {
    do {
        let address = try MACAddress(string: addressString)
        if address.isLocallyAdministered {
            return .failure(MACLookupError.locallyAdministered(addressString))
        }
        let vendor = try await resolver.lookup(address)
        return .success(vendor)
    } catch {
        return .failure(error)
    }
}
```
