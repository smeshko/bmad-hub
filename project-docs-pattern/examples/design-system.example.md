---
title: Design System
description: Design tokens, components, and patterns
author: Design Team
date: 2024-01-08
version: 1.0.0
---

# Design System

Complete design system reference for TaskFlow.

## Design Principles

| Principle | Description |
|-----------|-------------|
| Clarity | Clear visual hierarchy, obvious actions |
| Consistency | Same patterns across all screens |
| Accessibility | WCAG 2.1 AA compliance |
| Performance | Lightweight, fast rendering |

## Color Tokens

### Primary Palette

| Token | Value | Usage |
|-------|-------|-------|
| `--color-primary` | `#2563EB` | Primary actions, links |
| `--color-primary-hover` | `#1D4ED8` | Hover states |
| `--color-primary-light` | `#DBEAFE` | Backgrounds |

### Semantic Colors

| Token | Value | Usage |
|-------|-------|-------|
| `--color-success` | `#16A34A` | Success states |
| `--color-warning` | `#CA8A04` | Warnings |
| `--color-error` | `#DC2626` | Errors |
| `--color-info` | `#0891B2` | Information |

### Neutrals

| Token | Value | Usage |
|-------|-------|-------|
| `--color-gray-900` | `#111827` | Primary text |
| `--color-gray-600` | `#4B5563` | Secondary text |
| `--color-gray-300` | `#D1D5DB` | Borders |
| `--color-gray-100` | `#F3F4F6` | Backgrounds |

## Typography

### Scale

| Token | Size | Weight | Usage |
|-------|------|--------|-------|
| `--text-h1` | 32px | 700 | Page titles |
| `--text-h2` | 24px | 600 | Section headers |
| `--text-h3` | 20px | 600 | Subsections |
| `--text-body` | 16px | 400 | Body text |
| `--text-small` | 14px | 400 | Captions |

### Font Stack

```css
--font-sans: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
--font-mono: 'JetBrains Mono', monospace;
```

## Spacing

Base unit: 4px

| Token | Value | Usage |
|-------|-------|-------|
| `--space-1` | 4px | Tight spacing |
| `--space-2` | 8px | Default gap |
| `--space-4` | 16px | Section spacing |
| `--space-6` | 24px | Large gaps |
| `--space-8` | 32px | Section margins |

## Components

### Button

| Variant | Usage |
|---------|-------|
| Primary | Main actions |
| Secondary | Alternative actions |
| Ghost | Tertiary actions |
| Danger | Destructive actions |

### States

| State | Description |
|-------|-------------|
| Default | Normal appearance |
| Hover | Mouse over |
| Active | Being clicked |
| Disabled | Not interactive |
| Loading | Async operation |

## Shadows

| Token | Value | Usage |
|-------|-------|-------|
| `--shadow-sm` | `0 1px 2px rgba(0,0,0,0.05)` | Cards |
| `--shadow-md` | `0 4px 6px rgba(0,0,0,0.1)` | Dropdowns |
| `--shadow-lg` | `0 10px 15px rgba(0,0,0,0.1)` | Modals |

## Related Documentation

- [UI Components Reference](../reference/ui-components.md)
- [View Template](../templates/view-template.md)
