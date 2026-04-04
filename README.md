# Friscora 💰

A modern, feature-rich personal finance management iOS app built with SwiftUI. Friscora helps you track expenses and income, plan work shifts and pay, set financial goals, and get AI-powered financial advice—all in a cohesive dark-themed interface.

![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0-green.svg)
![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)

## 📱 Features

### Navigation (main tabs)

- **Dashboard** — Monthly overview, categories, goals entry points, history, and AI adviser
- **Analytics** — Period controls, spending charts, category detail, savings insights, and trends
- **Add** — Expenses and income with categories, notes, dates, and multi-currency support
- **Schedule** — Work jobs, calendar of shifts, optional personal events, salary projection, and work settings
- **Settings (Profile)** — Profile, security, language, notifications, and app preferences

### Core functionality

- **📊 Dashboard**
  - Real-time financial overview: monthly income, expenses, and remaining balance
  - Spending breakdown by category with charts
  - Active goals with progress; navigation to full **Goals** screen
  - **History** (full transaction list) and **AI Financial Adviser** chat available from the dashboard
  - Month-by-month navigation with historical data
  - Merge/unmerge past month balances into the current month

- **📈 Analytics**
  - Month (or range) aligned with the rest of the app
  - Primary category spending visualization and insights
  - Income split views and trend context where applicable

- **💸 Expense tracking**
  - Add, edit, and delete expenses
  - Standard and **custom categories** (icons/colors, ordering, and editing flows)
  - Multi-currency support with conversion
  - Notes and date tracking; edit transactions for any month

- **💵 Income management**
  - Multiple income sources and monthly totals
  - Edit incomes for any month; currency support

- **📅 Work schedule**
  - Multiple jobs and work-day logging on a calendar
  - **Personal schedule events** alongside work data where supported
  - Salary projection and sync-related helpers for pay expectations
  - Toolbar access to job/work settings

- **🎯 Financial goals**
  - Create goals with target amounts; track progress and contributions
  - Goal completion flow; integration with budget/balance logic
  - Open **Goals** from the Dashboard (not a separate tab)

- **🔐 Security**
  - Optional passcode and biometric authentication (Face ID / Touch ID)
  - Auto-lock when the app leaves the foreground
  - Secure storage for sensitive settings

- **🤖 AI financial adviser**
  - Chat-based guidance with context from your data (via the Dashboard entry point)

- **🌍 Localization**
  - English, Kazakh, Polish, and Russian strings (`en`, `kk`, `pl`, `ru`)

- **🌍 Multi-currency**
  - Broad currency support, conversion, and historical handling where used in the app

- **☁️ iCloud (Key-Value)**
  - Optional sync of UserDefaults-backed data across devices signed into the same iCloud account (requires the iCloud capability in Xcode)

## 🏗️ Architecture

Friscora uses **MVVM** (Model-View-ViewModel):

- **Models** — `Expense`, `Income`, `Goal`, `CustomCategory`, `UserProfile`, work schedule types (`Job`, `WorkDay`, `PersonalScheduleEvent`, etc.)
- **Views** — SwiftUI; main flows in `DashboardView`, `AnalyticsView`, `AddExpenseView`, `WorkScheduleView` (`ScheduleView`), `ProfileView`, plus `GoalsView`, `HistoryView`, `ChatView`, and shared components
- **ViewModels** — Observable state for dashboard, analytics, expenses, income, chat, onboarding, and work schedule
- **Services** — Singletons for persistence, currency, auth, goals, custom categories, iCloud sync, salary/work schedule, and AI context

### Project layout (high level)

```
Friscora/
├── Models/
├── Views/
│   ├── Components/
│   ├── DashboardView.swift
│   ├── AnalyticsView.swift
│   ├── AddExpenseView.swift
│   ├── WorkScheduleView.swift      # Schedule tab (ScheduleView)
│   ├── GoalsView.swift
│   ├── HistoryView.swift
│   ├── ChatView.swift
│   ├── ProfileView.swift
│   └── ...
├── ViewModels/
├── Services/
├── Helpers/
├── Persistence/
└── *.lproj/Localizable.strings
```

