# Life380 App Store Screenshots

## Captured Screenshots

| # | Screen | File | Status |
|---|--------|------|--------|
| 1 | Map View | `01_map_clean.png` | ✅ Captured |
| 2 | Places | `02_places.png` | ⏳ Capture manually |
| 3 | Insights | `03_insights.png` | ⏳ Capture manually |
| 4 | Circle | `04_circle.png` | ⏳ Capture manually |
| 5 | Settings | `05_settings.png` | ⏳ Capture manually |
| 6 | SOS | `06_sos.png` | ⏳ Capture manually |

## How to Capture Remaining Screenshots

### Step 1: Keep Status Bar Clean
The status bar is already set to 9:41 with full battery/signal.

### Step 2: Navigate in Simulator
1. Open the **Simulator** app on your Mac
2. Tap on each tab at the bottom to navigate:
   - **Places** (pin icon) - Shows saved locations
   - **Insights** (chart icon) - Shows activity dashboard
   - **Circle** (people icon) - Shows family members
   - **Settings** (gear icon) - Shows app settings

### Step 3: Capture Each Screen
After navigating to each screen, run in Terminal:

```bash
# Places tab
xcrun simctl io booted screenshot /Users/marsh/Life380/Screenshots/02_places.png

# Insights tab
xcrun simctl io booted screenshot /Users/marsh/Life380/Screenshots/03_insights.png

# Circle tab
xcrun simctl io booted screenshot /Users/marsh/Life380/Screenshots/04_circle.png

# Settings tab
xcrun simctl io booted screenshot /Users/marsh/Life380/Screenshots/05_settings.png

# SOS (tap SOS button in map view to open sheet)
xcrun simctl io booted screenshot /Users/marsh/Life380/Screenshots/06_sos.png
```

### Step 4: Reset Status Bar (when done)
```bash
xcrun simctl status_bar booted clear
```

## Screenshot Specs

- **Device:** iPhone 17 Pro (simulator)
- **Resolution:** 1179 x 2556 (will need scaling for App Store)
- **Status Bar:** 9:41 AM, Full battery, Full signal

## App Store Required Sizes

For submission, resize screenshots to:
- **6.7" Display:** 1290 x 2796
- **6.5" Display:** 1284 x 2778

Use a tool like:
- Preview (Mac) - Tools → Adjust Size
- Figma/Sketch - For adding device frames
- [AppMockUp](https://app-mockup.com) - Free online tool

## Marketing Text Suggestions

Add these as overlays in your final screenshots:

1. **Map:** "Always know where your family is"
2. **Places:** "Get notified when they arrive safely"
3. **Insights:** "Understand your family's patterns"
4. **Circle:** "Your private family circle"
5. **Settings:** "Privacy you control"
6. **SOS:** "Emergency help, one tap away"
