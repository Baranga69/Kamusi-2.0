# Kamusi 2.0 — Design System

> This document defines the visual and interaction language of Kamusi 2.0.
> It is a contract, not a suggestion.

Last updated: 2026-01-12

---

## 1. Design Philosophy

Kamusi is a **dictionary meant to be read**, not scanned.

The UI must feel:
- Calm
- Scholarly
- Trustworthy
- Modern
- Subtly African (not decorative, not stereotypical)

Primary principle:
> **Reading comfort > visual flair**

Avoid:
- Loud or playful aesthetics
- Harsh black-on-white contrast
- Dense layouts
- Heavy borders
- Overuse of bold or color

---

## 2. Material 3 Foundation

Kamusi uses **Material 3** as its base system.

Rules:
- `useMaterial3 = true` everywhere
- Prefer Material components over custom ones
- Extend Material theming instead of bypassing it

Allowed:
- FilledButton
- FilledTonalButton
- TextButton
- Cards with tonal surfaces
- Chips / pills for POS, tags

Discouraged:
- Custom shadows
- Excessive elevation
- Custom gesture systems

---

## 3. Color System

### Color Philosophy
- Neutral surfaces matter more than accent colors
- Color conveys meaning, not decoration
- Contrast should be soft but accessible

### Brand Colors

**Primary (Brand Anchor)**
- Deep Indigo / Blue-Gray  
  `#3A4A6B`

**Secondary (Accent)**
- Muted Teal  
  `#4F8F8B`

**Error**
- `#B42318` (used sparingly)

---

### Neutral Surfaces

| Role | Color |
|----|----|
| background | `#FDFDFE` |
| surface | `#F7F8FA` |
| surfaceVariant | `#E9EBF0` |

---

### Text Colors

| Role | Color |
|----|----|
| onSurface | `#1F2937` (soft charcoal) |
| onSurfaceVariant | `#4B5563` |

Rules:
- Avoid pure black unless required for accessibility
- Secondary text should never compete with primary content

---

### Implementation Rule

All colors must come from:
- `ColorScheme.fromSeed(seedColor: #3A4A6B)`
- Or named roles in ThemeData

❌ No hardcoded widget colors  
❌ No random hex values in UI code  

---

## 4. Typography System

### Typography Philosophy
- Dictionaries are read slowly
- Definitions deserve space and rhythm
- Hierarchy must be clear without shouting

---

### Font Families (max 2)

Primary (Content):
- **Source Serif 4** or **Noto Serif**
- Used for:
  - Lemmas
  - Definitions
  - Long-form content

Secondary (UI chrome):
- **Inter** or **Roboto Flex**
- Used for:
  - Buttons
  - Labels
  - Navigation
  - Metadata

---

### Type Scale (Material 3 aligned)

#### Lemma (Headword)
- `displaySmall` or `headlineMedium`
- Weight: `w600`
- Letter spacing: `-0.5`

#### Part of Speech
- `labelLarge`
- Weight: `w500`
- Color: `onSurfaceVariant`

#### Definitions (Most important text)
- `bodyLarge`
- Size: 16–17
- Line height: 1.45–1.6
- Weight: `w400`

#### Examples / Usage
- `bodyMedium`
- Italic allowed
- Color: `onSurfaceVariant`

#### Search Results
- Lemma: `titleMedium`
- Preview/POS: `bodySmall`

---

### Typography Anti-Rules

❌ No ALL CAPS UI text  
❌ No bold paragraphs  
❌ No fontSize < 13 for readable content  
❌ No more than 2 font families  

---

## 5. Layout & Spacing

### Spacing Guidelines

| Use | Size |
|----|----|
| Page padding | 16–20dp |
| Section spacing | 24–32dp |
| Item spacing | 12–16dp |

Whitespace is preferred over dividers.

---

### Shapes

- Cards: 16dp radius
- Chips / pills: 20dp+ radius
- Inputs: rounded, soft outlines

---

### Dividers

- Use sparingly
- 1dp
- Color: surfaceVariant or outlineVariant

---

## 6. Interaction & States

- All tappable elements must have Material ripple feedback
- Empty states should be calm and explanatory
- Loading states should be skeletons or subtle indicators
- Error states should not be alarming unless critical

---

## 7. Accessibility

- Maintain readable contrast
- Support system font scaling
- Avoid color-only meaning
- Ensure touch targets ≥ 44dp

---

## 8. Non-Negotiables

- This design system applies to **mobile and admin**
- No “one-off” visual decisions
- If it feels loud, it’s wrong
- If it’s hard to read, it’s wrong

---

End of document.