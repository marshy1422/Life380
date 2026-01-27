# Life380 TestFlight & App Store Submission Checklist

## Pre-Submission Requirements

### 1. Apple Developer Account
- [ ] Active Apple Developer Program membership ($99/year)
- [ ] Certificates & Provisioning Profiles configured
- [ ] App ID registered: `com.life380.app`

### 2. App Store Connect Setup
- [ ] Create new app record
- [ ] **Bundle ID:** `com.life380.app`
- [ ] **SKU:** `life380-ios-v1`
- [ ] **Primary Language:** English (U.S.)
- [ ] **App Name:** Life380
- [ ] **Subtitle:** Family Location & Safety
- [ ] **Category:** Social Networking (Primary), Lifestyle (Secondary)

---

## App Information

### Basic Info
| Field | Value |
|-------|-------|
| App Name | Life380 |
| Subtitle | Family Location & Safety |
| Bundle ID | com.life380.app |
| Version | 1.0.0 |
| Build | 1 |
| SKU | life380-ios-v1 |

### Description (4000 chars max)
```
Life380 keeps your family connected and safe with real-time location sharing, smart arrival notifications, and emergency SOS alerts.

KEY FEATURES:

📍 PRECISION LOCATION TRACKING
• See where your family members are in real-time
• High-accuracy GPS with smart filtering
• Battery-optimized background updates

🏠 PLACES & GEOFENCING
• Save important places (Home, Work, School)
• Get notified when family arrives or leaves
• Automatic place detection

⏱️ SMART ETAs
• See when family members will arrive
• Hybrid calculation for accurate estimates
• "Almost there" notifications

🆘 EMERGENCY SOS
• One-tap emergency alerts to your circle
• Share location instantly in emergencies
• Critical notifications bypass Do Not Disturb

📊 INSIGHTS DASHBOARD
• Track time spent at places
• View travel patterns and commutes
• Weekly activity summaries

👨‍👩‍👧‍👦 FAMILY CIRCLES
• Create private family groups
• Invite members with simple codes
• Switch between multiple circles

PRIVACY FIRST:
• You control what you share
• Location sharing can be paused anytime
• Data encrypted in transit and at rest
• Delete your data anytime

Life380 - Because knowing your family is safe matters.
```

### Keywords (100 chars max)
```
family,location,tracker,gps,safety,find,friends,kids,parental,sos,emergency,geofence,eta
```

### Support URL
```
https://life380.app/support
```

### Marketing URL
```
https://life380.app
```

### Privacy Policy URL (Required)
```
https://life380.app/privacy
```

---

## Privacy & Compliance

### App Privacy (Nutrition Labels)

**Data Collected:**

| Data Type | Purpose | Linked to Identity | Tracking |
|-----------|---------|-------------------|----------|
| Precise Location | App Functionality | Yes | No |
| Coarse Location | App Functionality | Yes | No |
| Email Address | Account | Yes | No |
| Name | Account | Yes | No |
| User ID | App Functionality | Yes | No |
| Device ID | Analytics | No | No |

**Data Usage Purposes:**
- [ ] App Functionality (Primary)
- [ ] Analytics (if using Firebase Analytics)

### Required Privacy Disclosures
- [ ] Location data is shared with circle members only
- [ ] Data is not sold to third parties
- [ ] Users can delete their account and data

### Info.plist Permission Strings
- [x] `NSLocationWhenInUseUsageDescription`
- [x] `NSLocationAlwaysAndWhenInUseUsageDescription`
- [x] `NSLocationAlwaysUsageDescription`
- [x] `NSMotionUsageDescription`
- [x] `ITSAppUsesNonExemptEncryption` = NO

---

## App Review Information

### Demo Account (if needed)
```
Email: demo@life380.app
Password: TestFlight2024!
```

### Notes for Reviewer
```
Life380 is a family location sharing app. To fully test:

1. Sign in with the demo account above
2. The demo account is part of a "Demo Family" circle
3. You'll see simulated family member locations on the map
4. Test the SOS feature by holding the SOS button for 3 seconds (this is a demo and won't trigger real alerts)

Location permissions are required for core functionality. Background location is used to send arrival/departure notifications even when the app is closed.

If you have questions, contact: review@life380.app
```

