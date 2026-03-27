//
//  FeedbackView.swift
//  Friscora
//
//  In-app feedback form: submits to Firestore with optional screenshot as base64.
//

import SwiftUI
import PhotosUI

struct FeedbackView: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var descriptionText = ""
    @State private var stepsToReproduce = ""
    @State private var expectedResult = ""
    @State private var actualResult = ""
    @State private var selectedType: FeedbackType = .other
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var loadedImage: UIImage?
    @State private var isSubmitting = false
    @State private var showThankYou = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    @State private var thankYouAppeared = false

    private enum Field {
        case subject, description, steps, expected, actual
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()

                if showThankYou {
                    thankYouContent
                } else {
                    ZStack(alignment: .bottom) {
                        formContent
                        if canSubmit && !showThankYou {
                            sendFeedbackButton
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            AppColorTheme.background.opacity(0),
                                            AppColorTheme.background.opacity(0.95),
                                            AppColorTheme.cardBackground.opacity(0.98)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .ignoresSafeArea(edges: .bottom)
                                )
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(AppAnimation.formField, value: canSubmit)
                }
            }
            .navigationTitle(L10n("feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        HapticHelper.lightImpact()
                        isPresented = false
                        dismiss()
                    }
                    .foregroundColor(AppColorTheme.sapphire)
                }
            }
        }
    }

    private var formContent: some View {
        Form {
            // Required
            Section {
                TextField(L10n("feedback.subject_placeholder"), text: $subject)
                    .focused($focusedField, equals: .subject)
                    .autocapitalization(.sentences)
                TextField(L10n("feedback.description_placeholder"), text: $descriptionText, axis: .vertical)
                    .focused($focusedField, equals: .description)
                    .lineLimit(3...8)
                    .autocapitalization(.sentences)
            } header: {
                Text(L10n("feedback.required"))
                    .foregroundColor(.white)
            }

            // Type – tap a row to select (no Menu/Picker to avoid UIHostingController reparenting)
            Section {
                ForEach(FeedbackType.allCases, id: \.self) { type in
                    Button {
                        HapticHelper.selection()
                        selectedType = type
                    } label: {
                        HStack {
                            Text(typeLabel(for: type))
                                .foregroundColor(AppColorTheme.textPrimary)
                            Spacer()
                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColorTheme.sapphire)
                            }
                        }
                    }
                }
            } header: {
                Text(L10n("feedback.type_section"))
            }

            // Optional details
            Section {
                TextField(L10n("feedback.steps_placeholder"), text: $stepsToReproduce, axis: .vertical)
                    .focused($focusedField, equals: .steps)
                    .lineLimit(2...6)
                TextField(L10n("feedback.expected_placeholder"), text: $expectedResult, axis: .vertical)
                    .focused($focusedField, equals: .expected)
                    .lineLimit(1...4)
                TextField(L10n("feedback.actual_placeholder"), text: $actualResult, axis: .vertical)
                    .focused($focusedField, equals: .actual)
                    .lineLimit(1...4)
            } header: {
                Text(L10n("feedback.optional_details"))
            }

            // Screenshot – optional, one image stored as base64 in Firestore
            Section {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 1,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(AppColorTheme.sapphire)
                            .frame(width: 24)
                        if loadedImage != nil {
                            Text(L10n("feedback.screenshot_change"))
                        } else {
                            Text(L10n("feedback.screenshot_add"))
                        }
                    }
                }
                .onChange(of: selectedPhotoItems) { _, newItems in
                    Task {
                        await loadImage(from: newItems.first)
                    }
                }
                if let img = loadedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } header: {
                Text(L10n("feedback.screenshot_optional"))
            } footer: {
                Text(L10n("feedback.screenshot_footer"))
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // Extra bottom padding when sticky button is visible so last section isn’t covered
            if canSubmit {
                Section {
                    Color.clear
                        .frame(height: 72)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var canSubmit: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sendFeedbackButton: some View {
        Button {
            submitFeedback()
        } label: {
            HStack(spacing: 12) {
                if isSubmitting {
                    ProgressView()
                        .tint(AppColorTheme.textPrimary)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                    Text(L10n("feedback.submit"))
                        .fontWeight(.semibold)
                        .font(.headline)
                }
            }
            .foregroundColor(AppColorTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        AppColorTheme.sapphire,
                        AppColorTheme.sapphire.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: AppColorTheme.sapphire.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .disabled(isSubmitting)
    }

    private var thankYouContent: some View {
        VStack(spacing: 0) {
            Spacer()
            thankYouCard
            Spacer()
            thankYouDoneButton
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var thankYouCard: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColorTheme.sapphire.opacity(0.25),
                                AppColorTheme.sapphire.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColorTheme.emeraldGreen,
                                AppColorTheme.emeraldGreen.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            VStack(spacing: 10) {
                Text(L10n("feedback.thank_you_title"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColorTheme.textPrimary)
                Text(L10n("feedback.thank_you_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppColorTheme.layer2Border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
        )
        .padding(.horizontal, 24)
        .opacity(thankYouAppeared ? 1 : 0)
        .scaleEffect(thankYouAppeared ? 1 : 0.88)
        .onAppear {
            withAnimation(AppAnimation.feedbackSubmit) {
                thankYouAppeared = true
            }
        }
    }

    private var thankYouDoneButton: some View {
        Button {
            HapticHelper.lightImpact()
            isPresented = false
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(L10n("common.done"))
                    .fontWeight(.semibold)
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(AppColorTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        AppColorTheme.sapphire,
                        AppColorTheme.sapphire.opacity(0.88)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: AppColorTheme.sapphire.opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    private func typeLabel(for type: FeedbackType) -> String {
        switch type {
        case .bug: return L10n("feedback.type_bug")
        case .feature: return L10n("feedback.type_feature")
        case .other: return L10n("feedback.type_other")
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else {
            await MainActor.run { loadedImage = nil }
            return
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            await MainActor.run { loadedImage = nil }
            return
        }
        await MainActor.run { loadedImage = uiImage }
    }

    private func submitFeedback() {
        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        HapticHelper.mediumImpact()
        Task {
            do {
                try await FeedbackService.shared.submit(
                    subject: subject,
                    description: descriptionText,
                    stepsToReproduce: stepsToReproduce.isEmpty ? nil : stepsToReproduce,
                    expectedResult: expectedResult.isEmpty ? nil : expectedResult,
                    actualResult: actualResult.isEmpty ? nil : actualResult,
                    type: selectedType,
                    screenshotImage: loadedImage
                )
                await MainActor.run {
                    isSubmitting = false
                    showThankYou = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
