# Kamusi 2.0 — Design System

> This document defines the visual and interaction language of Kamusi 2.0.
> It is binding on the surfaces it covers, and it says which surface it is
> talking about.

Last updated: 2026-10-10

---

## 0. Two surfaces

Kamusi does two different jobs, and one visual language cannot serve both.

| Surface | What it is | How it behaves |
| --- | --- | --- |
| **Dictionary** | Search, results, entry and expression detail, home | Calm. Sections 1–7 below. |
| **Jifunze (Learn)** | Daily challenge, practice rounds, progress | Warm and responsive. Section 9. |

The dictionary is where trust lives: somebody checking what a word means
needs to believe what they read, and nothing undermines that faster than an
interface that feels like a game. Jifunze is where motivation lives, and a
learning tool nobody enjoys returning to teaches nobody.

Rules that belong to one surface say so. Everything in sections 2–7
(Material 3, colour sourcing, type scale, spacing, accessibility) applies to
both — they are about craft, not mood.

**The dividing line:** a game is a place you choose to go. Looking a word up
must never be interrupted by one.

---

## 1. Design Philosophy (dictionary surface)

Kamusi is a **dictionary meant to be read**, not scanned.

The reading surface must feel:
- Calm
- Scholarly
- Trustworthy
- Modern
- Subtly African (not decorative, not stereotypical)

Primary principle:
> **Reading comfort > visual flair**

Avoid, on the reading surface:
- Playful or attention-seeking treatments
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
- No “one-off” visual decisions — if a surface needs different rules, it gets
  a section here, like Jifunze did
- On the reading surface: if it feels loud, it’s wrong
- Anywhere: if it’s hard to read, it’s wrong
- Colour is never the only carrier of meaning, on any surface

---

## 9. Jifunze (Learn) surface

Learning needs feedback, momentum and a reason to come back tomorrow. This
surface is allowed what the dictionary is not — but it is still Kamusi, so
the licence has limits.

### Allowed here

- **Motion with a job.** A progress bar filling, a new question sliding in, a
  score ring growing on completion. Each one tells you something changed.
- **Semantic colour.** Right and wrong need to read instantly, which the
  reading palette has no role for. Use `KamusiLearnColors`
  (`lib/ui/theme/kamusi_learn_colors.dart`), registered as a `ThemeExtension`
  — never raw hex in a widget.
- **One gradient.** Reserved for the daily challenge card, so the single most
  important thing to do today looks like it.
- **Haptics.** A light tap for correct, a firmer one for incorrect. The result
  arrives before the eye has read the colour.
- **Warmth in the copy.** “Zote sawa” beats “5/5 correct”.

### Not allowed, even here

- **Punishment.** No lives, no timers, no streak-loss warnings. A wrong answer
  reveals the right one and moves on; the round cannot be failed.
- **Slot-machine reward.** One restrained celebration on completion, not
  confetti on every correct answer. The greens are muted on purpose.
- **Colour alone.** Every correct/incorrect state carries an icon too.
- **Leaking into the dictionary.** No streak nags on the entry screen, no
  "quiz me" buttons interrupting a definition.
- **Unreviewed content.** `/learn` serves published entries only, and an AI
  Swahili definition must have cleared review. A game is a worse place than
  most to teach something wrong.

### Semantic colours

| Role | Means |
| --- | --- |
| `correct` / `correctContainer` | A right answer. Muted green: approval, not fireworks. |
| `incorrect` / `incorrectContainer` | A wrong answer. Warm amber, **not** the error red — being wrong while learning is information, not a fault. |
| `streak` | The streak flame. The one genuinely bright accent in the app. |
| `progressTrack` | The unfilled part of a progress bar. |

### Type on this surface

The type scale in section 4 still holds. A prompt that is a definition or a
proverb is content and takes the serif; a bare headword is a label and stays
in the UI face. Options that are definitions take the serif too — they are
the thing being read.

---

End of document.