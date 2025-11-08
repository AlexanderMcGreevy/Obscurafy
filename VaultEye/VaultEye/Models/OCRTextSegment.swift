import Foundation

struct OCRTextSegment: Identifiable, Hashable, Codable {
    let id: UUID
    let regionID: UUID
    let rawText: String
    let sanitizedText: String

    init(id: UUID = UUID(), regionID: UUID, rawText: String, sanitizedText: String) {
        self.id = id
        self.regionID = regionID
        self.rawText = rawText
        self.sanitizedText = sanitizedText
    }
}

enum TextSanitizer {
    static func sanitize(_ input: String) -> String {
        guard !input.isEmpty else { return input }

        // Replace sequences of digits with bullet characters except last four digits when length >= 4
        let pattern = "\\d{4,}"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        var sanitized = input

        if let regex = regex {
            let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: input) else { continue }
                let substring = input[range]
                let maskedCount = max(0, substring.count - 4)
                let mask = String(repeating: "•", count: maskedCount) + substring.suffix(4)
                sanitized.replaceSubrange(range, with: mask)
            }
        }

        // Mask email local parts
        let emailPattern = "([A-Z0-9._%+-]+)@([A-Z0-9.-]+\\.[A-Z]{2,})"
        if let emailRegex = try? NSRegularExpression(pattern: emailPattern, options: [.caseInsensitive]) {
            let matches = emailRegex.matches(in: sanitized, options: [], range: NSRange(location: 0, length: sanitized.utf16.count))
            for match in matches.reversed() {
                guard match.numberOfRanges == 3,
                      let fullRange = Range(match.range(at: 0), in: sanitized),
                      let domainRange = Range(match.range(at: 2), in: sanitized) else {
                    continue
                }

                let domain = sanitized[domainRange]
                let maskedEmail = "••••@\(domain)"
                sanitized.replaceSubrange(fullRange, with: maskedEmail)
            }
        }

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
