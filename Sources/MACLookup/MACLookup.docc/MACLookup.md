# ``MACLookup``

Library for looking up vendor information from MAC addresses
using the IEEE OUI database.

## Overview

The `MACLookup` module provides a Swift API and a `hwaddrlookup`
command-line tool for identifying network device manufacturers
from their MAC addresses. The package uses the IEEE
Organisationally Unique Identifier (OUI) database to provide
vendor information.

Key capabilities include cross-platform support, local caching
for reducing network requests and offline operation, permissive
input format handling, and thread-safe concurrent access through
Swift actors.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:CommandLineUsage>

### Core Types

- ``MACAddress``
- ``MACVendorInfo``
- ``MACLookup``

### Error Handling

- ``MACLookupError``

### Parsing and Utilities

- ``OUIParser``
- ``ieeeOUIURL``

### Advanced Topics

- <doc:DatabaseManagement>
- <doc:ErrorHandling>