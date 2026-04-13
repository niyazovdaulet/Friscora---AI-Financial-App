//
//  HapticHelper.swift
//  Friscora
//
//  Centralized haptics: selection for tab/segment/picker changes, light/medium for actions.
//

import UIKit
import Combine

enum HapticHelper {

    /// Use for tab, segment, or picker selection changes.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Use for secondary actions: collapse, filter chip, "View All", clear form.
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Use for primary commit actions: save, add transaction, complete goal, delete.
    static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}
