# UML Class Diagram for Swift MAC Lookup

This document provides a UML class diagram representation of the swift-mac-lookup structure.

## Overview

The Swift MAC Lookup project consists of a library for MAC address vendor lookup functionality and a command-line tool that uses this library. The project is structured as a Swift Package with multiple targets.

## Class Diagram

```mermaid
classDiagram
    %% Core Data Structures
    class MACAddress {
        +bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
        +description: String
        +oui: String
        +init(string: String) throws
        +hash(into hasher: inout Hasher)
        +encode(to encoder: Encoder) throws
        +init(from decoder: Decoder) throws
    }

    class MACVendorInfo {
        +prefix: String
        +companyName: String
        +companyAddress: String
        +countryCode: String
        +blockType: String
        +updated: String
        +isPrivate: Bool
        +rawData: [String: String]
        +init(prefix: String, companyName: String, ...)
        +from(vendorName: String) MACVendorInfo
        +encode(to encoder: Encoder) throws
        +init(from decoder: Decoder) throws
    }

    class MACLookupError {
        <<enumeration>>
        +invalidMACAddress(String)
        +notFound(String)
        +databaseError(Error)
        +networkError(Error)
        +apiError(String)
        +invalidConfiguration(String)
        +errorDescription: String?
    }

    %% Core Service Classes
    class MACLookup {
        <<actor>>
        -session: URLSession
        -localDatabaseURL: URL
        -onlineURL: URL
        -localDatabase: [String: MACVendorInfo]
        -decoder: JSONDecoder
        +lastUpdated: Date?
        +init(localDatabaseURL: URL?, onlineURL: URL, session: URLSession?)
        +loadLocalDatabase() throws
        +saveLocalDatabase() async throws
        +lookupLocal(String) throws MACVendorInfo
        +lookupOnline(String, updateLocal: Bool) async throws MACVendorInfo
        +lookup(String) async throws MACVendorInfo
        +lookup(MACAddress) async throws MACVendorInfo
        +updateDatabase(from: URL?) async throws
        -getLocalVendorInfo(for: MACAddress) MACVendorInfo?
    }

    class OUIParser {
        <<utility>>
        +parse(Data) throws [String: String]
    }

    %% Command Line Tool
    class HWAddrLookup {
        <<struct>>
        +update: Bool
        +local: Bool
        +macAddresses: [String]
        +run() async throws
    }

    class FileCacheManager {
        <<actor>>
        +shared: FileCacheManager
        -fileManager: FileManager
        -cacheFileName: String
        -cacheDirectory: URL
        +getCacheFileURL() URL
        +ensureCacheDirectory() throws
        +fileExists(at: URL) Bool
        +shouldUpdateCache(forceUpdate: Bool, localOnly: Bool) async (Bool, Bool)
    }

    %% Test Support
    class MockURLProtocol {
        -queue: DispatchQueue
        -requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
        +canInit(with: URLRequest) Bool
        +canonicalRequest(for: URLRequest) URLRequest
        +startLoading()
        +stopLoading()
        +reset()
        +createMockURLSession() URLSession
    }

    %% Protocol Conformances and Relationships
    MACAddress --|> Hashable
    MACAddress --|> Codable
    MACAddress --|> CustomStringConvertible
    MACAddress --|> Sendable

    MACVendorInfo --|> Codable
    MACVendorInfo --|> Sendable

    MACLookupError --|> Error
    MACLookupError --|> LocalizedError
    MACLookupError --|> Sendable

    HWAddrLookup --|> AsyncParsableCommand

    MockURLProtocol --|> URLProtocol

    %% Usage Relationships
    MACLookup ..> MACAddress : uses
    MACLookup ..> MACVendorInfo : creates/manages
    MACLookup ..> MACLookupError : throws
    MACLookup ..> OUIParser : uses
    MACLookup --> URLSession : contains

    HWAddrLookup ..> MACLookup : uses
    HWAddrLookup ..> FileCacheManager : uses
    HWAddrLookup ..> MACLookupError : handles

    OUIParser ..> MACLookupError : throws
    OUIParser ..> MACVendorInfo : creates

    FileCacheManager --> FileManager : contains

    %% Constants and Globals
    class Constants {
        <<utility>>
        +ieeeOUIURL: URL
    }

    MACLookup ..> Constants : uses
```

## Package Structure

```
MACLookup Package
├── MACLookup (Library Target)
│   ├── MACAddress
│   ├── MACVendorInfo
│   ├── MACLookupError
│   ├── MACLookup (Actor)
│   └── OUIParser
├── hwaddrlookup (Executable Target)
│   ├── HWAddrLookup
│   └── FileCacheManager
└── MACLookupTests (Test Target)
    └── MockURLProtocol
```

## Key Design Patterns

### 1. Actor Pattern
- **MACLookup**: Uses Swift's actor pattern to ensure thread-safe access to the local database and network operations
- **FileCacheManager**: Manages file system operations in a thread-safe manner

### 2. Error Handling
- **MACLookupError**: Comprehensive error enumeration covering validation, network, and database errors
- Proper error propagation through throwing functions

### 3. Protocol-Oriented Design
- **Codable**: Both `MACAddress` and `MACVendorInfo` conform for JSON serialization
- **Sendable**: All data types are Sendable for safe concurrent usage
- **CustomStringConvertible**: `MACAddress` provides readable string representation

### 4. Separation of Concerns
- **OUIParser**: Dedicated utility for parsing IEEE OUI format
- **FileCacheManager**: Isolated file management logic
- **MockURLProtocol**: Testing infrastructure separated from main code

## Data Flow

1. **Input**: MAC address string → `MACAddress.init(string:)`
2. **Local Lookup**: `MACLookup.lookupLocal()` → checks local database
3. **Online Lookup**: `MACLookup.lookupOnline()` → downloads and parses OUI data via `OUIParser`
4. **Cache Management**: `FileCacheManager` handles local file operations
5. **Output**: `MACVendorInfo` with vendor details

## Dependencies

- **Foundation**: Core framework functionality
- **ArgumentParser**: Command-line interface (external dependency)
- **FoundationNetworking**: Network operations (Linux compatibility)

## Concurrency Model

The project leverages Swift's modern concurrency features:
- **Actors**: `MACLookup` and `FileCacheManager` ensure thread safety
- **Async/Await**: Network operations and file I/O use async patterns
- **Sendable**: All data types are safe for concurrent access

This design provides a robust, thread-safe, and efficient MAC address lookup system with both library and command-line interfaces.