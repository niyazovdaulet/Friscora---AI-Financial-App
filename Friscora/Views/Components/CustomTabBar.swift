//
//  CustomTabBar.swift
//  Friscora
//
//  Bottom navigation for MainTabView: indices 0…4 match legacy TabView tags.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var pillNamespace

    // FI-UI-REFINE: Tighter vertical envelope (~15% shorter) for a slimmer floating bar without crowding the FAB.
    /// Total area reserved for the bar + FAB protrusion (slim strip + floating Add).
    private let tabBarLayoutHeight: CGFloat = 58
    // FI-UI-REFINE: Shorter chrome row so less empty space above icons; icons stay optically centered in the pill.
    /// Visible chrome strip behind the icon/label row only; FAB draws above and overlaps this strip.
    private let chromeStripMinHeight: CGFloat = 27
    // FI-UI-REFINE: Slightly less lift so the FAB still overlaps the glass after the bar got shorter (clean integration).
    /// Upward shift so the FAB reads as floating over the chrome strip (25% lower than prior 11pt lift).
    private let fabVerticalLift: CGFloat = 6
    /// Selected-tab “pill” as a rounded box (not a circle/capsule blob).
    private let selectionBoxCornerRadius: CGFloat = 10
    // FI-UI-REFINE: Corner radius scaled down with bar height so the capsule still feels balanced, not tubby.
    /// Outer floating “glass” capsule behind the tab row.
    private let glassBarCornerRadius: CGFloat = 23
    /// Reserves horizontal room for the floating FAB so side tabs don’t collide with it.
    private let fabLaneWidth: CGFloat = 64

    @State private var rippleGeneration = 0
    @State private var lastRippleTab: Int?

    private var tabSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : AppAnimation.tabBarSpring
    }

    private var fabSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : AppAnimation.tabBarFABSpring
    }

    private var pillAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : AppAnimation.tabBarPill
    }

    private var rippleAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.14) : AppAnimation.tabBarRipple
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                let barWidth = max(geo.size.width, 1)
                let interItem = Self.interItemSpacing(forBarWidth: barWidth)
                // Each pair is centered in its half so extra width isn’t all on the outer screen edges; uniform `interItem`
                // gaps keep the FAB from crowding Analytics / Schedule.
                HStack(alignment: .bottom, spacing: interItem) {
                    HStack(alignment: .bottom, spacing: interItem) {
                        regularItem(tab: 0, systemImage: "house.fill", title: L10n("tab.dashboard"))
                        regularItem(tab: 1, systemImage: "chart.pie.fill", title: L10n("tab.analytics"))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    fabPlaceholderLane

                    HStack(alignment: .bottom, spacing: interItem) {
                        regularItem(tab: 3, systemImage: "calendar.badge.clock", title: L10n("tab.schedule"))
                        regularItem(tab: 4, systemImage: "gearshape.fill", title: L10n("tab.settings"))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .padding(.horizontal, 8)
            // FI-UI-REFINE: Less top inset removes “dead” space above the row; bottom kept slightly larger for optical balance to home indicator.
            .padding(.top, 0)
            .padding(.bottom, 3)
            .frame(minHeight: chromeStripMinHeight)
            .frame(maxWidth: .infinity)
            .background { floatingGlassBarBackground }
            .clipShape(RoundedRectangle(cornerRadius: glassBarCornerRadius, style: .continuous))
            // FI-UI-REFINE: Softer hairline so the edge doesn’t read as a hard rim on very light glass.
            .overlay {
                RoundedRectangle(cornerRadius: glassBarCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            }
            // FI-UI-REFINE: Gentler shadows — float without “thick card” weight.
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 7)
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            .animation(pillAnimation, value: selectedTab)

            addFAB
                .offset(y: -fabVerticalLift)
                .zIndex(2)
        }
        .frame(height: tabBarLayoutHeight)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var floatingGlassBarBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: glassBarCornerRadius, style: .continuous)
                .fill(AppColorTheme.layer2Card.opacity(0.96))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: glassBarCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: glassBarCornerRadius, style: .continuous)
                    .fill(AppColorTheme.customTabBarGlassTint)
            }
        }
    }

    /// Fixed-width lane so the FAB stays visually centered between Analytics and Schedule without shrinking neighbors.
    private var fabPlaceholderLane: some View {
        Color.clear
            .frame(width: fabLaneWidth, height: 1)
            .allowsHitTesting(false)
    }

    /// Uniform, device-aware gaps between adjacent tab slots (and FAB lane).
    private static func interItemSpacing(forBarWidth width: CGFloat) -> CGFloat {
        let scaled = width * 0.021
        return min(14, max(6, scaled))
    }

    private func regularItem(tab: Int, systemImage: String, title: String) -> some View {
        let selected = selectedTab == tab
        return Button {
            triggerRipple(for: tab)
            withAnimation(tabSpring) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(selected ? 1.06 : 1)
                    .offset(y: selected ? -1 : 0)

                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(selected ? AppColorTheme.customTabBarLabelSelected : AppColorTheme.customTabBarInactive)
            .opacity(selected ? 1 : 1)
            // FI-UI-REFINE: ~35% less vertical padding on each tab cell — tighter bar, same tap width via minHeight below.
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: selectionBoxCornerRadius, style: .continuous)
                        .fill(AppColorTheme.customTabBarSelectionFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: selectionBoxCornerRadius, style: .continuous)
                                .strokeBorder(AppColorTheme.customTabBarSelectionStroke, lineWidth: 1)
                        }
                        // FI-UI-REFINE: Lighter selection chip shadow so it doesn’t compete with the bar float.
                        .shadow(color: .black.opacity(0.16), radius: 3, x: 0, y: 1)
                        .matchedGeometryEffect(id: "tabPill", in: pillNamespace)
                        .transition(
                            .asymmetric(
                                insertion: .offset(y: reduceMotion ? -4 : -8).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                }
            }
            .frame(minWidth: 44)
            // FI-UI-REFINE: Slightly shorter min row keeps icons vertically centered in the new chrome height without squishing labels.
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .overlay {
            if lastRippleTab == tab {
                TabBarRippleBurst(
                    color: AppColorTheme.customTabBarAccent,
                    animation: rippleAnimation,
                    compact: reduceMotion
                )
                .id(rippleGeneration)
                .allowsHitTesting(false)
            }
        }
    }

    private var addFAB: some View {
        let selected = selectedTab == 2
        return Button {
            triggerRipple(for: 2)
            withAnimation(fabSpring) {
                selectedTab = 2
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Group {
                        if selected {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppColorTheme.customTabBarAccent,
                                            AppColorTheme.customTabBarAccent.opacity(0.75),
                                            Color(hex: "4A8CC8")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppColorTheme.customTabBarFabInactive,
                                            AppColorTheme.customTabBarFabInactive.opacity(0.88)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .frame(width: 50, height: 50)
                    .shadow(
                        color: selected ? AppColorTheme.customTabBarAccent.opacity(0.65) : .black.opacity(0.45),
                        radius: selected ? 18 : 10,
                        x: 0,
                        y: selected ? 10 : 7
                    )
                    .shadow(color: AppColorTheme.customTabBarAccent.opacity(selected ? 0.35 : 0.18), radius: selected ? 12 : 6, x: 0, y: 0)
                    .overlay {
                        Circle()
                            .stroke(
                                selected ? AppColorTheme.customTabBarAccent.opacity(0.65) : AppColorTheme.customTabBarAccent.opacity(0.35),
                                lineWidth: selected ? 2 : 1.25
                            )
                    }

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(selected ? Color.white : Color.white.opacity(0.92))
                        .rotationEffect(.degrees(selected ? 45 : 0))
                }
                .scaleEffect(selected ? 1.06 : 1)
                .offset(y: selected && !reduceMotion ? -1 : 0)

                Text(L10n("tab.add"))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(selected ? AppColorTheme.customTabBarAccent : AppColorTheme.customTabBarInactive)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(L10n("tab.add"))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(fabSpring, value: selectedTab)
        .overlay {
            if lastRippleTab == 2 {
                TabBarRippleBurst(
                    color: AppColorTheme.customTabBarAccent,
                    animation: rippleAnimation,
                    compact: reduceMotion,
                    stronger: true
                )
                .id(rippleGeneration)
                .allowsHitTesting(false)
            }
        }
    }

    private func triggerRipple(for tab: Int) {
        lastRippleTab = tab
        rippleGeneration += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.12 : 0.4)) {
            if lastRippleTab == tab {
                lastRippleTab = nil
            }
        }
    }
}

// MARK: - Ripple

private struct TabBarRippleBurst: View {
    let color: Color
    let animation: Animation
    var compact: Bool = false
    var stronger: Bool = false

    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(color.opacity(stronger ? 0.65 : 0.5), lineWidth: compact ? 1.2 : 2)
            .frame(width: 28, height: 28)
            .scaleEffect(expanded ? (compact ? 1.55 : (stronger ? 2.65 : 2.35)) : 0.12)
            .opacity(expanded ? 0 : (compact ? 0.45 : 0.7))
            .onAppear {
                expanded = false
                withAnimation(animation) {
                    expanded = true
                }
            }
    }
}
