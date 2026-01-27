# Life380 Quick Submission Guide

## 5-Minute TestFlight Submission

### Step 1: Prepare (2 min)
```
Open Xcode → Life380.xcodeproj
Select: Any iOS Device (arm64)
Product → Clean Build Folder
```

### Step 2: Archive (1 min)
```
Product → Archive
Wait for build to complete...
```

### Step 3: Upload (2 min)
```
Window → Organizer
Select latest archive
Click "Distribute App"
Select "App Store Connect"
Click "Upload"
```

---

## App Store Connect Setup

### Create App Record
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. My Apps → (+) New App
3. Fill in:
   - **Platform:** iOS
   - **Name:** Life380
   - **Primary Language:** English (U.S.)
   - **Bundle ID:** com.life380.app
   - **SKU:** life380-ios-v1

### Required URLs (Host these first!)
| URL | Purpose |
|-----|---------|
| `https://life380.app/privacy` | Privacy Policy |
| `https://life380.app/support` | Support Page |
| `https://life380.app/terms` | Terms of Service |

---

## TestFlight Distribution

### Internal Testers (Immediate)
1. App Store Connect → TestFlight
2. Internal Testing → Add testers
3. Testers receive email invite

### External Testers (After Review)
1. Create External Group
2. Add build to group
3. Submit for Beta App Review
4. Review takes 24-48 hours

---

## Key Info at a Glance

| Item | Value |
|------|-------|
| Bundle ID | `com.life380.app` |
| Version | 1.0.0 |
| Build | 1 |
| Min iOS | 17.0 |
| Category | Social Networking |

---

## Common Issues & Fixes

### "Missing Compliance"
→ Go to TestFlight → Build → Export Compliance
→ Select "No" for encryption (we marked it in Info.plist)

### "Missing Privacy Policy"
→ Add URL in App Store Connect → App Information

### "Invalid Binary"
→ Check provisioning profile matches bundle ID
→ Ensure Release configuration

### "Beta Review Rejected"
→ Check Notes for Reviewer are clear
→ Ensure demo account works
→ Remove any debug/test UI

---

## After Upload

1. ✅ Check build appears in TestFlight (5-15 min)
2. ✅ Complete Export Compliance if prompted
3. ✅ Add internal testers
4. ✅ Send TestFlight invites
5. ✅ Monitor crash reports

---

## Support Contacts

- **Beta Feedback:** Settings → Beta Program → Send Feedback
- **Email:** feedback@life380.app

---

*Ready to ship! 🚀*
