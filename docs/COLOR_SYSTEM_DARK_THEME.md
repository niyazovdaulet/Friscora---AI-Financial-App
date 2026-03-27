# Friscora – Original (Dark) Theme Color System

Reference of **all colors** used for the dark theme across the project. Use this when defining light-theme equivalents for a smooth transition between themes.

---

## 1. AppColorTheme (Friscora/Helpers/AppColorTheme.swift)

### 1.1 Surface / background (3-layer system)

| Token | Hex | Usage |
|-------|-----|------|
| **layer1Background** | `#000926` | App screen background, safe areas |
| **layer2Card** | `#0B1E3A` | Cards, sections, primary surfaces |
| **layer2Border** | `white` 5% opacity | Card borders |
| **layer3Elevated** | `#0A1628` | Inner/elevated elements inside cards |
| **background** | = layer1Background | Main background (alias) |
| **cardBackground** | = layer2Card | Card/container background |
| **elevatedBackground** | = layer3Elevated | Elevated surfaces |
| **cardBorder** | = layer2Border | Card borders |

### 1.2 Primary palette

| Token | Hex | Usage |
|-------|-----|------|
| **deepNavy** | `#000926` | App background, tab bar |
| **sapphire** | `#0F52BA` | CTAs, balance indicator, secondary |
| **iceBlue** | `#D6E6F3` | textSecondary base |
| **powderBlue** | `#A6C5D7` | textTertiary base |

### 1.3 Accent / semantic

| Token | Hex | Usage |
|-------|-----|------|
| **emeraldGreen** | `#50C878` | Accent, positive, income, tab active |
| **royalAmethyst** | `#0B6E4F` | AI success, goals accent |
| **mintWhisper** | `#D1F2EB` | Goals secondary accent |
| **darkEvergreen** | `#013220` | Charts, growth |
| **accent** | = emeraldGreen | Primary accent |
| **positive** | = emeraldGreen | Income, success |
| **negative** | `#FF6B6B` | Expenses, destructive |
| **negativeMuted** | `#FF8585` | Negative text |
| **warning** | `#E6A23C` | Warnings |
| **goldAccent** | `#D4AF37` | AI/premium, month picker |
| **balanceHighlight** | = sapphire | Balance emphasis |
| **aiSuccess** | = royalAmethyst | AI confirmations |

### 1.4 Neutral grays

| Token | Hex | Usage |
|-------|-----|------|
| **grayLight** | `#0D1B2A` | Subtle backgrounds |
| **grayMedium** | `#8BA0B5` | Secondary text, chart “other” |
| **grayDark** | `#1B3A5C` | Borders, dividers, disabled states |

### 1.5 Indicators

| Token | Hex | Usage |
|-------|-----|------|
| **incomeIndicator** | = emeraldGreen | Income strip/icon |
| **expenseIndicator** | `#FF6B6B` | Expense strip/icon |
| **balanceIndicator** | = sapphire | Balance strip/icon |
| **inactiveIndicator** | `#5A6B7D` | Inactive state |

### 1.6 Tab bar

| Token | Hex | Usage |
|-------|-----|------|
| **tabBarBackground** | = deepNavy | `#000926` |
| **tabActive** | = emeraldGreen | `#50C878` |
| **tabInactive** | `#5A7A99` | Inactive tab icon/text |

### 1.7 Text

| Token | Definition | Usage |
|-------|------------|------|
| **textPrimary** | `Color.white` | Headings, primary content |
| **textSecondary** | iceBlue @ 85% | Subtitle, secondary content |
| **textTertiary** | powderBlue @ 70% | Hints, captions |

### 1.8 CTAs

| Token | Definition | Usage |
|-------|------------|------|
| **ctaPrimary** | = sapphire | Primary buttons |
| **ctaSuccess** | = emeraldGreen | Success actions |
| **ctaDestructive** | `#FF6B6B` | Destructive actions |

### 1.9 Gradients (dark theme)

