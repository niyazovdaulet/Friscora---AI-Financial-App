# Friscora 💰

A modern, feature-rich personal finance management iOS app built with SwiftUI. Friscora helps you track expenses, manage income, set financial goals, and get AI-powered financial advice—all in a beautiful, intuitive interface.

![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0-green.svg)
![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)

## 📱 Features

### Core Functionality

- **📊 Dashboard**
  - Real-time financial overview with monthly income, expenses, and remaining balance
  - Spending breakdown by category with visual charts
  - Active goals tracking with progress indicators
  - Recent activity feed
  - Month-by-month navigation with historical data
  - Merge/unmerge past month balances to current month

- **💸 Expense Tracking**
  - Add, edit, and delete expenses
  - Support for standard and custom categories
  - Multi-currency support with automatic conversion
  - Notes and date tracking
  - Edit expenses from any month (past or current)

- **💵 Income Management**
  - Track multiple income sources
  - Monthly income totals
  - Edit incomes from any month
  - Currency support

- **🎯 Financial Goals**
  - Create savings goals with target amounts
  - Track progress with visual indicators
  - Add progress contributions (deducted from balance)
  - Goal completion celebrations
  - Goals integrated with budget calculations
  - Active and completed goals views

- **🔐 Security**
  - Optional passcode authentication
  - Biometric authentication support (Face ID/Touch ID)
  - Auto-lock when app goes to background
  - Secure data storage

- **🤖 AI Financial Adviser**
  - Chat-based financial advice
  - Context-aware recommendations
  - Personalized insights based on your spending patterns

- **🌍 Multi-Currency Support**
  - Support for 50+ currencies
  - Automatic currency conversion
  - Historical currency tracking

- **📈 Advanced Features**
  - Custom expense categories with emoji icons
  - Category spending analysis
  - Balance carryover from previous months
  - Month merging for flexible budget management
  - Comprehensive debug logging

## 🏗️ Architecture

Friscora follows the **MVVM (Model-View-ViewModel)** architecture pattern:

- **Models**: Data structures (`Expense`, `Income`, `Goal`, `UserProfile`, etc.)
- **Views**: SwiftUI views for UI presentation
- **ViewModels**: Business logic and state management
- **Services**: Singleton services for data persistence and business operations

### Key Components

```
Friscora/
├── Models/              # Data models
│   ├── Expense.swift
│   ├── Income.swift
│   ├── Goal.swift
│   ├── CustomCategory.swift
│   └── UserProfile.swift
│
├── Views/               # SwiftUI views
│   ├── DashboardView.swift
│   ├── AddExpenseView.swift
│   ├── GoalsView.swift
│   ├── ChatView.swift
│   ├── ProfileView.swift
│   └── Components/
│
├── ViewModels/          # ViewModels for state management
│   ├── DashboardViewModel.swift
│   ├── ExpenseViewModel.swift
│   ├── IncomeViewModel.swift
│   └── ChatViewModel.swift
│
├── Services/            # Business logic services
│   ├── ExpenseService.swift
│   ├── IncomeService.swift
│   ├── GoalService.swift
│   ├── CurrencyService.swift
│   ├── AuthenticationService.swift
│   └── UserProfileService.swift
│
└── Helpers/             # Utilities and helpers
    ├── AppColorTheme.swift
    ├── CurrencyFormatter.swift
    └── ViewModifiers.swift
```

## 🚀 Getting Started

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

