# Life380 App Store Screenshots Guide

## Required Screenshot Sizes

| Device | Size (pixels) | Required |
|--------|---------------|----------|
| iPhone 6.7" (15 Pro Max) | 1290 x 2796 | Yes |
| iPhone 6.5" (14 Plus) | 1284 x 2778 | Yes |
| iPhone 5.5" (8 Plus) | 1242 x 2208 | Optional |
| iPad Pro 12.9" | 2048 x 2732 | If supporting iPad |

## Screenshot Content Plan

### Screenshot 1: Map View (Hero Shot)
**Focus:** Family members visible on map
**Elements to show:**
- Map with 2-3 family member markers
- Precision badge showing "Precise"
- SOS button visible
- Clean navigation bar

**Marketing text overlay:**
```
"Always know where your family is"
```

### Screenshot 2: Places & Geofencing
**Focus:** Saved places with notifications
**Elements to show:**
- List of places (Home, Work, School)
- Place icons and colors
- Notification bell indicators

**Marketing text overlay:**
```
"Get notified when they arrive safely"
```

### Screenshot 3: Smart ETAs
**Focus:** Member detail card with ETA
**Elements to show:**
- Member selected on map
- ETA card showing arrival time
- Distance and travel mode

**Marketing text overlay:**
```
"Know when they'll be home"
```

### Screenshot 4: SOS Emergency
**Focus:** SOS feature
**Elements to show:**
- SOS button prominently displayed
- Or active SOS state with pulsing animation

**Marketing text overlay:**
```
"Emergency help when you need it"
```

### Screenshot 5: Insights Dashboard
**Focus:** Activity insights
**Elements to show:**
- Time at places chart
- Weekly activity bars
- Travel statistics

**Marketing text overlay:**
```
"Understand your family's patterns"
```

### Screenshot 6: Family Circle
**Focus:** Circle management
**Elements to show:**
- Circle name and invite code
- List of family members
- Battery levels visible

**Marketing text overlay:**
```
"Your private family circle"
```

---

## How to Capture Clean Screenshots

### Option 1: Simulator with Status Bar Override
```bash
# Set clean status bar (9:41 AM, full battery, full signal)
xcrun simctl status_bar booted override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularMode active \
  --cellularBars 4 \
  --wifiBars 3

# Capture screenshot
xcrun simctl io booted screenshot screenshot.png

# Clear status bar override when done
xcrun simctl status_bar booted clear
```

### Option 2: Physical Device
1. Connect iPhone to Mac
2. Open Xcode → Window → Devices and Simulators
3. Select device → Take Screenshot
4. Screenshots saved to Desktop

### Option 3: Design Tool (Recommended for App Store)
1. Capture raw screenshots from simulator/device
2. Import into Figma/Sketch/Photoshop
3. Add device frames (mockup)
4. Add marketing text overlays
5. Export at correct dimensions

---

## Screenshot Design Template

```
┌────────────────────────────────┐
│                                │
│    "Marketing Headline"        │  ← Large, bold text
│                                │
│   ┌──────────────────────┐    │
│   │                      │    │
│   │    Device Frame      │    │
│   │    with App          │    │
│   │    Screenshot        │    │
│   │                      │    │
│   │                      │    │
│   │                      │    │
│   └──────────────────────┘    │
│                                │
│         Life380 Logo           │  ← Optional
│                                │
└────────────────────────────────┘
```

---

## Color Palette for Screenshots

| Color | Hex | Usage |
|-------|-----|-------|
| Primary Blue | #007AFF | Highlights, CTAs |
| Safe Green | #34C759 | Precision, success |
| Alert Red | #FF3B30 | SOS, warnings |
| Background | #F2F2F7 | Light mode BG |
| Text | #000000 | Headlines |
| Subtext | #8E8E93 | Secondary text |

---

## Text Overlays (Copy)

### Headlines (pick 6)
1. "Always know where your family is"
2. "Get notified when they arrive safely"
3. "Know when they'll be home"
4. "Emergency help when you need it"
5. "Understand your family's patterns"
6. "Your private family circle"
7. "Precision location for peace of mind"
8. "One tap away from safety"

### Tagline
```
Life380 - Family safety, simplified.
```

---

## Free Screenshot Generator Tools

1. **App Mockup** - https://app-mockup.com
2. **MockUPhone** - https://mockuphone.com
3. **Rotato** - https://rotato.app (paid, high quality)
4. **Screenshots Pro** - Mac App Store

---

## Checklist Before Submission

- [ ] 6 screenshots per required device size
- [ ] Consistent design across all screenshots
- [ ] Marketing text is readable
- [ ] No personal data visible (use demo data)
- [ ] Status bar shows 9:41 AM (Apple standard)
- [ ] Battery shows full
- [ ] No system dialogs visible
- [ ] App looks polished and complete

---

## Quick Capture Script

```bash
#!/bin/bash
# Run this after dismissing any dialogs

# Set clean status bar
xcrun simctl status_bar booted override --time "9:41" --batteryState charged --batteryLevel 100

# Create output directory
mkdir -p ~/Desktop/Life380_Screenshots

# Capture each screen (navigate manually between captures)
echo "Navigate to Map view and press Enter..."
read
xcrun simctl io booted screenshot ~/Desktop/Life380_Screenshots/01_map.png

echo "Navigate to Places view and press Enter..."
read
xcrun simctl io booted screenshot ~/Desktop/Life380_Screenshots/02_places.png

echo "Navigate to Insights view and press Enter..."
read
xcrun simctl io booted screenshot ~/Desktop/Life380_Screenshots/03_insights.png

echo "Navigate to Circle view and press Enter..."
read
xcrun simctl io booted screenshot ~/Desktop/Life380_Screenshots/04_circle.png

echo "Navigate to Settings view and press Enter..."
read
xcrun simctl io booted screenshot ~/Desktop/Life380_Screenshots/05_settings.png

echo "Show SOS feature and press Enter..."
read
xcrun simctl io booted screenshot ~/Desktop/Life380_Screenshots/06_sos.png

# Clear status bar
xcrun simctl status_bar booted clear

echo "Done! Screenshots saved to ~/Desktop/Life380_Screenshots/"
```

---

*For best results, use a design tool to add device frames and marketing text to raw screenshots.*
