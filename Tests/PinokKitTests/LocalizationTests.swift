import Foundation
import Testing
@testable import PinokKit

/// Helpers for the localization tests (kept here so TestSupport.swift is untouched).
enum L10nScan {
    /// `Sources/PinokKit`, found from this file's path.
    static var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PinokKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("Sources/PinokKit")
    }

    static func swiftFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: sourcesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func matches(_ pattern: String, in text: String, group: Int = 1) -> [String] {
        let re = try! NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            unescape(ns.substring(with: $0.range(at: group)))
        }
    }

    /// Swift literal → runtime string (only the escapes that can show up here).
    static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    /// Literals passed to `t("...")` (also `t("...", args)`). `d.set(` etc. are not matched.
    static let tCall = #"(?<![A-Za-z0-9_.])t\(\s*"((?:[^"\\]|\\.)*)""#

    /// `title:` / `caption:` / `detail:` literals of `ReminderTemplate(...)` entries.
    static func templateStrings(in text: String) -> [String] {
        text.components(separatedBy: "ReminderTemplate(id:").dropFirst().flatMap { chunk -> [String] in
            let entry = chunk.components(separatedBy: "animation:").first ?? chunk
            return matches(#"(?:title|caption|detail):\s*"((?:[^"\\]|\\.)*)""#, in: entry)
        }
    }

    /// Format specifiers in order: `%@`, `%ld`, `%d`, `%%`, …
    static func specifiers(_ s: String) -> [String] {
        matches(#"(%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?[@dDiuUxXoOfFeEgGcCsSpaA%])"#, in: s)
    }

    static func hasCyrillic(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }

    static func hasLatinLetter(_ s: String) -> Bool {
        s.unicodeScalars.contains { ("a"..."z").contains($0) || ("A"..."Z").contains($0) }
    }
}

@Suite("Localization", .serialized)
struct LocalizationTests {

    // MARK: Coverage

    @Test func everyTCallLiteralHasRussianTranslation() throws {
        var missing: [String] = []
        var found = 0
        for file in try L10nScan.swiftFiles() where file.lastPathComponent != "Localization.swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for key in L10nScan.matches(L10nScan.tCall, in: text) {
                found += 1
                if L10n.ru[key] == nil { missing.append("\(file.lastPathComponent): \"\(key)\"") }
            }
        }
        #expect(found > 50, "The scan found too few t(\"…\") calls (\(found)) — the regex or path is broken")
        let unique = Array(Set(missing)).sorted()
        #expect(unique.isEmpty, "Missing Russian translations for t() keys:\n\(unique.joined(separator: "\n"))")
    }

    @Test func everyReminderTemplateTextHasRussianTranslation() throws {
        let text = try String(contentsOf: L10nScan.sourcesDir.appendingPathComponent("Reminders.swift"), encoding: .utf8)
        let scanned = L10nScan.templateStrings(in: text)
        #expect(scanned.count == ReminderLibrary.all.count * 3,
                "Expected title+caption+detail for every template, scanned \(scanned.count)")

        // Runtime values too, so the scan cannot silently drift from the real data.
        let runtime = ReminderLibrary.all.flatMap { [$0.title, $0.caption, $0.detail] }
        #expect(Set(scanned) == Set(runtime))

        let missing = Set(scanned + runtime).filter { L10n.ru[$0] == nil }.sorted()
        #expect(missing.isEmpty, "Missing Russian translations for templates:\n\(missing.joined(separator: "\n"))")
    }

    @Test func everyDefaultBreakTipHasRussianTranslation() {
        #expect(!BreakTips.defaults.isEmpty)
        let missing = BreakTips.defaults.filter { L10n.ru[$0] == nil }
        #expect(missing.isEmpty, "Missing Russian translations for break tips:\n\(missing.joined(separator: "\n"))")
    }

    @Test func melodyTitlesHaveRussianTranslation() {
        let missing = Melodies.all.map(\.title).filter { L10n.ru[$0] == nil }
        #expect(missing.isEmpty, "Missing Russian translations for melody titles: \(missing)")
    }

    // MARK: Format safety

    @Test func russianValuesKeepFormatSpecifiersInOrder() {
        var bad: [String] = []
        for (key, value) in L10n.ru {
            let k = L10nScan.specifiers(key), v = L10nScan.specifiers(value)
            if k != v { bad.append("\"\(key)\" \(k) → \"\(value)\" \(v)") }
        }
        #expect(bad.isEmpty, "Format specifier mismatch:\n\(bad.sorted().joined(separator: "\n"))")
    }

    @Test func specifierParserWorks() {
        #expect(L10nScan.specifiers("a %@ b %ld c %d %%") == ["%@", "%ld", "%d", "%%"])
        #expect(L10nScan.specifiers("no specifiers") == [])
    }

    // MARK: Sanity

    @Test func russianValuesAreNotEmpty() {
        let empty = L10n.ru.filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.keys.sorted()
        #expect(empty.isEmpty, "Empty Russian values: \(empty)")
    }

    @Test func keysAreEnglish() {
        let cyrillicKeys = L10n.ru.keys.filter(L10nScan.hasCyrillic).sorted()
        #expect(cyrillicKeys.isEmpty, "Keys with Cyrillic (key must be English): \(cyrillicKeys)")
        let emptyKeys = L10n.ru.keys.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        #expect(emptyKeys.isEmpty)
    }

    @Test func valuesAreNotKeys() {
        // A value that is itself a key means the pair was probably swapped or copy-pasted.
        let swapped = L10n.ru.filter { $0.key != $0.value && L10n.ru[$0.value] != nil }.map(\.key).sorted()
        #expect(swapped.isEmpty, "Values that are also keys: \(swapped)")
    }

    @Test func valuesAreTranslated() {
        // Every key with English words must get a value with Russian letters (not left in English).
        let untranslated = L10n.ru
            .filter { L10nScan.hasLatinLetter($0.key) && !L10nScan.hasCyrillic($0.value) }
            .map { "\"\($0.key)\" → \"\($0.value)\"" }.sorted()
        #expect(untranslated.isEmpty, "Values without Cyrillic:\n\(untranslated.joined(separator: "\n"))")
    }

    @Test func noStrayWhitespace() {
        let bad = L10n.ru.filter { k, v in
            k != k.trimmingCharacters(in: .whitespacesAndNewlines) || v != v.trimmingCharacters(in: .whitespacesAndNewlines)
        }.keys.sorted()
        #expect(bad.isEmpty, "Leading/trailing whitespace: \(bad)")
    }

    // MARK: t(_:)

    @Test func tReturnsEnglishWhenNotRussian() {
        defer { L10n.isRussian = false }
        L10n.isRussian = false
        #expect(t("Pause") == "Pause")
        #expect(t("Sit up straight") == "Sit up straight")
        #expect(t("None") == "None")
    }

    @Test func tReturnsRussianWhenRussian() {
        defer { L10n.isRussian = false }
        L10n.isRussian = true
        #expect(t("Pause") == "Пауза")
        #expect(t("Sit up straight") == "Выпрямись")
        #expect(t("None") == "Без звука")
        for (key, value) in L10n.ru { #expect(t(key) == value) }
    }

    @Test(arguments: [false, true])
    func tReturnsUnknownStringsUnchanged(russian: Bool) {
        defer { L10n.isRussian = false }
        L10n.isRussian = russian
        #expect(t("Some unknown string 12345") == "Some unknown string 12345")
        #expect(t("") == "")
        #expect(t("My custom reminder") == "My custom reminder")
    }

    @Test func tFormatsArgumentsInEnglish() {
        defer { L10n.isRussian = false }
        L10n.isRussian = false
        #expect(t("%ld min", 5) == "5 min")
        #expect(t("Break in %@", "0:45") == "Break in 0:45")
        #expect(t("%@ — in %@", "Water", "5:00") == "Water — in 5:00")
        #expect(t("Today: posture %ld · tongue %ld · breaks %ld", 1, 2, 3) == "Today: posture 1 · tongue 2 · breaks 3")
    }

    @Test func tFormatsArgumentsInRussian() {
        defer { L10n.isRussian = false }
        L10n.isRussian = true
        #expect(t("%ld min", 5) == "5 мин")
        #expect(t("Break in %@", "0:45") == "Перерыв через 0:45")
        #expect(t("%ld h %ld min", 1, 30) == "1 ч 30 мин")
        #expect(t("+%ld min", 5) == "+5 мин")
        #expect(t("Unknown %ld thing", 7) == "Unknown 7 thing")
    }

    @Test func formattingEveryKeyDoesNotCrash() {
        // Feed every key with arguments that match its own specifiers, in both languages.
        defer { L10n.isRussian = false }
        for russian in [false, true] {
            L10n.isRussian = russian
            for key in L10n.ru.keys {
                let specs = L10nScan.specifiers(key).filter { $0 != "%%" }
                guard !specs.isEmpty, specs.allSatisfy({ ["%@", "%ld", "%d"].contains($0) }) else { continue }
                // A mismatched value would crash here; that case is reported by the specifier test instead.
                guard L10nScan.specifiers(t(key)) == L10nScan.specifiers(key) else { continue }
                let args: [CVarArg] = specs.map { spec -> CVarArg in
                    switch spec {
                    case "%@": return "X" as NSString
                    case "%ld": return 7 as Int
                    default: return Int32(7)
                    }
                }
                let out = String(format: t(key), arguments: args)
                #expect(!out.isEmpty)
                #expect(!out.contains("%@") && !out.contains("%ld"), "Unformatted specifier left in \"\(out)\"")
            }
        }
    }

    // MARK: L10n.apply / AppLanguage

    @Test func applyEnglishAndRussian() {
        defer { L10n.isRussian = false }
        L10n.apply(.ru)
        #expect(L10n.isRussian)
        #expect(t("Pause") == "Пауза")
        L10n.apply(.en)
        #expect(!L10n.isRussian)
        #expect(t("Pause") == "Pause")
    }

    @Test func applySystemFollowsPreferredLanguages() {
        defer { L10n.isRussian = false }
        L10n.apply(.system)
        let expected = Locale.preferredLanguages.first?.hasPrefix("ru") ?? false
        #expect(L10n.isRussian == expected)
    }

    @Test func appLanguageTitles() {
        defer { L10n.isRussian = false }
        L10n.isRussian = false
        #expect(AppLanguage.system.title == "System")
        #expect(AppLanguage.en.title == "English")
        #expect(AppLanguage.ru.title == "Русский")
        L10n.isRussian = true
        #expect(AppLanguage.system.title == "Как в системе")
        #expect(AppLanguage.en.title == "English")
        #expect(AppLanguage.ru.title == "Русский")
    }

    @Test func appLanguageCasesAndIDs() {
        #expect(AppLanguage.allCases == [.system, .en, .ru])
        #expect(AppLanguage.allCases.map(\.id) == ["system", "en", "ru"])
        #expect(AppLanguage(rawValue: "ru") == .ru)
    }
}