2. Firebase (required for Firebase-backed features): in the [Firebase Console](https://console.firebase.google.com), add an iOS app and download `GoogleService-Info.plist`, or copy `Friscora/GoogleService-Info.plist.example` to `Friscora/GoogleService-Info.plist` and replace the placeholder values with your project’s keys.

3. Open the project in Xcode:
```bash
open Friscora.xcodeproj
```

4. Build and run the project (⌘R)

### First Launch

On first launch, the app will guide you through:
1. **Onboarding**: Set up your initial income
2. **Currency Selection**: Choose your preferred currency
3. **Financial Goal**: Select your primary financial objective
4. **Security**: Optional passcode/biometric setup
5. **Notifications**: Configure reminder preferences

## 💻 Usage

### Adding Expenses

1. Navigate to the **Add** tab
2. Select **Expense** type
3. Enter amount, select category, and add optional note
4. Choose date (can edit past months)
5. Tap **Save Transaction**

### Tracking Income

1. Go to the **Add** tab
2. Select **Income** type
3. Enter amount and optional note
4. Select date
5. Save the transaction

### Creating Goals

1. Navigate to the **Goals** tab
2. Tap the **+** button
3. Enter goal title and target amount
4. Optionally set a deadline
5. Add progress by tapping on a goal and entering amount

### Viewing Dashboard

The Dashboard shows:
- **Monthly Income**: Total income for selected month
- **Total Expenses**: All expenses for the month
- **Remaining Balance**: Income - Expenses - Goal Allocations
- **Spending by Category**: Visual breakdown
- **Allocated Savings**: Active goals and progress
- **Recent Activity**: Latest transactions

### Month Navigation

- Tap the month selector in the top-right
- Select any month from installation date to current
- View historical financial data
- **Merge/Unmerge**: For past months, use the merge button to add that month's balance to the current month

### Custom Categories

1. Go to **Add** tab → **Category** section
2. Tap **Edit** button
3. Create custom categories with emoji icons
4. Custom categories appear in spending breakdown

## 🎨 Design System

Friscora uses a professional dark theme with:
- **Primary Color**: Deep Navy (#0B1F33)
- **Accent Color**: Soft Teal (#2EC4B6)
- **Positive**: Teal (for income)
- **Negative**: Red (for expenses)
- **Balance Highlight**: Soft Blue

The app is designed with:
- Smooth animations and transitions
- Haptic feedback for interactions
- Modern card-based UI
- Intuitive navigation

## 🔧 Technical Details

### Data Persistence

- **UserDefaults**: Used for storing expenses, incomes, goals, and user preferences
- **CoreData**: Prepared for future migration (CoreDataStack included)

### Currency Conversion

- Real-time currency conversion using external API
- Historical currency tracking
- Automatic conversion when viewing multi-currency transactions

### Authentication

- Passcode-based authentication
- Biometric authentication (Face ID/Touch ID)
- Auto-lock on app background
- Secure keychain storage

### Debug Logging

Comprehensive debug prints for:
- Transaction additions/updates/deletions
- Goal progress tracking
- Balance calculations
- Month merging operations
- Financial summaries

View debug output in Xcode console.

## 📊 Financial Calculations

### Remaining Balance Formula

```
Remaining Balance = Monthly Income + Carryover + Merged Balance - Total Expenses - Goal Allocations
```

Where:
- **Monthly Income**: Sum of all income for the month
- **Carryover**: Positive balance from previous month
- **Merged Balance**: Sum of merged past month balances (current month only)
- **Total Expenses**: Sum of all expenses for the month
- **Goal Allocations**: Money allocated to goals (deducted from balance)

### Goal Integration

- Goal progress additions are **deducted** from remaining balance
- Goals appear in Dashboard as "Allocated Savings"
- Goal allocations are included in monthly calculations

## 🛠️ Development

### Project Structure

The project follows a clean architecture with clear separation of concerns:

- **Models**: Pure data structures, Codable for persistence
- **Services**: Singleton services managing business logic and data
- **ViewModels**: ObservableObject classes managing view state
- **Views**: SwiftUI views with minimal logic

### Adding New Features

1. Create model in `Models/` if needed
2. Add service methods in appropriate `Services/` file
3. Create ViewModel if complex state management required
4. Build SwiftUI view in `Views/`
5. Wire up in appropriate tab or navigation

### Debug Mode

The app includes extensive debug logging. To view:
1. Run app in Xcode
2. Open Console (⌘⇧Y)
3. Filter by app name or search for emoji markers:
   - 💰 Expense operations
   - 💵 Income operations
   - 🎯 Goal operations
   - 📊 Financial summaries
   - 🔗 Merge operations

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👤 Author

**Daulet**
- Created: December 28, 2025

## 🙏 Acknowledgments

- Built with SwiftUI and modern iOS development practices
- Uses Combine for reactive programming
- Implements MVVM architecture pattern

## 🔮 Future Enhancements

Potential features for future versions:
- [ ] CoreData migration for better data management
- [ ] Cloud sync across devices
- [ ] Export financial reports (PDF/CSV)
- [ ] Recurring transactions
- [ ] Budget limits and alerts
- [ ] Investment tracking
- [ ] Bill reminders
- [ ] Receipt scanning with OCR
- [ ] Dark/Light mode toggle
- [ ] Widget support

## 📞 Support

For issues, questions, or contributions, please open an issue on the GitHub repository.

---

**Friscora** - Your personal financial companion 💰✨

