import Foundation

public enum AlphabetIndexing {
    public static let defaultIndexKeys: [String] =
        (65...90).compactMap { UnicodeScalar($0).map(String.init) } + ["#"]

    public static func normalizedForAlphabetIndex(_ text: String) -> String {
        let latin = text.applyingTransform(.toLatin, reverse: false) ?? text
        let folded = latin.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return folded.uppercased()
    }

    public static func sectionKey(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "#" }
        let normalized = normalizedForAlphabetIndex(trimmed)
        guard let scalar = normalized.unicodeScalars.first else { return "#" }
        let value = scalar.value
        if (65...90).contains(value) {
            return String(scalar)
        }
        return "#"
    }
}
