import Foundation
import PDFKit
import CryptoKit
import Combine

enum StatementImportError: LocalizedError {
    case unsupportedFile
    case unreadableFile
    case corruptedPDF
    case noExtractableText
    case noTransactionsDetected
    case storageFailure

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "This file is not a supported PDF statement."
        case .unreadableFile:
            return "Friscora couldn't read this file."
        case .corruptedPDF:
            return "This PDF appears corrupted or unsupported."
        case .noExtractableText:
            return "This PDF appears to be unsupported or image-based."
        case .noTransactionsDetected:
            return "We couldn't identify transactions in this statement."
        case .storageFailure:
            return "We couldn't save this statement locally."
        }
    }
}

final class StatementFileStore {
    private let filesKey = "statement_import_files_v1"
    private let fm = FileManager.default

    private var importsDirectory: URL {
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("StatementImports", isDirectory: true)
    }

    func listFiles() -> [ImportedStatementFile] {
        guard let data = UserDefaults.standard.data(forKey: filesKey),
              let decoded = try? JSONDecoder().decode([ImportedStatementFile].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.importedAt > $1.importedAt }
    }

    func saveFiles(_ files: [ImportedStatementFile]) {
        guard let encoded = try? JSONEncoder().encode(files) else { return }
        UserDefaults.standard.set(encoded, forKey: filesKey)
    }

    func importPDF(from sourceURL: URL) throws -> ImportedStatementFile {
        guard sourceURL.pathExtension.lowercased() == "pdf" else {
            throw StatementImportError.unsupportedFile
        }
        let secured = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if secured { sourceURL.stopAccessingSecurityScopedResource() }
        }
        guard fm.isReadableFile(atPath: sourceURL.path) else { throw StatementImportError.unreadableFile }
        try fm.createDirectory(at: importsDirectory, withIntermediateDirectories: true)

        let destination = importsDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        do {
            try fm.copyItem(at: sourceURL, to: destination)
        } catch {
            throw StatementImportError.storageFailure
        }