### Contact Information
```
First Name: [Your Name]
Last Name: [Your Last Name]
Phone: [Your Phone]
Email: review@life380.app
```

---

## TestFlight Beta Configuration

### Internal Testing (Up to 100 testers)
- [ ] Add team members as internal testers
- [ ] No review required - immediate access

### External Testing (Up to 10,000 testers)
- [ ] Requires Beta App Review
- [ ] Add beta testers via email or public link

### Beta App Description
```
Welcome to the Life380 beta!

We're testing our family location sharing app and need your feedback. Please report any bugs or suggestions using the in-app feedback feature (Settings → Beta Program → Send Feedback).

What to test:
• Location accuracy and battery usage
• Geofence notifications (arriving/leaving places)
• SOS emergency feature
• Family circle management
• Overall app stability

Thank you for helping us improve Life380!
```

### What to Test
```
• Create and join family circles
• Add places and test geofence notifications
• Check location accuracy on the map
• Test the SOS emergency feature
• Review the Insights dashboard
• Try different settings combinations
```

---

## Screenshots Required

### iPhone 6.7" (iPhone 15 Pro Max) - Required
- [ ] Screenshot 1: Map view with family members
- [ ] Screenshot 2: Places list with geofences
- [ ] Screenshot 3: Insights dashboard
- [ ] Screenshot 4: SOS feature
- [ ] Screenshot 5: Circle/family view
- [ ] Screenshot 6: Settings (optional)

### iPhone 6.5" (iPhone 14 Plus) - Required
- [ ] Same 5-6 screenshots as above

### iPhone 5.5" (iPhone 8 Plus) - Optional but recommended
- [ ] Same screenshots for older devices

### iPad 12.9" - If supporting iPad
- [ ] Same screenshots for iPad layout

---

## Technical Checklist

### Build Configuration
- [ ] Set to Release configuration
- [ ] Strip debug symbols
- [ ] Enable bitcode (if required)
- [ ] Set correct provisioning profile

### Archive & Upload
```bash
# In Xcode:
1. Select "Any iOS Device" as destination
2. Product → Archive
3. Window → Organizer
4. Select archive → Distribute App
5. Choose "App Store Connect"
6. Upload
```

### Common Rejection Reasons to Avoid
- [ ] All permission strings are user-friendly and explain WHY
- [ ] Privacy policy URL is accessible and complete
- [ ] Demo account works if app requires login
- [ ] No placeholder content or Lorem ipsum
- [ ] No crashes on launch
- [ ] Account deletion works (App Store requirement)
- [ ] No private APIs used

---

## Post-Upload Checklist

### After Upload to App Store Connect
- [ ] Build appears in TestFlight section
- [ ] Add Export Compliance information
- [ ] Set up internal testing group
- [ ] Add beta testers

### Monitor Beta
- [ ] Check for crash reports in Xcode Organizer
- [ ] Review beta feedback submissions
- [ ] Monitor TestFlight feedback
- [ ] Track battery usage reports

---

## Version History

| Version | Build | Date | Notes |
|---------|-------|------|-------|
| 1.0.0 | 1 | TBD | Initial beta release |

---

## Quick Commands

### Build for Release
```bash
xcodebuild -scheme Life380 -configuration Release -destination generic/platform=iOS archive -archivePath ./Life380.xcarchive
```

### Export IPA
```bash
xcodebuild -exportArchive -archivePath ./Life380.xcarchive -exportPath ./export -exportOptionsPlist ExportOptions.plist
```

### Upload via CLI (requires App Store Connect API key)
```bash
xcrun altool --upload-app -f Life380.ipa -t ios -u "apple-id@email.com" -p "app-specific-password"
```

---

## Contacts

| Role | Name | Email |
|------|------|-------|
| Developer | | |
| App Store Contact | | review@life380.app |
| Support | | support@life380.app |
| Privacy | | privacy@life380.app |

---

*Last Updated: January 2026*
