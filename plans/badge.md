# Badge System Implementation Plan

## Overview
Add a badge system that displays unique icons on calendar dates based on whether users answered the experiment name question correctly (green) or incorrectly (red), with single-attempt enforcement.

## Files to Modify

| File | Changes |
|------|---------|
| `Psychly/Experiment.swift` | Add `badgeIcon` property |
| `Psychly/UserStatsManager.swift` | Add answer persistence (correct/incorrect state per date) |
| `Psychly/CalendarManager.swift` | Load badge icons for experiments |
| `Psychly/CalendarView.swift` | Update `DayCell` to show badge overlay with color |
| `Psychly/ExperimentView.swift` | Use persisted answer state, prevent re-answering |
| `Psychly/ExperimentManager.swift` | Generate unique badge when creating new experiments |
| `Psychly/GeminiService.swift` | Add experiment categorization for badge selection |

## Implementation Steps

### Step 1: Extend Experiment Model
**File:** `Psychly/Experiment.swift`
- Add optional `badgeIcon: String?` property (SF Symbol name)
- Add optional `badgeCategory: String?` property

### Step 2: Add Answer Persistence to UserStatsManager
**File:** `Psychly/UserStatsManager.swift`
- Add `@Published var answers: [String: UserAnswer]` dictionary (date string → answer)
- Create `UserAnswer` struct with: `correct: Bool`, `guess: String`, `timestamp: Date`
- Add `hasAnswered(for date: Date) -> Bool`
- Add `getAnswer(for date: Date) -> UserAnswer?`
- Add `recordAnswer(for date: Date, correct: Bool, guess: String)` - saves to Firestore
- Modify `loadStats()` to load answers from Firestore

**Firestore structure:**
```
userStats/{userId}
  - viewedDates: [String]
  - answers: {
      "2026-01-25": { correct: true, guess: "...", timestamp: ... }
    }
```

### Step 3: Add Badge Generation with Uniqueness
**File:** `Psychly/GeminiService.swift`
- Add `categorizeExperiment(name: String, info: String) -> String` method
- Use Gemini to categorize into: social, cognitive, behavioral, memory, obedience, conformity, etc.

**File:** `Psychly/ExperimentManager.swift`
- Maintain a pool of available SF Symbols (50+ icons to ensure uniqueness)
- When creating new experiment:
  1. Fetch all existing experiments to get list of already-used badge icons
  2. Filter the icon pool to exclude used icons
  3. Use Gemini categorization to pick the most appropriate unused icon
  4. If no category-specific icon available, pick any unused icon
- Save the unique badge icon with the experiment

**SF Symbol Pool (organized by category, but any can be used):**
```swift
let iconPool: [String: [String]] = [
    "social": ["person.2.fill", "person.3.fill", "figure.2", "person.wave.2.fill"],
    "cognitive": ["brain.head.profile", "brain", "lightbulb.fill", "puzzlepiece.fill"],
    "behavioral": ["pawprint.fill", "bell.fill", "arrow.triangle.branch", "repeat"],
    "memory": ["memorychip", "doc.text.fill", "list.clipboard.fill", "tray.full.fill"],
    "emotional": ["heart.fill", "face.smiling.fill", "bolt.heart.fill", "heart.circle.fill"],
    "developmental": ["figure.and.child.holdinghands", "figure.2.and.child.holdinghands", "leaf.fill"],
    "perception": ["eye.fill", "ear.fill", "hand.raised.fill", "camera.metering.spot"],
    "obedience": ["figure.stand.line.dotted.figure.stand", "hand.raised.slash.fill", "exclamationmark.triangle.fill"],
    "conformity": ["person.3.sequence.fill", "arrow.left.arrow.right", "equal.circle.fill"],
    "learning": ["book.fill", "graduationcap.fill", "pencil.and.outline", "text.book.closed.fill"],
    "aggression": ["bolt.fill", "flame.fill", "burst.fill", "waveform.path.ecg"],
    "attachment": ["heart.circle.fill", "link.circle.fill", "figure.2.arms.open"],
    "motivation": ["flag.fill", "star.fill", "trophy.fill", "target"],
    "stress": ["waveform.path.ecg.rectangle.fill", "exclamationmark.circle.fill", "cloud.bolt.fill"],
    "default": ["flask.fill", "testtube.2", "atom", "sparkles", "questionmark.circle.fill"]
]
```

### Step 4: Update CalendarManager
**File:** `Psychly/CalendarManager.swift`
- Add `@Published var experimentBadges: [String: String]` (date → icon)
- In `loadExperimentDates()`, also load `badgeIcon` from each experiment document
- Add `getBadgeIcon(for date: Date) -> String?`
- Add `getUsedBadgeIcons() -> Set<String>` for uniqueness checking

### Step 5: Update CalendarView with Badge Display
**File:** `Psychly/CalendarView.swift`
- Add `@StateObject private var userStatsManager = UserStatsManager()`
- In grid loop, get `answer = userStatsManager.getAnswer(for: date)` and `badgeIcon = calendarManager.getBadgeIcon(for: date)`
- Pass to `DayCell`: `badgeIcon: String?`, `answerState: Bool?`

**Update `DayCell`:**
- Add parameters: `badgeIcon: String?`, `answerState: Bool?`
- Add computed `badgeColor`: green if correct, red if incorrect
- Wrap in `ZStack`, add badge overlay in bottom-right corner:
```swift
if let icon = badgeIcon, answerState != nil {
    Image(systemName: icon)
        .foregroundStyle(.white)
        .padding(4)
        .background(Circle().fill(badgeColor))
        .offset(x: 8, y: 8)
}
```

### Step 6: Update ExperimentView for Single-Attempt
**File:** `Psychly/ExperimentView.swift`
- Add `@StateObject private var userStatsManager = UserStatsManager()`
- Replace `@State private var hasSubmittedGuess` with computed property: `userStatsManager.hasAnswered(for: date)`
- Replace `@State private var guessWasCorrect` with computed: `userStatsManager.getAnswer(for: date)?.correct`
- In submit action, call `userStatsManager.recordAnswer(for: date, correct: result.isCorrect, guess: userGuess)`
- Show previous guess text when already answered

### Step 7: Migration for Existing Experiments
**File:** `Psychly/ExperimentManager.swift`
- In `loadExperiment()`, check if `badgeIcon` is nil
- If nil, generate a unique badge (excluding already-used icons) and update Firestore document

## Badge Uniqueness Logic

```swift
func selectUniqueBadgeIcon(category: String, usedIcons: Set<String>) -> String {
    // 1. Try category-specific icons first
    if let categoryIcons = iconPool[category] {
        if let available = categoryIcons.first(where: { !usedIcons.contains($0) }) {
            return available
        }
    }

    // 2. Fall back to any unused icon from any category
    for (_, icons) in iconPool {
        if let available = icons.first(where: { !usedIcons.contains($0) }) {
            return available
        }
    }

    // 3. Last resort: use a generic icon (shouldn't happen with 50+ icons)
    return "circle.fill"
}
```

## Verification
1. Create a new experiment → verify unique badge icon is generated and stored
2. Create multiple experiments → verify each has a different badge icon
3. Answer correctly → verify green badge appears on calendar date
4. Answer incorrectly → verify red badge appears on calendar date
5. Close and reopen app → verify answer state persists (can't re-answer)
6. View past experiment → verify badge shows with correct color
7. Check Firestore → verify `answers` field in userStats document
8. Check Firestore → verify no duplicate `badgeIcon` values across experiments
