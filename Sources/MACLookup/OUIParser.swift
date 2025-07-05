import Foundation

/// A parser for the IEEE OUI text format.
struct OUIParser {
    /// Parses the OUI text data into a dictionary of MAC address prefixes to vendor information.
    /// - Parameter data: The OUI text data to parse.
    /// - Returns: A dictionary mapping MAC address prefixes to vendor information.
    /// - Throws: An error if the data cannot be parsed.
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
               firstComponent.range(of: "^([0-9A-F]{2}-){2}[0-9A-F]{2}$", 
                                 options: [.regularExpression, .caseInsensitive]) != nil {
                
                // Save the previous entry if we have one
                if let oui = currentOUI, !vendorName.isEmpty {
                    result[oui] = vendorName
                }
                
                // Start a new entry
                currentOUI = firstComponent.replacingOccurrences(of: "-", with: "").uppercased()
                vendorName = components.dropFirst().joined(separator: " ")
            } else if !trimmedLine.hasPrefix("\t") && !vendorName.isEmpty {
                // Continue the vendor name on the next line if it's not indented
                vendorName += " " + trimmedLine
            }
        }
        
        // Add the last entry
        if let oui = currentOUI, !vendorName.isEmpty {
            result[oui] = vendorName
        }
        
        return result
    }
}

// MARK: - MACVendorInfo Extension

extension MACVendorInfo {
    /// Creates a new `MACVendorInfo` instance from a vendor name.
    /// - Parameter vendorName: The name of the vendor.
    /// - Returns: A new `MACVendorInfo` instance.
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
