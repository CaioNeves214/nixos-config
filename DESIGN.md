# Design System Inspired by Nous Portal

> Auto-extracted from `https://portal.nousresearch.com/` on 2026-08-04

## 1. Visual Theme & Atmosphere

Refined dark mode with muted tones — cinematic and premium.

The hero section leads with "Everything to power your Hermes Agent" followed by "Hermes is the agent that grows with you.Nous Portal is the best way to power it, bundling the models".

**Key Characteristics:**
- Sigurd Variable as the heading font (custom web font loaded via @font-face)
- Rules Variable as the body font for all running text
- Heading weight 300, letter-spacing 1.6704px
- Dark background (#0000f2) as the primary canvas
- Primary accent `#575380` used for CTAs and brand highlights
- 5 shadow level(s) detected — standard shadows
- Sharp corners (0-2px) for a precise, technical aesthetic
- Tags: dark, sharp, accented, monospace, serif

## 2. Color Palette & Roles

### Primary
- **Primary Accent** (`#575380`) · `--color-primary`: Brand color, CTA backgrounds, link text, interactive highlights.
- **Background** (`#0000f2`) · `--color-bg`: Page background, primary canvas.
- **Background Secondary** (`#fbfafe`) · `--color-bg-secondary`: Cards, surfaces, alternating sections.

### Text
- **Text Primary** (`#f5f5f5`) · `--color-text`: Headings and body text.
- **Text Secondary** (`#999999`) · `--color-text-secondary`: Muted text, captions, placeholders.

### Borders & Surfaces
- **Border** (`#fbfafe`) · `--color-border`: Dividers, outlines, input borders.

### Full Extracted Palette

| # | Hex | CSS Variable | Role | Area | Contrast |
|---|---|---|---|---|---|
| 1 | `#0000f2` | `--palette-1` | section | large | text-light |
| 2 | `#fbfafe` | `--palette-2` | block | large | text-dark |
| 3 | `#eceaf5` | `--palette-3` | block | medium | text-dark |
| 4 | `#575380` | `--palette-4` | text-accent | small | text-light |

## 3. Typography Rules

- **Heading Font:** `Sigurd Variable` (web font)
- **Body Font:** `Rules Variable` (web font)

### Type Hierarchy

| Role | Font | Size | Weight | Line Height | Letter Spacing |
|---|---|---|---|---|---|
| H1 | Sigurd Variable | 55.68px | 300 | 51.2256px | 1.6704px |
| H2 | Sigurd Variable | 27.84px | 300 | 25.6128px | 0.8352px |
| H3 | Sigurd Variable | 18.56px | 300 | 20.416px | 0.5568px |
| Body | Sigurd Variable | 20.416px | 800 | 20.416px | 1.63328px |
| Code | Rules Variable | 14px | 400 | 21px | normal |

### Type Scale

| Token | Size | Suggested Usage |
|---|---|---|
| Display | `55.68px` | headings |
| H1 | `27.84px` | headings |
| H2 | `20.88px` | headings |
| H3 | `20.416px` | headings |
| H4 | `18.56px` | headings |
| Body L | `16px` | body / supporting text |
| Body | `14px` | body / supporting text |
| Small | `13.5px` | body / supporting text |
| XS | `12.75px` | body / supporting text |
| Caption | `12px` | body / supporting text |

## 4. Component Stylings

### Primary Button

```css
.btn-primary {
  background: #0000f2;
  color: #f5f5f5;
  border-radius: 0px;
  padding: 0px 0px;
  font-size: 14px;
  font-weight: 400;
  border: none;
  cursor: pointer;
}
```

### Ghost Button

```css
.btn-ghost {
  background: transparent;
  color: #f5f5f5;
  border-radius: 0px;
  padding: 5.568px 17.4px;
  font-size: 14px;
  font-weight: 400;
  border: none;
  cursor: pointer;
}
```

### Ghost Button 2

```css
.btn-ghost-2 {
  background: transparent;
  color: #0000f2;
  border-radius: 0px;
  padding: 8.12px 12.76px;
  font-size: 10.44px;
  font-weight: 400;
  border: none;
  cursor: pointer;
}
```

## 5. Layout Principles

- **Base spacing unit:** `3.5px` — use multiples (7px, 10.5px, 14px, etc.)

### Spacing Scale (extracted from real elements)

| Token | Value | Role |
|---|---|---|
| spacing-1 | `3.5px` | element |
| spacing-2 | `3.48px` | element |
| spacing-3 | `9.28px` | element |
| spacing-4 | `5.568px` | element |
| spacing-5 | `13.92px` | element |
| spacing-6 | `6.96px` | element |
| spacing-7 | `7px` | element |
| spacing-8 | `17.4px` | element |

### Border Radius Scale

| Token | Value | Element |
|---|---|---|

## 6. Depth & Elevation

| Level | Shadow | Usage |
|---|---|---|
| Low | `rgb(0, 0, 242) 2px 0px 0px 0px, rgb(0, 0, 242) -2px 0px 0px 0px, rgb(0, 0, 242) ...` | Cards, subtle elevation |
| Low | `color(srgb 0.960784 0.960784 0.960784 / 0.2) 2px 0px 0px 0px, color(srgb 0.96078...` | Cards, subtle elevation |
| Low | `rgb(245, 245, 245) 2px 0px 0px 0px, rgb(245, 245, 245) -2px 0px 0px 0px, rgb(245...` | Cards, subtle elevation |
| Low | `rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0...` | Cards, subtle elevation |
| Low | `color(srgb 0 0 0.94902 / 0.2) 2px 0px 0px 0px, color(srgb 0 0 0.94902 / 0.2) -2p...` | Cards, subtle elevation |


## 7. Do's and Don'ts

### Do
- Use `#0000f2` as the primary background color
- Use `Sigurd Variable` for all headings and `Rules Variable` for body text
- Use `#575380` as the single dominant accent/CTA color
- Maintain `3.5px` as the base spacing unit — all gaps should be multiples
- Keep the overall feel dark — use dark surfaces throughout
- Keep corners sharp (0-2px radius) for a precise, technical feel
- Use serif fonts for headlines to maintain editorial authority
- Apply the shadow system for elevation — use the extracted shadow values
- Use weight 300 for headings to match the brand's typographic voice

### Don't
- Don't use colors outside the extracted palette without justification
- Don't substitute Sigurd Variable/Rules Variable with generic alternatives
- Don't use irregular spacing — stick to 3.5px grid
- Don't introduce bright white surfaces — they break the dark palette
- Don't use large border-radius — keep everything crisp and geometric
- Don't mix in geometric sans-serif headlines — it breaks the editorial tone
- Don't use pure black (#000000) for text — use `#f5f5f5` instead
- Don't add decorative elements not present in the original design — no badges, ribbons, banners, or ornaments unless the source site uses them
- Don't invent UI patterns the source site doesn't have — if the original has no NEW badge, don't add one just because a red is in the palette

## 8. Responsive Behavior

| Breakpoint | Width | Notes |
|---|---|---|
| Mobile | < 640px | Single column, stack sections, reduce font sizes ~80% |
| Tablet | 640–1024px | 2-column where appropriate, maintain spacing ratios |
| Desktop | 1024–1440px | Full layout as designed |
| Wide | > 1440px | Max-width container, center content |

- Touch targets: minimum 44×44px on mobile
- Maintain 3.5px base unit across breakpoints — only scale multipliers

## 9. Agent Prompt Guide

### Quick Color Reference

```
Background:  #0000f2
Text:        #f5f5f5
Accent:      #575380
Border:      #fbfafe
```

### Example Prompts

1. "Build a hero section with a `#0000f2` background, `Sigurd Variable` heading in `#f5f5f5`, and a `#575380` CTA button with 0px radius."
2. "Create a pricing card using background `#fbfafe`, border `#fbfafe`, `Rules Variable` for text, and 10.5px padding."
3. "Design a navigation bar — `#0000f2` background, `#f5f5f5` links, `#575380` for active state."
4. "Build a feature grid with 3 columns, 10.5px gap, each card using the card component style."
5. "Create a footer with `#fbfafe` background, `#f5f5f5` text, and 7px padding."

### Iteration Guide

1. Start with layout structure (sections, grid, spacing)
2. Apply colors from the palette — background first, then text, then accents
3. Set typography — font families, sizes from the type scale, weights
4. Add components — buttons, cards, inputs using the specs above
5. Apply border-radius consistently across all elements
6. Add shadows for depth — use the extracted shadow values, not defaults
7. Check responsive behavior — test mobile and tablet layouts
8. Final pass — verify all colors match, spacing is consistent, fonts are correct

## 10. CSS Custom Properties

> 294 custom properties extracted from `:root` / `html` stylesheets.

### Color Variables

| Variable | Value |
|---|---|
| `--gray-50` | `#f9fafb` |
| `--gray-100` | `#f3f4f6` |
| `--gray-200` | `#e5e7eb` |
| `--gray-300` | `#d1d5db` |
| `--gray-400` | `#9ca3af` |
| `--gray-500` | `#6b7280` |
| `--gray-600` | `#4b5563` |
| `--gray-700` | `#374151` |
| `--gray-800` | `#1f2937` |
| `--gray-900` | `#111827` |
| `--red-50` | `#fdf2f2` |
| `--red-100` | `#fde8e8` |
| `--red-200` | `#fbd5d5` |
| `--red-300` | `#f8b4b4` |
| `--red-400` | `#f98080` |
| `--red-500` | `#f05252` |
| `--red-600` | `#e02424` |
| `--red-700` | `#c81e1e` |
| `--red-800` | `#9b1c1c` |
| `--red-900` | `#771d1d` |
| `--orange-50` | `#fff8f1` |
| `--orange-100` | `#feecdc` |
| `--orange-200` | `#fcd9bd` |
| `--orange-300` | `#fdba8c` |
| `--orange-400` | `#ff8a4c` |
| `--orange-500` | `#ff5a1f` |
| `--orange-600` | `#d03801` |
| `--orange-700` | `#b43403` |
| `--orange-800` | `#8a2c0d` |
| `--orange-900` | `#771d1d` |
| ... | *(169 more)* |

### Spacing Variables

| Variable | Value |
|---|---|
| `--background-alpha` | `1` |
| `--midground-alpha` | `1` |
| `--foreground-alpha` | `1` |
| `--space-2xs` | `.125rem` |
| `--space-xs` | `.25rem` |
| `--space-s` | `.5rem` |
| `--space-m` | `.5rem` |
| `--space-l` | `.75rem` |
| `--space-xl` | `.75rem` |
| `--space-2xl` | `1rem` |
| `--space-3xl` | `1.5rem` |
| `--space-4xl` | `2rem` |
| `--space-5xl` | `2.5rem` |
| `--space-section-h` | `.75rem` |
| `--space-section-white` | `.5rem` |
| `--space-section-v` | `3.5rem` |
| `--type-h1-size` | `3.25rem` |
| `--type-h1-line` | `3.5rem` |
| `--type-h1-tracking` | `.03em` |
| `--type-h2-size` | `2.625rem` |
| ... | *(27 more)* |

### Typography Variables

| Variable | Value |
|---|---|
| `--font-display` | `"Sigurd Variable", "Times New Roman", serif` |
| `--font-body` | `"Rules Variable", sans-serif` |
| `--font-ui` | `var(--font-body)` |
| `--font-mono` | `"Courier Prime", "Courier New", monospace` |
| `--font-sigurd` | `var(--font-display)` |
| `--font-rules` | `var(--font-body)` |
| `--font-sans` | `var(--font-body)` |
| `--text-primary` | `var(--hermes-fg)` |
| `--text-secondary` | `var(--hermes-fg-secondary)` |
| `--text-tertiary` | `var(--hermes-white-60)` |
| `--text-disabled` | `var(--hermes-white-60)` |
| `--text-on-accent` | `var(--hermes-primary)` |

### Other Variables

| Variable | Value |
|---|---|
| `--hermes-primary-80` | `var(--hermes-primary)` |
| `--hermes-primary-20` | `var(--hermes-primary)` |
| `--hermes-white-90` | `var(--hermes-white)` |
| `--hermes-white-60` | `var(--hermes-white)` |
| `--hermes-white-20` | `var(--hermes-white)` |
| `--hermes-bg` | `var(--hermes-primary)` |
| `--hermes-bg-primary` | `var(--hermes-white)` |
| `--hermes-bg-primary-pressed` | `var(--hermes-white-20)` |
| `--hermes-bg-secondary` | `var(--hermes-white-20)` |
| `--hermes-bg-ghost` | `transparent` |
| `--hermes-bg-pressed` | `var(--hermes-bg-secondary)` |
| `--hermes-bg-card` | `var(--hermes-grey-50)` |
| `--hermes-fg` | `var(--hermes-white)` |
| `--hermes-fg-secondary` | `var(--hermes-white-60)` |
| `--hermes-fg-on-primary` | `var(--hermes-primary)` |
| ... | *(21 more)* |
