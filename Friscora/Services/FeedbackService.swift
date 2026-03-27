//
//  FeedbackService.swift
//  Friscora
//
//  Submits in-app feedback to Firestore. Optional screenshot stored as base64
//  in the document (no Storage) to stay on the free Spark plan.
//

import Foundation
import FirebaseFirestore
import UIKit

/// Feedback type for filtering in a future dashboard.
enum FeedbackType: String, CaseIterable, Identifiable {
    case bug
    case feature
    case other

    var id: String { rawValue }
}

// MARK: - Metadata (auto-filled, hidden from user)

private struct FeedbackMetadata {
    let appVersion: String
    let buildNumber: String
    let device: String
    let iosVersion: String
    let locale: String
    let analyticsMonth: String?
}

// MARK: - Service

final class FeedbackService {
    static let shared = FeedbackService()

    private let collection = "feedback"
    private let analyticsMonthKey = "friscora_last_analytics_month"

    private init() {}

    /// Persist the last selected analytics month so feedback can include it when present.
    /// Call from Analytics when the user changes the selected month.
    func setLastAnalyticsMonth(_ date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone.current
        let value = formatter.string(from: date)
        UserDefaults.standard.set(value, forKey: analyticsMonthKey)
    }

    /// Read last analytics month (e.g. "2025-02") if set.
    func lastAnalyticsMonth() -> String? {
        UserDefaults.standard.string(forKey: analyticsMonthKey)
    }

    private func collectMetadata() -> FeedbackMetadata {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let device = UIDevice.current.model
        let iosVersion = UIDevice.current.systemVersion
        let locale = LocalizationManager.shared.currentLanguageCode
        let analyticsMonth = lastAnalyticsMonth()
        return FeedbackMetadata(
            appVersion: version,
            buildNumber: build,
            device: device,
            iosVersion: iosVersion,
            locale: locale,
            analyticsMonth: analyticsMonth
        )
    }

    /// Firestore document limit is 1 MB; each string field is limited to ~1 MB.
    /// Compress aggressively and cap so screenshotBase64 stays under ~700 KB (safe with other fields).
    private static let maxBase64Bytes = 700_000

    /// Compress image to JPEG and return base64 string, or nil if still too large.
    func compressImageToBase64(_ image: UIImage) -> String? {
        let maxLongSide: CGFloat = 560
        var quality: CGFloat = 0.4
        let size = image.size
        let scale = min(maxLongSide / max(size.width, size.height), 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        guard newSize.width >= 1, newSize.height >= 1 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: newSize)
        var resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        for _ in 0..<4 {
            guard let jpeg = resized.jpegData(compressionQuality: quality) else { return nil }
            if jpeg.count <= Self.maxBase64Bytes {
                return jpeg.base64EncodedString()
            }
            quality -= 0.08
            if quality < 0.2 { break }
        }
        return nil
    }

    /// Submit feedback to Firestore. Screenshot is optional; stored as base64 in document.
    func submit(
        subject: String,
        description: String,
        stepsToReproduce: String?,
        expectedResult: String?,
        actualResult: String?,
        type: FeedbackType?,
        screenshotImage: UIImage?
    ) async throws {
        let meta = collectMetadata()
        let screenshotBase64 = screenshotImage.flatMap { compressImageToBase64($0) }

        var data: [String: Any] = [
            "subject": subject.trimmingCharacters(in: .whitespacesAndNewlines),
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "appVersion": meta.appVersion,
            "buildNumber": meta.buildNumber,
            "device": meta.device,
            "iosVersion": meta.iosVersion,
            "locale": meta.locale,
            "createdAt": Timestamp(date: Date())
        ]

        if let steps = stepsToReproduce?.trimmingCharacters(in: .whitespacesAndNewlines), !steps.isEmpty {
            data["stepsToReproduce"] = steps
        }
        if let expected = expectedResult?.trimmingCharacters(in: .whitespacesAndNewlines), !expected.isEmpty {
            data["expectedResult"] = expected
        }
        if let actual = actualResult?.trimmingCharacters(in: .whitespacesAndNewlines), !actual.isEmpty {
            data["actualResult"] = actual
        }
        if let t = type {
            data["type"] = t.rawValue
        }
        if let base64 = screenshotBase64 {
            data["screenshotBase64"] = base64
        }
        if let month = meta.analyticsMonth {
            data["analyticsMonth"] = month
        }

        try await Firestore.firestore().collection(collection).addDocument(data: data)
    }
}
