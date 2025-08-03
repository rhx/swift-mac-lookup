import Foundation

/// A parser for the IEEE OUI text format.
///
/// `OUIParser` handles the parsing of IEEE OUI database text files into structured
/// data suitable for MAC address vendor lookups. The parser is designed to handle
/// the specific format used by the IEEE Registration Authority whilst being robust
/// against formatting variations.
///
/// ## Input Format
///
/// The IEEE OUI database uses a specific text format with entries like:
/// ```
/// 00-00-0C   (hex)    Cisco Systems, Inc
///                     170 West Tasman Drive
///                     San Jose CA 95134
///                     US
/// ```
///
/// ## Parser Behaviour
///
/// The parser processes the text line by line, identifying OUI entries by their
/// hex format and handling multi-line vendor information correctly.
struct OUIParser {
    /// Parses IEEE OUI text data into a structured format.
    ///
    /// Processes the IEEE OUI database text format and extracts vendor information
    /// for each registered MAC address prefix. The parser handles the multi-line
    /// format where vendor names may span multiple lines and filters out comments
    /// and empty lines.
    ///
    /// The parsing process:
    /// 1. Decodes the data as UTF-8 text
    /// 2. Processes each line to identify OUI entries
    /// 3. Extracts MAC prefixes in hex format (e.g., "00-11-22")
    /// 4. Collects associated vendor names, including multi-line entries
    /// 5. Returns a dictionary mapping normalised OUI strings to vendor names
    ///
    /// - Parameter data: The IEEE OUI database text data to parse.
    /// - Returns: A dictionary mapping 6-character hex OUI strings to vendor names.
    /// - Throws: `MACLookupError.apiError` if the data cannot be decoded as UTF-8.
    static func parse(_ data: Data) throws -> [String: String] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw MACLookupError.apiError("Failed to decode OUI data as UTF-8")
        }

        var result: [String: String] = [:]
        var currentOUI: String? = nil
        var vendorName: String = ""

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            // Check for OUI line (starts with a MAC prefix)
            let components = trimmedLine.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            if components.count >= 2,
                let firstComponent = components.first,
                firstComponent.range(
                    of: "^([0-9A-F]{2}-){2}[0-9A-F]{2}$",
                    options: [.regularExpression, .caseInsensitive]) != nil
            {

                // Save the previous entry if we have one
                if let oui = currentOUI, !vendorName.isEmpty {
                    result[oui] = vendorName
                }

                // Start a new entry
                currentOUI = firstComponent.replacingOccurrences(of: "-", with: "").uppercased()
                let rawVendorName = components.dropFirst().joined(separator: " ")

                // Clean up vendor name by removing format artifacts
                vendorName = cleanVendorName(rawVendorName)
            }
            // Skip address lines (indented or continuation lines) - we only want the company name
        }

        // Add the last entry
        if let oui = currentOUI, !vendorName.isEmpty {
            result[oui] = vendorName
        }

        return result
    }

    /// Cleans up vendor names by removing format artifacts from the OUI data.
    ///
    /// The IEEE OUI database includes format markers like "(hex)" and OUI codes
    /// that should not be part of the clean company name. This method removes
    /// these artifacts to provide clean vendor names.
    ///
    /// - Parameter rawVendorName: The raw vendor name from the OUI file.
    /// - Returns: A cleaned vendor name with format artifacts removed.
    private static func cleanVendorName(_ rawVendorName: String) -> String {
        var cleaned = rawVendorName

        // Remove "(hex)" marker
        cleaned = cleaned.replacingOccurrences(
            of: "\\s*\\(hex\\)\\s*",
            with: " ",
            options: .regularExpression
        )

        // Remove "(base 16)" marker if present
        cleaned = cleaned.replacingOccurrences(
            of: "\\s*\\(base 16\\)\\s*",
            with: " ",
            options: .regularExpression
        )

        // Remove OUI code patterns (6 hex digits followed by optional text)
        cleaned = cleaned.replacingOccurrences(
            of: "\\s+[0-9A-F]{6}\\s.*$",
            with: "",
            options: .regularExpression
        )

        // Clean up extra whitespace
        cleaned = cleaned.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)

        return cleaned
    }
}

// MARK: - MACVendorInfo Extension

extension MACVendorInfo {
    /// Creates a new `MACVendorInfo` instance from a vendor name.
    ///
    /// Convenience factory method for creating vendor information records when
    /// only the vendor name is available from the parsed OUI data. Other fields
    /// are populated with appropriate defaults.
    ///
    /// This method is primarily used internally by the OUI parser to create
    /// vendor records from the IEEE database text format.
    ///
    /// - Parameter vendorName: The name of the vendor organisation.
    /// - Returns: A new `MACVendorInfo` instance with default values for optional fields.
    static func from(vendorName: String) -> MACVendorInfo {
        return MACVendorInfo(
            prefix: "",
            companyName: vendorName,
            companyAddress: "",
            countryCode: "",
            blockType: "MA-L",
            updated: "",
            isPrivate: false
        )
    }
}
