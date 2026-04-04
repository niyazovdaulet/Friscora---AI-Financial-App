//
//  CustomCategoryFormViews.swift
//  Friscora
//
//  Shared editor UI for new / edit custom category (matches Dashboard & Analytics card styling).
//

import SwiftUI

enum CustomCategoryEditorConstants {
    static let emojiOptions: [String] = [
        "📝", "🎯", "💡", "⭐", "🔥", "💎", "🎨", "🎵", "🏆", "🌟", "✨", "🎪",
        "🎭", "🎬", "📚", "🎮", "⚽", "🏀", "🎾", "🏊", "🚴", "🎲", "🎰", "💰",
        "💳", "🏥", "🎓", "🍕", "☕", "🚗"
    ]
}

/// Name, emoji, and chart color — used by add and edit category sheets.
struct CustomCategoryEditorContent: View {
    @Binding var categoryName: String
    @Binding var selectedEmoji: String
    @Binding var selectedColorHex: String
    var focusName: FocusState<Bool>.Binding
    /// Uppercased 6-char hexes unavailable unless currently selected (other customs only).
    var lockedChartHexes: Set<String> = []
    /// Emoji strings used by built-ins or other customs (current selection stays tappable).
    var lockedEmojis: Set<String> = []
    /// Shown under the name field when non-nil (e.g. duplicate name).
    var nameDuplicateMessage: String? = nil

    /// Icon grid hidden by default so chart colors stay above the fold.
    @State private var emojiPickerExpanded = false

    private var colorHexesForPicker: [String] {
        CategoryColorPalette.editorHexesIncludingSelection(selectedColorHex)
    }

    private var emojiOptionsForPicker: [String] {
        CategoryIconReservation.editorEmojiOptionsIncludingSelection(selectedEmoji)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                sectionLabel(L10n("category.name"))
                editorCard {
                    TextField(L10n("add_transaction.enter_category_name"), text: $categoryName)
                        .font(AppTypography.body)
                        .foregroundColor(AppColorTheme.textPrimary)
                        .focused(focusName)
                        .textInputAutocapitalization(.words)

                    if let msg = nameDuplicateMessage, !msg.isEmpty {
                        Text(msg)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColorTheme.negative)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, AppSpacing.xs)
                    }
                }

                sectionLabel(L10n("category.icon"))
                editorCard {
                    if emojiPickerExpanded {
                        emojiGrid(emojiOptionsForPicker)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                emojiPickerExpanded = false
                            }
                            HapticHelper.selection()
                        } label: {
                            Label(L10n("category.icon_collapse"), systemImage: "chevron.up")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColorTheme.sapphire)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.s)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                emojiPickerExpanded = true
                            }
                            HapticHelper.selection()
                        } label: {
                            HStack(spacing: 14) {
                                Text(selectedEmoji)
                                    .font(.system(size: 40))
                                    .frame(width: 56, height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(AppColorTheme.layer3Elevated)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppColorTheme.grayDark, lineWidth: 1)
                                    )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n("category.icon.tap_to_change"))
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(AppColorTheme.textPrimary)
                                        .multilineTextAlignment(.leading)
                                    Text(L10n("category.icon.collapse_hint"))
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColorTheme.textTertiary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColorTheme.textTertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionLabel(L10n("category.chart_color"))
                editorCard {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: AppSpacing.s
                    ) {
                        ForEach(colorHexesForPicker, id: \.self) { hex in
                            let hexU = hex.uppercased()
                            let on = selectedColorHex.uppercased() == hexU
                            let locked = lockedChartHexes.contains(hexU) && !on
                            Button {
                                guard !locked else { return }
                                selectedColorHex = hex
                                HapticHelper.selection()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 36, height: 36)
                                        .opacity(locked ? 0.42 : 1)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                    if on {
                                        Circle()
                                            .stroke(AppColorTheme.textPrimary, lineWidth: 2.5)
                                            .frame(width: 44, height: 44)
                                    }
                                    if locked {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
                                    }
                                }
                                .frame(height: 48)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .disabled(locked)
                            .accessibilityLabel(
                                locked
                                    ? String(format: L10n("category.chart_color.a11y_locked"), hex)
                                    : String(format: L10n("category.chart_color.a11y_swatch"), hex)
                            )
                            .accessibilityAddTraits(on ? [.isSelected] : [])
                        }
                    }
                }
            }
            .padding(AppSpacing.m)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollIndicators(.hidden, axes: .vertical)
        .background(AppColorTheme.background)
    }

    @ViewBuilder
    private func emojiGrid(_ emojis: [String]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: AppSpacing.s
        ) {
            ForEach(emojis, id: \.self) { emoji in
                let on = selectedEmoji == emoji
                let locked = lockedEmojis.contains(emoji) && !on
                Button {
                    guard !locked else { return }
                    selectedEmoji = emoji
                    HapticHelper.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        emojiPickerExpanded = false
                    }
                } label: {
                    ZStack {
                        Text(emoji)
                            .font(.system(size: 28))
                            .opacity(locked ? 0.42 : 1)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        on
                                            ? AppColorTheme.sapphire.opacity(0.22)
                                            : AppColorTheme.layer3Elevated
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        on ? AppColorTheme.sapphire : AppColorTheme.grayDark,
                                        lineWidth: on ? 1.5 : 1
                                    )
                            )
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
                        }
                    }
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .accessibilityLabel(
                    locked
                        ? String(format: L10n("category.icon.a11y_locked"), emoji)
                        : String(format: L10n("category.icon.a11y_option"), emoji)
                )
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(AppColorTheme.textPrimary)
            .tracking(0.4)
    }

    private func editorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(AppSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(AppColorTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                    )
            )
    }
}