        let hash = try computeFileHash(for: destination)
        let file = ImportedStatementFile(
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            localURL: destination,
            fileHash: hash
        )
        var files = listFiles()
        files.insert(file, at: 0)
        saveFiles(files)
        return file
    }

    func updateFile(_ file: ImportedStatementFile) {
        var files = listFiles()
        guard let idx = files.firstIndex(where: { $0.id == file.id }) else { return }
        files[idx] = file
        saveFiles(files)
    }

    func renameFile(_ file: ImportedStatementFile, to newName: String) {
        var updated = file
        updated.displayName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        updateFile(updated)
    }

    func deleteFile(_ file: ImportedStatementFile) {
        try? fm.removeItem(at: file.localURL)
        var files = listFiles()
        files.removeAll { $0.id == file.id }
        saveFiles(files)
    }

    private func computeFileHash(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

struct StatementParseResult {
    let pageCount: Int
    let transactions: [ParsedStatementTransaction]
    let warnings: [String]
}

final class StatementParserService {
    typealias ParseProgressHandler = @Sendable (String) -> Void
    private let dateFormatter = DateFormatter()
    private let amountRegex = try? NSRegularExpression(
        pattern: #"([-+]?\s*\d{1,3}(?:[ \u{00A0}.]\d{3})*(?:,\d{2})|[-+]?\s*\d+(?:,\d{2}))\s*(PLN|EUR|USD|GBP|RUB|KZT|zł|€|\$|£|₽|₸|〒)\b"#,
        options: [.caseInsensitive]
    )

    func parseStatement(from file: ImportedStatementFile, progress: ParseProgressHandler? = nil) throws -> StatementParseResult {
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        progress?("Extracting pages…")
        guard let pdf = PDFDocument(url: file.localURL) else { throw StatementImportError.corruptedPDF }
        let pageCount = pdf.pageCount
        guard pageCount > 0 else { throw StatementImportError.noExtractableText }

        var lines: [String] = []
        for index in 0..<pageCount {
            let pageText = pdf.page(at: index)?.string ?? ""
            lines.append(contentsOf: pageText.components(separatedBy: .newlines))
        }

        progress?("Detecting transactions…")
        let normalizedLines = normalizeLines(lines)
        if normalizedLines.isEmpty { throw StatementImportError.noExtractableText }

        progress?("Identifying amounts…")
        let blocks = parseTransactionBlocks(from: normalizedLines)
        var parsed: [ParsedStatementTransaction] = []
        var parseWarnings: [String] = []
        var rejectionCounts: [TransactionBlockRejectionReason: Int] = [:]

        for block in blocks {
            if let tx = buildParsedTransaction(from: block) {
                parsed.append(tx)
            } else if let reason = block.rejectionReason {
                rejectionCounts[reason, default: 0] += 1
            }
        }

        // Fallback for bank statements that are table-like (Date Amount Details) and don't use Santander markers.
        if parsed.isEmpty {
            progress?("Trying generic statement format…")
            parsed = parseGenericTransactionRows(from: normalizedLines)
        }

        if parsed.count < 3, !parsed.isEmpty {
            parseWarnings.append("Some transactions need manual review before importing.")
        }
        if let missingAmount = rejectionCounts[.missingAmount], missingAmount > 0 {
            parseWarnings.append("\(missingAmount) block(s) skipped due to missing amount.")
        }
        if let missingDate = rejectionCounts[.missingOperationDate], missingDate > 0 {
            parseWarnings.append("\(missingDate) block(s) skipped due to missing date.")
        }
        logParseDebugReport(
            pageCount: pageCount,
            lineCount: normalizedLines.count,
            blocks: blocks,
            parsedCount: parsed.count,
            rejectionCounts: rejectionCounts
        )
        if parsed.isEmpty { throw StatementImportError.noTransactionsDetected }
        progress?("Preparing review…")
        return StatementParseResult(pageCount: pageCount, transactions: parsed, warnings: parseWarnings)
    }

    private func normalizeLines(_ rawLines: [String]) -> [String] {
        let normalized = rawLines
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return stitchSplitPolishTokens(in: normalized)
    }

    /// Fold for stitch pairing only (must match whole keyword when two lines are concatenated without spaces).
    private func foldedLineFragment(_ line: String) -> String {
        line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .lowercased()
    }

    /// Only merge genuinely split tokens (e.g. `Data ope` + `racji`). Do **not** merge legal footers like
    /// `…zł. Strona 1/6` + `Data operacji` — that previously swallowed page boundaries and dropped amounts.
    private func stitchSplitPolishTokens(in lines: [String]) -> [String] {
        var merged: [String] = []
        var index = 0
        while index < lines.count {
            let current = lines[index]
            if index + 1 < lines.count {
                let next = lines[index + 1]
                let a = foldedLineFragment(current)
                let b = foldedLineFragment(next)
                let combined = a + b
                if combined == "dataoperacji" || combined == "dataksiegowania" || combined == "datawydruku" {
                    let stitched = "\(current) \(next)"
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    merged.append(stitched)
                    index += 2
                    continue
                }
            }
            merged.append(current)
            index += 1
        }
        return merged
    }

    func parseTransactionBlocks(from lines: [String]) -> [RawTransactionBlock] {
        var blocks: [RawTransactionBlock] = []
        var index = 0
        var activeTitleBlockIndex: Int?

        while index < lines.count {
            let line = lines[index]
            if isIgnorableLine(line) {
                activeTitleBlockIndex = nil
                index += 1
                continue
            }

            if isOperationDateMarker(line) {
                var block = RawTransactionBlock(capturedLines: [line])
                if detectAmount(in: line) != nil, isLikelyBookedAmountLine(line) {
                    block.amountLine = line
                }
                index += 1
                if index < lines.count, let date = parseDate(lines[index]) {
                    block.operationDateLine = formattedDate(date)
                    block.capturedLines.append(lines[index])
                    index += 1
                }
                if index < lines.count, isBookingDateMarker(lines[index]) {
                    block.capturedLines.append(lines[index])
                    index += 1
                    if index < lines.count, let date = parseDate(lines[index]) {
                        block.bookingDateLine = formattedDate(date)
                        block.capturedLines.append(lines[index])
                        index += 1
                    }
                }
                blocks.append(block)
                activeTitleBlockIndex = nil
                continue
            }

            if let title = extractTitleValue(from: line), !title.isEmpty {
                if let targetIndex = blocks.indices.last {
                    blocks[targetIndex].titleLines.append(title)
                    blocks[targetIndex].capturedLines.append(line)
                    activeTitleBlockIndex = targetIndex
                }
                index += 1
                continue
            }

            if let activeTitleBlockIndex, shouldContinueTitle(with: line) {
                blocks[activeTitleBlockIndex].titleLines.append(line)
                blocks[activeTitleBlockIndex].capturedLines.append(line)
                index += 1
                continue
            } else {
                activeTitleBlockIndex = nil
            }

            if detectAmount(in: line) != nil, isLikelyBookedAmountLine(line) {
                if let targetIndex = blocks.lastIndex(where: { $0.amountLine == nil }) {
                    blocks[targetIndex].amountLine = line
                    blocks[targetIndex].capturedLines.append(line)
                } else if let last = blocks.indices.last {
                    blocks[last].amountLine = line
                    blocks[last].capturedLines.append(line)
                }
                index += 1
                continue
            }

            if let activeTitleBlockIndex {
                blocks[activeTitleBlockIndex].capturedLines.append(line)
            } else if let last = blocks.indices.last {
                blocks[last].capturedLines.append(line)
            }
            index += 1
        }

        for idx in blocks.indices {
            let block = blocks[idx]
            if block.operationDateLine == nil, block.bookingDateLine == nil {
                blocks[idx].rejectionReason = .missingOperationDate
            } else if block.amountLine == nil {
                blocks[idx].rejectionReason = .missingAmount
            } else if buildDescription(from: block).isEmpty {
                blocks[idx].rejectionReason = .missingDescription
            }
        }

        return blocks
    }

    func buildParsedTransaction(from block: RawTransactionBlock) -> ParsedStatementTransaction? {
        guard let amountLine = block.amountLine,
              let amount = detectAmount(in: amountLine) else {
            return nil
        }
        let dateRaw = block.operationDateLine ?? block.bookingDateLine
        guard let dateRaw, let date = parseDate(dateRaw) else {
            return nil
        }

        var warnings: [String] = []
        let description = buildDescription(from: block)
        if description.isEmpty {
            warnings.append("Description is short")
        }
        if abs(amount.value) < 0.01 {
            warnings.append("Amount looks unusual")
        }
        if block.operationDateLine == nil {
            warnings.append("Used booking date")
        }

        var confidence = 0.58
        if block.operationDateLine != nil { confidence += 0.18 }
        if block.bookingDateLine != nil { confidence += 0.06 }
        if !description.isEmpty { confidence += 0.12 }
        if block.amountLine != nil { confidence += 0.08 }
        if warnings.count >= 2 { confidence -= 0.15 }
        if confidence < 0.65 {
            warnings.append("Low confidence parse")
        }

        let displayDescription = description.isEmpty ? "Imported Transaction" : description
        let rawBlock = block.capturedLines.joined(separator: " | ")
        let currency = amount.currency ?? detectCurrency(in: amountLine) ?? UserProfileService.shared.profile.currency
        var direction: ParsedTransactionDirection = amount.value >= 0 ? .income : .expense
        let foldedBlob = block.capturedLines.joined(separator: " ").folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "pl_PL")
        )
        let upperFolded = foldedBlob.uppercased()
        if upperFolded.contains("OBCIAZENIE") {
            direction = .expense
        } else if upperFolded.contains("UZNANIE") {
            direction = .income
        }

        return ParsedStatementTransaction(
            rawDescription: rawBlock,
            normalizedDescription: normalizeDescription(displayDescription),
            displayDescription: displayDescription,
            amount: amount.value,
            date: date,
            currency: currency,
            direction: direction,
            confidence: max(0.1, min(1.0, confidence)),
            warnings: warnings,
            rawSourceLine: amountLine
        )
    }

    private func normalizeDescription(_ description: String) -> String {
        description.lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectCurrency(in line: String) -> String? {
        let currencies = ["USD", "EUR", "GBP", "KZT", "PLN", "RUB", "$", "€", "£", "₸", "〒", "zł", "₽"]
        for currency in currencies where line.localizedCaseInsensitiveContains(currency) {
            switch currency {
            case "$": return "USD"
            case "€": return "EUR"
            case "£": return "GBP"
            case "₸": return "KZT"
            case "〒": return "KZT" // OCR/PDF extraction artifact for tenge sign in some statements
            case "₽": return "RUB"
            case "zł": return "PLN"
            default: return currency
            }
        }
        return nil
    }

    private func detectDate(in line: String) -> (value: Date, matchedText: String)? {
        let patterns = [
            "\\b\\d{2}/\\d{2}/\\d{4}\\b",
            "\\b\\d{2}/\\d{2}/\\d{2}\\b",
            "\\b\\d{2}\\.\\d{2}\\.\\d{4}\\b",
            "\\b\\d{2}\\.\\d{2}\\.\\d{2}\\b",
            "\\b\\d{4}-\\d{2}-\\d{2}\\b"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)),
                  let range = Range(match.range, in: line) else { continue }
            let raw = String(line[range])
            if let date = parseDate(raw) {
                return (date, raw)
            }
        }
        return nil
    }

    private func parseDate(_ raw: String) -> Date? {
        // Explicitly map 2-digit year statements to 20xx to avoid accidental year 0026/1926 parsing.
        if let d = parseTwoDigitYearDate(raw) {
            return d
        }
        let formats = [
            "dd/MM/yyyy", "MM/dd/yyyy",
            "dd.MM.yyyy", "MM.dd.yyyy",
            "yyyy-MM-dd",
            "dd/MM/yy", "MM/dd/yy",
            "dd.MM.yy", "MM.dd.yy"
        ]
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: raw) { return date }
        }
        return nil
    }

    func detectAmount(in line: String) -> (value: Double, matchedText: String, currency: String?)? {
        let nsRange = NSRange(location: 0, length: line.utf16.count)
        if let amountRegex {
            let matches = amountRegex.matches(in: line, range: nsRange)
            if !matches.isEmpty {
                var best: (score: Int, value: Double, token: String, currency: String?)?
                for match in matches {
                    guard let amountRange = Range(match.range(at: 1), in: line) else { continue }
                    let token = String(line[amountRange]).trimmingCharacters(in: .whitespaces)
                    guard let value = parseAmountToken(token), isPlausibleStatementLedgerAmount(value) else { continue }
                    let tokenStart = amountRange.lowerBound
                    let prefix = String(line[..<tokenStart])
                    let hasEqualsHint = prefix.suffix(3).contains("=")
                    let currency = match.range(at: 2).location != NSNotFound ? (Range(match.range(at: 2), in: line).map { String(line[$0]) }) : nil
                    let normalizedCurrency = normalizeCurrencyToken(currency)

                    var score = 0
                    if token.contains("-") || token.contains("+") { score += 5 }
                    if normalizedCurrency == "PLN" { score += 4 }
                    if hasEqualsHint { score -= 6 } // likely exchange rate (e.g. 1 USD=3.85 PLN)
                    if abs(value) >= 10 { score += 1 }
                    if best == nil || score > best!.score {
                        best = (score, value, token, normalizedCurrency)
                    }
                }
                if let best {
                    return (best.value, best.token, best.currency)
                }
            }
        }

        // Fallback pattern allows whitespace after sign (e.g. "- 200,00").
        let pattern = "[-+]?\\s*\\d{1,3}(?:[., ]\\d{3})*(?:[.,]\\d{2})|[-+]?\\s*\\d+(?:[.,]\\d{2})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: line, range: nsRange)
        guard let last = matches.last, let range = Range(last.range, in: line) else { return nil }
        let token = String(line[range]).trimmingCharacters(in: .whitespaces)
        guard let value = parseAmountToken(token), isPlausibleStatementLedgerAmount(value) else { return nil }

        var signedValue = value
        if line.lowercased().contains("debit") || line.contains("-\(token)") || line.contains("(\(token))") {
            signedValue = -abs(value)
        } else if line.lowercased().contains("credit") || line.contains("+\(token)") {
            signedValue = abs(value)
        }
        return (signedValue, token, detectCurrency(in: line))
    }

    /// Polish statements: space = thousands grouping, comma = decimal (e.g. `1 044,23` or `-681,06`).
    /// App elsewhere uses US-style in `CurrencyFormatter`; this path is statement-specific.
    func parseAmountToken(_ token: String) -> Double? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")

        if compact.contains(",") && compact.contains(".") {
            if compact.lastIndex(of: ",") ?? compact.startIndex > compact.lastIndex(of: ".") ?? compact.startIndex {
                let normalized = compact.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                return Double(normalized).map { CurrencyFormatter.roundToTwoDecimals($0) }
            }
            let normalized = compact.replacingOccurrences(of: ",", with: "")
            return Double(normalized).map { CurrencyFormatter.roundToTwoDecimals($0) }
        } else if compact.contains(",") {
            let normalized = compact.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            return Double(normalized).map { CurrencyFormatter.roundToTwoDecimals($0) }
        } else {
            let normalized = compact.replacingOccurrences(of: ",", with: "")
            return Double(normalized).map { CurrencyFormatter.roundToTwoDecimals($0) }
        }
    }

    /// Rejects share-capital / footer numbers (e.g. 1 021 893 140 zł) mistaken for transaction amounts.
    private func isPlausibleStatementLedgerAmount(_ value: Double) -> Bool {
        abs(value) <= 10_000_000
    }

    private func isOperationDateMarker(_ line: String) -> Bool {
        if line.range(of: #"(?i)data\s+opis\s+kwota"#, options: .regularExpression) != nil { return false }
        let normalized = normalizeForKeywordMatch(line)
        return normalized.contains("dataoperacji")
    }

    private func isBookingDateMarker(_ line: String) -> Bool {
        let normalized = normalizeForKeywordMatch(line)
        return normalized.contains("dataksiegowania")
    }

    private func extractTitleValue(from line: String) -> String? {
        guard let range = line.range(of: "Tytuł:", options: .caseInsensitive) else { return nil }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldContinueTitle(with line: String) -> Bool {
        if line.contains("PLN") || line.contains("EUR") || line.contains("USD") || line.contains("GBP") {
            return false
        }
        if isOperationDateMarker(line) || isBookingDateMarker(line) { return false }
        return !isMostlyMetadata(line)
    }

    private func isLikelyBookedAmountLine(_ line: String) -> Bool {
        if line.contains("=") { return false }
        if line.range(of: #"[-+]\s*\d"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^\s*\d[\d\s,.]*\s*(PLN|EUR|USD|GBP|RUB|KZT)\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        return false
    }

    private func buildDescription(from block: RawTransactionBlock) -> String {
        let joined = block.titleLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !isMostlyMetadata($0) }
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return joined
    }

    private func isIgnorableLine(_ line: String) -> Bool {
        let upper = line.uppercased()
        let blockedMarkers = [
            "HISTORIA RACHUNKU",
            "PODSUMOWANIE OGÓLNE",
            "ZESTAWIENIE OPERACJI",
            "REGULAMIN",
            "DANE ADRESOWE",
            "NUMER RACHUNKU",
            "NUMER KARTY",
            "SALDO KOŃCOWE",
            "SALDO POCZĄTKOWE",
            "SUMA WPŁYWÓW",
            "SUMA WYDATKÓW",
            "LICZBA OPERACJI",
            "ŁĄCZNIE:"
        ]
        if blockedMarkers.contains(where: { upper.contains($0) }) { return true }
        if upper.hasPrefix("WPŁYWY ") || upper.hasPrefix("WYDATKI ") { return true }
        if line.range(of: #"Strona\s+\d+/\d+"#, options: .regularExpression) != nil { return true }
        return isMostlyMetadata(line)
    }

    private func isMostlyMetadata(_ line: String) -> Bool {
        let accountPattern = #"\b\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\b"#
        let cardPattern = #"\b\d{4}\s?\*+\s?\*+\s?\d{4}\b"#
        let addressPattern = #"ul\.|kod pocztowy|miejscowość|klient|adres|regulamin|bank"# // polish statement footer noise
        if line.range(of: accountPattern, options: .regularExpression) != nil { return true }
        if line.range(of: cardPattern, options: .regularExpression) != nil { return true }
        if line.range(of: addressPattern, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        return false
    }

    private func formattedDate(_ date: Date) -> String {
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: date)
    }

    private func normalizeCurrencyToken(_ currency: String?) -> String? {
        guard let currency else { return nil }
        switch currency.lowercased() {
        case "zł": return "PLN"
        case "€": return "EUR"
        case "$": return "USD"
        case "£": return "GBP"
        case "₽": return "RUB"
        case "₸": return "KZT"
        case "〒": return "KZT" // OCR/PDF extraction artifact for tenge sign
        default: return currency.uppercased()
        }
    }

    private func normalizeForKeywordMatch(_ line: String) -> String {
        line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    /// Generic fallback parser for table-like statement rows:
    /// e.g. `03.04.26 - 200,00 ₸ Others Commission...`
    /// Used when block parser finds nothing (non-Santander layouts).
    private func parseGenericTransactionRows(from lines: [String]) -> [ParsedStatementTransaction] {
        var parsed: [ParsedStatementTransaction] = []
        for line in lines {
            guard let dateHit = detectDate(in: line), let amountHit = detectAmount(in: line) else { continue }
            if abs(amountHit.value) < 0.01 { continue }
            let explicitCurrency = amountHit.currency ?? detectCurrency(in: line)
            let hasExplicitSign = amountHit.matchedText.contains("-") || amountHit.matchedText.contains("+")
            let looksLikeDateFragmentAmount = amountHit.matchedText.range(of: #"^\d{1,2}\.\d{2}$"#, options: .regularExpression) != nil
            if looksLikeDateFragmentAmount && !hasExplicitSign && explicitCurrency == nil {
                continue
            }
            if !hasExplicitSign && explicitCurrency == nil {
                continue
            }

            // Remove the detected date and amount token to leave a readable description fragment.
            var description = line
            description = description.replacingOccurrences(of: dateHit.matchedText, with: "")
            description = description.replacingOccurrences(of: amountHit.matchedText, with: "")
            description = description.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove isolated currency tokens/symbols left after amount removal.
            description = description.replacingOccurrences(
                of: #"^(PLN|EUR|USD|GBP|RUB|KZT|zł|€|\$|£|₽|₸)\b\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            description = description.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip obvious headers/summary lines that happen to contain numbers.
            let lower = line.lowercased()
            if lower.contains("date amount transaction details") ||
                lower.contains("transaction summary") ||
                lower.contains("card balance") {
                continue
            }

            let displayDescription = description.isEmpty ? "Imported Transaction" : description
            let currency = explicitCurrency ?? UserProfileService.shared.profile.currency
            let direction: ParsedTransactionDirection = amountHit.value >= 0 ? .income : .expense

            let tx = ParsedStatementTransaction(
                rawDescription: line,
                normalizedDescription: normalizeDescription(displayDescription),
                displayDescription: displayDescription,
                amount: amountHit.value,
                date: dateHit.value,
                currency: currency,
                direction: direction,
                confidence: 0.72,
                warnings: []
            )
            parsed.append(tx)
        }
        return parsed
    }

    private func parseTwoDigitYearDate(_ raw: String) -> Date? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let separators: [Character] = [".", "/"]
        guard let sep = separators.first(where: { normalized.contains($0) }) else { return nil }
        let parts = normalized.split(separator: sep).map(String.init)
        guard parts.count == 3, parts[2].count == 2 else { return nil }
        guard let first = Int(parts[0]), let second = Int(parts[1]), let yy = Int(parts[2]) else { return nil }
        let fullYear = 2000 + yy

        func build(day: Int, month: Int) -> Date? {
            guard (1...31).contains(day), (1...12).contains(month) else { return nil }
            var comps = DateComponents()
            comps.calendar = Calendar(identifier: .gregorian)
            comps.timeZone = TimeZone.current
            comps.year = fullYear
            comps.month = month
            comps.day = day
            return comps.date
        }

        // Unambiguous cases first.
        if first > 12, let d = build(day: first, month: second) { return d }   // DD/MM/YY
        if second > 12, let d = build(day: second, month: first) { return d }  // MM/DD/YY

        // Ambiguous case (both <= 12): prefer separator-specific conventions, then fallback.
        if sep == "/" {
            if let d = build(day: second, month: first) { return d } // MM/DD/YY
            return build(day: first, month: second)                  // DD/MM/YY fallback
        } else {
            if let d = build(day: first, month: second) { return d } // DD.MM.YY
            return build(day: second, month: first)                  // MM.DD.YY fallback
        }
    }

    private func logParseDebugReport(
        pageCount: Int,
        lineCount: Int,
        blocks: [RawTransactionBlock],
        parsedCount: Int,
        rejectionCounts: [TransactionBlockRejectionReason: Int]
    ) {
        #if DEBUG
        print("🧾 [STATEMENT PARSE DEBUG]")
        print("   Pages: \(pageCount)")
        print("   Page limit: none (all pages scanned)")
        print("   Normalized lines: \(lineCount)")
        print("   Blocks detected: \(blocks.count)")
        print("   Parsed transactions: \(parsedCount)")
        if rejectionCounts.isEmpty {
            print("   Rejections: none")
        } else {
            for reason in TransactionBlockRejectionReason.allCases {
                let count = rejectionCounts[reason, default: 0]
                if count > 0 {
                    print("   Rejection \(reason.rawValue): \(count)")
                }
            }
        }
        let rejectedSamples = blocks.filter { $0.rejectionReason != nil }.prefix(3)
        for (index, sample) in rejectedSamples.enumerated() {
            let reason = sample.rejectionReason?.rawValue ?? "unknown"
            let preview = sample.capturedLines.prefix(6).joined(separator: " | ")
            print("   Sample rejected #\(index + 1) [\(reason)]: \(preview)")
        }
        print("─────────────────────────────────────────")
        #endif
    }
}

final class StatementImportReviewService {
    func recalculateSession(_ session: inout StatementImportSession) {
        session.selectedTransactionIDs = Set(session.parsedTransactions.filter(\.isSelected).map(\.id))
        session.updatedAt = Date()
    }

    func selectedTransactions(in session: StatementImportSession) -> [ParsedStatementTransaction] {
        session.parsedTransactions.filter { session.selectedTransactionIDs.contains($0.id) }
    }

    func selectedIncomeTotal(in session: StatementImportSession) -> Double {
        selectedTransactions(in: session).filter { $0.direction == .income }.reduce(0) { $0 + $1.absoluteAmount }
    }

    func selectedExpenseTotal(in session: StatementImportSession) -> Double {
        selectedTransactions(in: session).filter { $0.direction == .expense }.reduce(0) { $0 + $1.absoluteAmount }
    }
}

final class TransactionDeduplicationService {
    func detectDuplicates(parsedTransactions: [ParsedStatementTransaction]) -> [DuplicateTransactionWarning] {
        let calendar = Calendar.current
        let existingExpenses = ExpenseService.shared.expenses
        let existingIncomes = IncomeService.shared.incomes
        var warnings: [DuplicateTransactionWarning] = []

        for tx in parsedTransactions {
            let duplicate = (tx.direction == .expense) ? existingExpenses.contains(where: { existing in
                abs(existing.amount - tx.absoluteAmount) < 0.01 &&
                existing.currency == tx.currency &&
                calendar.isDate(existing.date, inSameDayAs: tx.date) &&
                normalize(existing.originalImportedDescription ?? existing.note ?? "").contains(tx.normalizedDescription.prefix(10))
            }) : existingIncomes.contains(where: { existing in
                abs(existing.amount - tx.absoluteAmount) < 0.01 &&
                existing.currency == tx.currency &&
                calendar.isDate(existing.date, inSameDayAs: tx.date) &&
                normalize(existing.originalImportedDescription ?? existing.note ?? "").contains(tx.normalizedDescription.prefix(10))
            })
            if duplicate {
                warnings.append(DuplicateTransactionWarning(parsedTransactionID: tx.id, reason: "Possible duplicate"))
            }
        }
        return warnings
    }

    private func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class StatementImportCommitService {
    func commit(file: ImportedStatementFile, session: StatementImportSession, skipDuplicateIDs: Set<UUID> = []) -> Int {
        let selected = session.parsedTransactions.filter { session.selectedTransactionIDs.contains($0.id) && !skipDuplicateIDs.contains($0.id) }
        let batchID = session.importBatchID ?? UUID()
        var incomes: [Income] = []
        var expenses: [Expense] = []

        for parsed in selected {
            if parsed.direction == .income {
                let income = Income(
                    amount: parsed.absoluteAmount,
                    date: parsed.date,
                    note: parsed.displayDescription,
                    currency: parsed.currency,
                    source: .statementImport(statementID: file.id, batchID: batchID),
                    sourceStatementID: file.id,
                    importBatchID: batchID,
                    originalImportedDescription: parsed.rawDescription,
                    isImported: true,
                    importConfidence: parsed.confidence
                )
                incomes.append(income)
            } else {
                let resolvedCategory = resolveExpenseCategory(for: parsed)
                let expense = Expense(
                    amount: parsed.absoluteAmount,
                    category: resolvedCategory.category,
                    customCategoryId: resolvedCategory.customCategoryID,
                    date: parsed.date,
                    note: parsed.displayDescription,
                    currency: parsed.currency,
                    sourceType: "statementImport",
                    sourceStatementID: file.id,
                    importBatchID: batchID,
                    originalImportedDescription: parsed.rawDescription,
                    isImported: true,
                    importConfidence: parsed.confidence
                )
                expenses.append(expense)
            }
        }
        if !incomes.isEmpty {
            IncomeService.shared.addIncomes(incomes)
        }
        if !expenses.isEmpty {
            ExpenseService.shared.addExpenses(expenses)
        }
        return selected.count
    }

    private func resolveExpenseCategory(for parsed: ParsedStatementTransaction) -> (category: ExpenseCategory, customCategoryID: UUID?) {
        let activeCustomIDs = Set(CustomCategoryService.shared.customCategories.map(\.id))

        if parsed.isCategorizationManuallyOverridden == true {
            if let customID = parsed.suggestedCustomCategoryID, activeCustomIDs.contains(customID) {
                return (.other, customID)
            }
            if let builtIn = parsed.suggestedBuiltInCategory {
                return (builtIn, nil)
            }
            return (.other, nil)
        }

        let confidence = parsed.categorizationConfidence ?? 0
        guard confidence >= CategorizationThresholds.mediumLowerBound else {
            return (.other, nil)
        }

        if let customID = parsed.suggestedCustomCategoryID, activeCustomIDs.contains(customID) {
            return (.other, customID)
        }
        if let builtIn = parsed.suggestedBuiltInCategory {
            return (builtIn, nil)
        }
        return (.other, nil)
    }
}

final class StatementImportCoordinator {
    private let fileStore = StatementFileStore()
    private let parser = StatementParserService()
    private let reviewService = StatementImportReviewService()
    private let dedupeService = TransactionDeduplicationService()
    private let commitService = StatementImportCommitService()
    private let categorySnapshotProvider = CategorySnapshotProvider()
    private let categorizationResolver = DeterministicCategorizationResolver()
    private let sessionsKey = "statement_import_sessions_v1"

    func files() -> [ImportedStatementFile] { fileStore.listFiles() }

    func rename(_ file: ImportedStatementFile, to name: String) {
        fileStore.renameFile(file, to: name)
    }

    func delete(_ file: ImportedStatementFile) {
        ExpenseService.shared.removeExpenses(withSourceStatementID: file.id)
        IncomeService.shared.removeIncomes(withSourceStatementID: file.id)
        fileStore.deleteFile(file)
        var sessions = loadSessions()
        sessions.removeAll { $0.statementFileID == file.id }
        saveSessions(sessions)
    }

    func importAndParseFile(from url: URL, progress: StatementParserService.ParseProgressHandler? = nil) throws -> (ImportedStatementFile, StatementImportSession) {
        var file = try fileStore.importPDF(from: url)
        let result = try parser.parseStatement(from: file, progress: progress)
        let enrichedTransactions = applyCategorization(to: result.transactions, force: true)
        let txIDs = Set(enrichedTransactions.map(\.id))
        let session = StatementImportSession(
            statementFileID: file.id,
            status: .readyForReview,
            parsedTransactions: enrichedTransactions,
            selectedTransactionIDs: txIDs,
            warnings: result.warnings
        )
        upsertSession(session)

        file.pageCount = result.pageCount
        file.status = .scanned
        file.transactionCount = enrichedTransactions.count
        file.totalIncome = enrichedTransactions.filter { $0.direction == .income }.reduce(0) { $0 + $1.absoluteAmount }
        file.totalExpense = enrichedTransactions.filter { $0.direction == .expense }.reduce(0) { $0 + $1.absoluteAmount }
        file.currencySet = Set(enrichedTransactions.map(\.currency))
        file.lastScannedAt = Date()
        fileStore.updateFile(file)
        return (file, session)
    }

    func rescan(_ file: ImportedStatementFile, progress: StatementParserService.ParseProgressHandler? = nil) throws -> StatementImportSession {
        let result = try parser.parseStatement(from: file, progress: progress)
        let enrichedTransactions = applyCategorization(to: result.transactions, force: true)
        let session = StatementImportSession(
            statementFileID: file.id,
            status: .readyForReview,
            parsedTransactions: enrichedTransactions,
            selectedTransactionIDs: Set(enrichedTransactions.map(\.id)),
            warnings: result.warnings
        )
        upsertSession(session)

        var updated = file
        updated.pageCount = result.pageCount
        updated.status = .scanned
        updated.transactionCount = enrichedTransactions.count
        updated.totalIncome = enrichedTransactions.filter { $0.direction == .income }.reduce(0) { $0 + $1.absoluteAmount }
        updated.totalExpense = enrichedTransactions.filter { $0.direction == .expense }.reduce(0) { $0 + $1.absoluteAmount }
        updated.currencySet = Set(enrichedTransactions.map(\.currency))
        updated.lastScannedAt = Date()
        fileStore.updateFile(updated)

        return session
    }

    func session(for fileID: UUID) -> StatementImportSession? {
        loadSessions().first(where: { $0.statementFileID == fileID })
    }

    func updateSession(_ session: StatementImportSession) {
        upsertSession(session)
    }

    func reviewServiceInstance() -> StatementImportReviewService { reviewService }

    func detectDuplicates(for session: StatementImportSession) -> [DuplicateTransactionWarning] {
        let selected = reviewService.selectedTransactions(in: session)
        return dedupeService.detectDuplicates(parsedTransactions: selected)
    }

    func commit(file: ImportedStatementFile, session: StatementImportSession, skipDuplicateIDs: Set<UUID>) -> Int {
        let importedCount = commitService.commit(file: file, session: session, skipDuplicateIDs: skipDuplicateIDs)

        var updatedSession = session
        updatedSession.status = .imported
        updatedSession.updatedAt = Date()
        upsertSession(updatedSession)

        if var storedFile = files().first(where: { $0.id == file.id }) {
            storedFile.status = .imported
            fileStore.updateFile(storedFile)
        }
        return importedCount
    }

    private func loadSessions() -> [StatementImportSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([StatementImportSession].self, from: data) else {
            return []
        }
        var didChange = false
        let migrated = decoded.map { session -> StatementImportSession in
            let enriched = applyCategorization(to: session.parsedTransactions, force: false)
            if enriched == session.parsedTransactions { return session }
            didChange = true
            var updated = session
            updated.parsedTransactions = enriched
            return updated
        }
        if didChange { saveSessions(migrated) }
        return migrated
    }

    private func saveSessions(_ sessions: [StatementImportSession]) {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(encoded, forKey: sessionsKey)
    }

    private func upsertSession(_ session: StatementImportSession) {
        var sessions = loadSessions()
        if let idx = sessions.firstIndex(where: { $0.id == session.id || $0.statementFileID == session.statementFileID }) {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
        saveSessions(sessions)
    }

    private func applyCategorization(
        to transactions: [ParsedStatementTransaction],
        force: Bool
    ) -> [ParsedStatementTransaction] {
        let snapshot = categorySnapshotProvider.activeCategorySnapshot()
        return transactions.map { transaction in
            guard transaction.direction == .expense else { return transaction }
            if transaction.isCategorizationManuallyOverridden == true { return transaction }
            if !force, transaction.categorizationConfidence != nil { return transaction }

            let suggestion = categorizationResolver.resolve(
                transactionDescription: transaction.rawDescription,
                snapshot: snapshot
            )
            var updated = transaction
            updated.suggestedBuiltInCategory = suggestion.category.builtInCategory
            updated.suggestedCustomCategoryID = suggestion.category.customCategoryID
            updated.categorizationConfidence = suggestion.confidence
            updated.categorizationReasons = [suggestion.reason]
            updated.categorizationSource = suggestion.category.source
            return updated
        }
    }
}
