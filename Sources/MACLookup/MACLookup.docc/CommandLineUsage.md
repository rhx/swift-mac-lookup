# Command-Line Usage

Use the `hwaddrlookup` tool for terminal-based MAC address lookups.

## Overview

The `hwaddrlookup` command-line tool allows you to look up vendors for MAC addresses.
It allows you pass multiple mac addresses for batch processing and integration with
shell scripts and system administration workflows.

## Basic Commands

### Single Address

```sh
hwaddrlookup 00:11:22:33:44:55
```

### Multiple Addresses

```sh
hwaddrlookup 00:11:22:33:44:55 aa:bb:cc:dd:ee:ff
```

## Options

### Update Database

Force a database update before lookup:

```sh
hwaddrlookup --update 00:11:22:33:44:55
```

### Local-Only Mode

Use cached database only, avoiding network requests:

```sh
hwaddrlookup --local 00:11:22:33:44:55
```

### Debug Output

Enable detailed logging:

```sh
hwaddrlookup --debug 00:11:22:33:44:55
```

## Input Formats

The tool accepts various MAC address formats:

- `00:11:22:33:44:55` (colon)
- `00-11-22-33-44-55` (hyphen)
- `00.11.22.33.44.55` (dot)
- `0011.2233.4455` (Cisco)
- `001122334455` (raw)

## Batch Processing

Process multiple addresses from files, avoiding network lookups:

```sh
cat addresses.txt -print0 | xargs -0 hwaddrlookup --local
```

## Error Output

Common error scenarios:

- Invalid format: `Invalid MAC address format: xyz`
- Not found: `Vendor not found`
- Locally administered: `Locally administered (no vendor information)`
