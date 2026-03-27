//
//  ViewModifiers.swift
//  Friscora
//
//  Custom view modifiers for common functionality
//

import SwiftUI
import Combine

// MARK: - Dismiss Keyboard on Tap
struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTap())
    }
}

// MARK: - Dismiss Keyboard on Background Tap
/// Use when the view has text fields that must receive tap-to-focus (e.g. amount, note).
/// Tapping outside the keyboard/text fields dismisses the keyboard; tapping a text field focuses it.
struct DismissKeyboardOnBackgroundTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}

extension View {
    /// Dismisses keyboard when user taps outside text fields. Prefer over dismissKeyboardOnTap() when the view
    /// contains text fields that should receive tap-to-focus (e.g. Add tab amount/note).
    func dismissKeyboardOnBackgroundTap() -> some View {
        self.modifier(DismissKeyboardOnBackgroundTap())
    }
}

// MARK: - Keyboard Avoiding
/// Adds bottom padding equal to keyboard height so scroll content can move above the keyboard.
struct KeyboardAvoidingModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(keyboardHeightPublisher) { height in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = height
                }
            }
    }
}

private let keyboardHeightPublisher = Publishers.Merge(
    NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height },
    NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        .map { _ in CGFloat(0) }
)
    .receive(on: RunLoop.main)
    .removeDuplicates()

extension View {
    /// Adds bottom padding when the keyboard is visible so scroll content stays above the keyboard.
    func keyboardAvoiding() -> some View {
        modifier(KeyboardAvoidingModifier())
    }
}

// MARK: - Auto-dismiss Date Picker
struct AutoDismissDatePicker: View {
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents
    let onDateSelected: (() -> Void)?
    @State private var previousDate: Date
    
    init(selection: Binding<Date>, displayedComponents: DatePickerComponents, onDateSelected: (() -> Void)? = nil) {
        self._selection = selection
        self.displayedComponents = displayedComponents
        self.onDateSelected = onDateSelected
        self._previousDate = State(initialValue: selection.wrappedValue)
    }
    
    var body: some View {
        DatePicker("", selection: $selection, displayedComponents: displayedComponents)
            .onChange(of: selection) { newDate in
                // Only dismiss if date actually changed (not just initialization)
                if abs(newDate.timeIntervalSince(previousDate)) > 1.0 {
                    // Dismiss keyboard/date picker when date changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        onDateSelected?()
                    }
                }
                previousDate = newDate
            }
    }
}