## 🚀 Getting started

### Prerequisites

- Xcode 14.0 or later  
- iOS 15.0 or later  
- Swift 5.0 or later  

### Installation

1. Clone the repository:

```bash
git clone https://github.com/niyazovdaulet/Friscora---AI-Financial-App.git
cd Friscora---AI-Financial-App
```

2. **Firebase** (if you use Firebase-backed features): in the [Firebase Console](https://console.firebase.google.com), add an iOS app and download `GoogleService-Info.plist`, or copy `Friscora/GoogleService-Info.plist.example` to `Friscora/GoogleService-Info.plist` and fill in your project keys.

3. **iCloud** (optional): enable iCloud and Key-Value storage (or as documented in your capabilities) for the app target so `ICloudSyncService` can sync.

4. Open the Xcode project:

```bash
open Friscora.xcodeproj
```

5. Build and run (⌘R).

### First launch

On first launch you are guided through onboarding (income, currency, goals, optional security, notifications, etc.).

## 💻 Usage

### Adding expenses or income

1. Open the **Add** tab.  
2. Choose expense or income, enter amount, category (and note if needed).  
3. Pick the date (including past months) and save.

### Goals

Open **Goals** from the **Dashboard** (links and shortcuts there). Create goals, track progress, and record contributions from that screen.

### History and AI chat

From the **Dashboard**, open **History** for a full list of transactions, or the **AI** flow for chat-based advice.

### Analytics

Use the **Analytics** tab to change the month, explore category spending, and read insights for the selected period.

### Schedule (work & personal)

Use the **Schedule** tab to add jobs, log work days on the calendar, review projections, and adjust work settings from the toolbar. Personal events can appear in the same calendar flow where enabled.

### Custom categories

From the **Add** flow, use the category editor to create and manage custom categories (appearance and order are persisted with the rest of your data).

### Month navigation (Dashboard)

Use the month control to move between months. For past months, merge or unmerge balances into the current month when you need a combined view.

## 🎨 Design system

Friscora uses a dark-first theme (see `AppColorTheme` and design helpers): deep navy base, teal accent, clear positive/negative semantics, cards, haptics, and shared motion via `AppAnimation`.

## 🔧 Technical details

### Data persistence

- **UserDefaults** — Primary store for expenses, incomes, goals, profile, work schedule data, and related preferences  
- **iCloud Key-Value** — Optional cross-device sync via `ICloudSyncService` (last-write-wins)  
- **Core Data** — Stack present for future or auxiliary use; check the project for current wiring  

### Currency

Conversion and formatting are handled through dedicated services and formatters (`CurrencyService`, `CurrencyFormatter`, etc.).

### Authentication

Passcode and biometrics with auto-lock; secure storage for secrets.

### Debug logging

Verbose logging is available in development builds—use the Xcode console while debugging.

## 📊 Financial calculations (summary)

Remaining balance reflects monthly income, carryover, merged past balances, expenses, and goal allocations. Goal contributions reduce available balance as implemented in `DashboardViewModel` and related services.

## 🛠️ Development

- **Models** — Prefer `Codable` (and existing coding patterns) for anything persisted.  
- **New features** — Add models, extend services, introduce a ViewModel when state is non-trivial, then compose SwiftUI views and wire tabs or navigation from existing entry points.  

## 📝 License

This project is licensed under the MIT License—see the LICENSE file.

## 👤 Author

**Daulet** — Created December 28, 2025.

## 🙏 Acknowledgments

Built with SwiftUI, Combine, and MVVM-oriented structure.

## 🔮 Possible future enhancements

- Deeper Core Data or CloudKit integration beyond Key-Value sync  
- Export (PDF/CSV), recurring transactions, budgets/alerts  
- Widgets, alternate themes, richer receipt capture  

## 📞 Support

For issues or contributions, open an issue on the [GitHub repository](https://github.com/niyazovdaulet/Friscora---AI-Financial-App).

---

**Friscora** — Your personal financial companion 💰✨
