//
//  CustomNumericKeyboard.swift
//  Friscora
//
//  Custom numeric keypad with period (.) as decimal key instead of comma.
//  Matches system keyboard layout and style; used as inputView for amount fields.
//

import SwiftUI
import UIKit

// MARK: - SwiftUI Keyboard View

struct CustomNumericKeyboardView: View {
    var onKeyPress: (String) -> Void
    
    private let keyColor = Color(uiColor: .systemGray4)
    private let keyColorPressed = Color(uiColor: .systemGray2)
    private let backgroundColor = Color(uiColor: .systemGray5)
    
    var body: some View {
        VStack(spacing: 10) {
            // Row 1: 1 2 3
            HStack(spacing: 8) {
                key("1")
                key("2")
                key("3")
            }
            // Row 2: 4 5 6
            HStack(spacing: 8) {
                key("4")
                key("5")
                key("6")
            }
            // Row 3: 7 8 9
            HStack(spacing: 8) {
                key("7")
                key("8")
                key("9")
            }
            // Row 4: . 0 backspace
            HStack(spacing: 8) {
                key(".")
                key("0")
                key("⌫", isBackspace: true)
            }
        }
        .padding(12)
        .frame(height: 280)
        .background(backgroundColor)
        .buttonStyle(.plain)
    }
    
    private func key(_ label: String, isBackspace: Bool = false) -> some View {
        Button {
            HapticHelper.lightImpact()
            if isBackspace {
                onKeyPress("backspace")
            } else {
                onKeyPress(label)
            }
        } label: {
            Text(label)
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(KeyButtonStyle(keyColor: keyColor, keyColorPressed: keyColorPressed))
    }
}

private struct KeyButtonStyle: ButtonStyle {
    let keyColor: Color
    let keyColorPressed: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? keyColorPressed : keyColor)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - UIKit Bridge (for use as inputView)

struct CustomNumericKeyboardUIView: UIViewRepresentable {
    var onKeyPress: (String) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let hosting = UIHostingController(rootView: CustomNumericKeyboardView(onKeyPress: onKeyPress))
        hosting.view?.backgroundColor = .systemGray5
        context.coordinator.hosting = hosting
        let view = hosting.view!
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 280)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var hosting: UIHostingController<CustomNumericKeyboardView>?
    }
}

// MARK: - Amount Field with Custom Keyboard

struct AmountInputWithCustomKeyboard: View {
    @Binding var amountDisplay: String
    var placeholder: String = "0.00"
    var focusTrigger: Int
    var onFormatChange: (String) -> Void
    var onFocusChange: ((Bool) -> Void)?
    
    var body: some View {
        AmountInputRepresentable(
            amountDisplay: $amountDisplay,
            placeholder: placeholder,
            focusTrigger: focusTrigger,
            onFormatChange: onFormatChange,
            onFocusChange: onFocusChange
        )
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

struct AmountInputRepresentable: UIViewRepresentable {
    @Binding var amountDisplay: String
    var placeholder: String
    var focusTrigger: Int
    var onFormatChange: (String) -> Void
    var onFocusChange: ((Bool) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            amountDisplay: $amountDisplay,
            onFormatChange: onFormatChange,
            onFocusChange: onFocusChange
        )
    }
    
    static func dismantleUIView(_ uiView: UITextField, coordinator: Coordinator) {
        uiView.removeTarget(coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
    }
    
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = .decimalPad
        field.font = .systemFont(ofSize: 28, weight: .bold)
        field.textAlignment = .left
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.tintColor = .label
        field.textColor = .label
        field.placeholder = placeholder
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.placeholderText]
        )
        
        let coord = context.coordinator
        let keyboardView = CustomNumericKeyboardUIView(onKeyPress: { [weak coord] key in
            guard let c = coord else { return }
            if key == "backspace" {
                c.textField?.deleteBackward()
            } else {
                c.textField?.insertText(key)
            }
        })
        let hosting = UIHostingController(rootView: keyboardView)
        hosting.view.backgroundColor = .systemGray5
        hosting.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 280)
        coord.keyboardHosting = hosting
        field.inputView = hosting.view
        field.inputAccessoryView = nil
        coord.textField = field
        field.text = amountDisplay
        field.addTarget(coord, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        return field
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
            uiView.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: UIColor.placeholderText]
            )
        }
        if uiView.text != amountDisplay {
            uiView.text = amountDisplay
        }
        if focusTrigger > context.coordinator.lastFocusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            var attempts = 0
            func tryBecomeFirstResponder() {
                if uiView.window != nil {
                    uiView.becomeFirstResponder()
                    return
                }
                attempts += 1
                if attempts < 10 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { tryBecomeFirstResponder() }
                }
            }
            DispatchQueue.main.async(execute: tryBecomeFirstResponder)
        }
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        weak var textField: UITextField?
        var keyboardHosting: UIHostingController<CustomNumericKeyboardUIView>? // retain keyboard
        @Binding var amountDisplay: String
        var onFormatChange: (String) -> Void
        var onFocusChange: ((Bool) -> Void)?
        private var isUpdatingFromDelegate = false
        var lastFocusTrigger = 0
        
        init(amountDisplay: Binding<String>, onFormatChange: @escaping (String) -> Void, onFocusChange: ((Bool) -> Void)?) {
            _amountDisplay = amountDisplay
            self.onFormatChange = onFormatChange
            self.onFocusChange = onFocusChange
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            onFocusChange?(true)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            onFocusChange?(false)
        }
        
        @objc func editingChanged(_ sender: UITextField) {
            guard !isUpdatingFromDelegate, let text = sender.text else { return }
            let stripped = CurrencyFormatter.stripAmountFormatting(text)
            let formatted = CurrencyFormatter.formatAmountForDisplay(stripped)
            isUpdatingFromDelegate = true
            amountDisplay = formatted
            onFormatChange(stripped)
            if sender.text != formatted {
                sender.text = formatted
            }
            isUpdatingFromDelegate = false
        }
    }
}