| Token | Colors | Usage |
|-------|--------|------|
| **primaryGradient** | `#000926` → `#001033` | Depth backgrounds |
| **cardGradient** | sapphire → sapphire 85% | Cards |
| **accentGradient** | emeraldGreen → 80% | Accent buttons |
| **positiveGradient** | emeraldGreen → royalAmethyst | Income |
| **negativeGradient** | negative → negative 70% | Expenses |
| **neutralGradient** | sapphire 60% → grayDark | Neutral states |
| **balanceGradient** | sapphire → `#1A5DC8` | Balance |
| **aiSuccessGradient** | royalAmethyst → darkEvergreen | AI moments |

### 1.10 Goals-specific

| Token | Hex | Usage |
|-------|-----|------|
| **goalsBackground** | `#000D1A` | Goals screen background |
| **goalsAccent** | = emeraldGreen | Goals primary |
| **goalsSecondaryAccent** | = mintWhisper | Goals secondary |
| **goalsCompleted** | powderBlue 60% | Completed state |
| **savingsCardBackground** | `#102A5C` | Savings cards |
| **goalsCardTop** | `#0A3D8F` | Goals card gradient top |
| **goalsCardBottom** | `#083070` | Goals card gradient bottom |

### 1.11 Charts

| Token | Hex | Usage |
|-------|-----|------|
| **chartPrimary** | = darkEvergreen | `#013220` |
| **chartSecondary** | = sapphire | |
| **chartAccent** | = emeraldGreen | |
| **chartBarBackground** | `#1A3A5C` | Bar background |
| **chartBarFill** | `#2E8B9A` | Bar fill, default series |

### 1.12 Other

| Token | Definition | Usage |
|-------|------------|------|
| **rowDivider** | white 6% | List row separators |
| **textOnLight** | = deepNavy | Text on light surfaces (e.g. light mode) |

---

## 2. Inline Color(hex:) usage (views)

### 2.1 DashboardView – category chart colors

| Purpose | Hex |
|--------|-----|
| Food | `#3498DB` |
| Transport | `#2E8B9A` |
| Rent | `#5DADE2` |
| Entertainment | `#48C9B0` |
| Subscriptions | `#76D7C4` |
| Other | uses `AppColorTheme.grayMedium` |

### 2.2 NewJobView / JobDetailView – job color picker

| Label | Hex |
|-------|-----|
| Teal (default) | `#2EC4B6` |
| Blue | `#3B82F6` |
| Purple | `#8B5CF6` |
| Pink | `#EC4899` |
| Amber | `#F59E0B` |
| Green | `#10B981` |
| Red | `#EF4444` |
| Cyan | `#06B6D4` |

---

## 3. Opacity variants used in code

These are applied on top of the tokens above; keep the same logic for light theme where relevant.

- **Card/background opacity**: `0.5`, `0.6`, `0.7`, `0.8`, `0.95`
- **Accent opacity**: `0.1`, `0.12`, `0.15`, `0.2`, `0.3`, `0.4`
- **Negative/positive opacity**: `0.15`, `0.3`, `0.4`, `0.7`
- **grayDark opacity**: `0.3`, `0.5`
- **rowDivider**: white 6%

---

## 4. Summary – hex palette (dark theme)

**Backgrounds:**  
`#000926`, `#0B1E3A`, `#0A1628`, `#0D1B2A`, `#000D1A`, `#102A5C`, `#0A3D8F`, `#083070`, `#1A3A5C`, `#001033`, `#1A5DC8`

**Accent / positive:**  
`#50C878`, `#0B6E4F`, `#D1F2EB`, `#013220`, `#2E8B9A`

**Secondary / UI:**  
`#0F52BA`, `#D6E6F3`, `#A6C5D7`, `#8BA0B5`, `#1B3A5C`, `#5A6B7D`, `#5A7A99`

**Negative / warning:**  
`#FF6B6B`, `#FF8585`, `#E6A23C`

**Special:**  
`#D4AF37` (gold), `#FFFFFF` (text primary, row divider base)

**Category / job colors:**  
`#3498DB`, `#2E8B9A`, `#5DADE2`, `#48C9B0`, `#76D7C4`, `#2EC4B6`, `#3B82F6`, `#8B5CF6`, `#EC4899`, `#F59E0B`, `#10B981`, `#EF4444`, `#06B6D4`

---

Use this list as the single source of truth for the app’s dark theme.
