# Life380 Integration Test Coordination Document

**Agent 15: Integration Test Coordinator**
**Date:** 2026-02-04
**App Version:** 1.0.0
**Document Status:** Pre-Submission Final

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Critical Issues Tracker](#critical-issues-tracker)
3. [Critical Path Test Scenarios](#critical-path-test-scenarios)
4. [End-to-End Test Plans](#end-to-end-test-plans)
5. [TestFlight Beta Test Plan](#testflight-beta-test-plan)
6. [Pre-Submission Verification Checklist](#pre-submission-verification-checklist)
7. [Appendix: Test Data Requirements](#appendix-test-data-requirements)

---

## Executive Summary

This document consolidates findings from all 14 previous audit agents and provides comprehensive test plans for Life380's App Store submission. The app is a family location sharing and safety application built with SwiftUI and Firebase.

### Overall Readiness Assessment

| Category | Status | Blocking Issues |
|----------|--------|-----------------|
| Phase 1 - Critical Blockers | RESOLVED | 0 |
| Phase 2 - Compliance Issues | ACTION REQUIRED | 7 issues |
| Phase 3 - Quality Issues | ACTION REQUIRED | 4 issues |
| Build Status | PASSING | 0 warnings, 0 errors |

**Submission Readiness:** NOT READY - 11 blocking issues must be resolved before submission.

---

## Critical Issues Tracker

### Phase 1 Issues (ALL RESOLVED)

| Issue | Status | Resolution |
|-------|--------|------------|
| PrivacyInfo.xcprivacy missing | FIXED | Created with required privacy manifest |
| Certificate pinning weak | FIXED | Hardened with production certificates |
| Firebase rules vulnerable | FIXED | 8 issues resolved (3 critical) |

### Phase 2 Issues (ACTION REQUIRED)

| ID | Issue | Severity | Status | Owner | Deadline |
|----|-------|----------|--------|-------|----------|
| P2-01 | COPPA: No age verification | CRITICAL | OPEN | Legal/Dev | Pre-submission |
| P2-02 | GDPR: Data export simulated | HIGH | OPEN | Backend | Pre-submission |
| P2-03 | StoreKit: Missing billing retry/grace period | HIGH | OPEN | Dev | Pre-submission |
| P2-04 | StoreKit: No revocation check | MEDIUM | OPEN | Dev | Pre-submission |
| P2-05 | StoreKit: No intro offer display | LOW | OPEN | Dev | Post-launch OK |
| P2-06 | Auth: lastAuthTime in UserDefaults | MEDIUM | OPEN | Dev | Pre-submission |
| P2-07 | Push: Critical Alerts without entitlement | CRITICAL | OPEN | Dev | Pre-submission |
| P2-08 | Encryption: ITSAppUsesNonExemptEncryption = NO | CRITICAL | OPEN | Dev | Pre-submission |
| P2-09 | Delete Account: No subscription guidance | MEDIUM | OPEN | Dev | Pre-submission |

### Phase 3 Issues (ACTION REQUIRED)

| ID | Issue | Severity | Status | Owner | Deadline |
|----|-------|----------|--------|-------|----------|
| P3-01 | SOS button missing VoiceOver | CRITICAL | OPEN | Dev | Pre-submission |
| P3-02 | CircleService force unwrap crash risk | HIGH | OPEN | Dev | Pre-submission |
| P3-03 | Hardcoded signing key | HIGH | OPEN | Dev | Pre-submission |
| P3-04 | Privacy policy URL not hosted | MEDIUM | OPEN | Ops | Pre-submission |
| P3-05 | 3 more screenshots needed | LOW | OPEN | Marketing | Pre-submission |

---

## Critical Path Test Scenarios

### Scenario 1: Account Creation and Sign in with Apple

**Priority:** P0 - Must pass for submission
**Estimated Time:** 15 minutes
**Required Devices:** iPhone with Face ID/Touch ID

#### Pre-conditions
- Fresh app install (no existing account)
- Apple ID signed in on device
- Network connectivity available

#### Test Steps

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1.1 | Launch app fresh | Onboarding/login screen appears | |
| 1.2 | Tap "Sign in with Apple" | Apple authentication sheet appears | |
| 1.3 | Complete Face ID/Touch ID | Authentication succeeds | |
| 1.4 | Verify account created | Home screen loads, profile exists in Firestore | |
| 1.5 | Force quit and relaunch | User remains signed in | |
| 1.6 | Sign out | Returns to login screen | |
| 1.7 | Sign in with Apple again | Same account restored (not duplicate) | |

#### Email/Password Flow

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1.8 | Tap "Create Account" | Sign up form appears | |
| 1.9 | Enter invalid email | Error message shown | |
| 1.10 | Enter weak password (<6 chars) | Error message shown | |
| 1.11 | Enter valid credentials | Account created, home screen loads | |
| 1.12 | Sign out, sign in again | Login succeeds | |
| 1.13 | Tap "Forgot Password" | Password reset email sent | |

#### Edge Cases

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1.14 | Cancel Apple Sign In | Returns to login, no crash | |
| 1.15 | Sign in with no network | Appropriate error shown | |
| 1.16 | Sign in with existing email | "Account exists" error shown | |

---

### Scenario 2: Circle Creation and Member Invitation

**Priority:** P0 - Core functionality
**Estimated Time:** 20 minutes
**Required Devices:** 2 iPhones with accounts

#### Pre-conditions
- User A and User B have accounts
- Both have network connectivity
- Location permissions granted

#### Test Steps

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 2.1 | User A: Tap "Create Circle" | Create circle form appears | |
| 2.2 | Enter circle name | Name accepted | |
| 2.3 | Tap "Create" | Circle created, invite code shown | |
| 2.4 | Verify invite code format | 6-character alphanumeric (no confusing chars) | |
| 2.5 | Copy invite code | Code copied to clipboard | |
| 2.6 | User B: Tap "Join Circle" | Join form appears | |
| 2.7 | Enter invite code | Code accepted | |
| 2.8 | Tap "Join" | User B added to circle | |
| 2.9 | User A: Verify member list | User B appears in circle | |
| 2.10 | User B: Verify circle list | New circle appears | |

#### QR Code Flow

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 2.11 | User A: Show QR code | QR code displays invite code | |
| 2.12 | User B: Scan QR code | Camera opens, scans successfully | |
| 2.13 | Confirm join | User B added to circle | |

#### Error Cases

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 2.14 | Enter invalid invite code | "Invalid code" error shown | |
| 2.15 | Join circle already in | "Already a member" error shown | |
| 2.16 | Leave circle as creator | "Cannot leave, must delete" error | |
| 2.17 | Leave circle as member | Successfully removed | |

---

### Scenario 3: Location Sharing Enable/Disable

**Priority:** P0 - Privacy-critical
**Estimated Time:** 15 minutes
**Required Devices:** 2 iPhones in same circle

#### Pre-conditions
- Users A and B in same circle
- Location permissions granted to both
- Both on network

#### Test Steps

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 3.1 | User A: Enable location sharing | Toggle turns on, location updates start | |
| 3.2 | User B: View map | User A's location visible on map | |
| 3.3 | User A: Disable location sharing | Toggle turns off | |
| 3.4 | User B: View map | User A's location disappears or shows "paused" | |
| 3.5 | User A: Enable again | Location reappears for User B | |

#### Permission Flow Testing

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 3.6 | Deny location permission in Settings | App shows permission required message | |
| 3.7 | Grant "While Using" only | Foreground tracking works | |
| 3.8 | Grant "Always" permission | Background tracking enabled | |
| 3.9 | Move to background | Significant location changes mode activates | |
| 3.10 | Return to foreground | Full accuracy tracking resumes | |

#### Accuracy Levels

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 3.11 | Set accuracy to "High" | GPS updates every 10m | |
| 3.12 | Set accuracy to "Medium" | GPS updates every 50m | |
| 3.13 | Set accuracy to "Low" | GPS updates every 200m | |

---

### Scenario 4: SOS Trigger and Cancellation

**Priority:** P0 - Safety-critical feature
**Estimated Time:** 20 minutes
**Required Devices:** 2 iPhones in same circle

#### Pre-conditions
- Users A and B in same circle
- Location enabled for both
- Push notifications enabled
- **Note:** Critical Alerts entitlement must be obtained before this works in production

#### Test Steps

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 4.1 | User A: Long press SOS button | Countdown starts (default 10 seconds) | |
| 4.2 | Observe countdown | Visual countdown, haptic feedback each second | |
| 4.3 | Release before countdown ends | SOS cancelled, confirmation haptic | |
| 4.4 | Long press SOS again | Countdown restarts | |
| 4.5 | Let countdown complete | SOS alert sent | |
| 4.6 | User A: Verify confirmation | "SOS Alert Sent" notification | |
| 4.7 | User B: Receive alert | Push notification with location | |
| 4.8 | User B: Tap notification | Opens app to User A's location | |
| 4.9 | User A: Cancel SOS | Alert marked as resolved | |
| 4.10 | User B: Verify resolved | Alert no longer active | |

#### VoiceOver Testing (CRITICAL - Currently Failing)

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 4.11 | Enable VoiceOver | VoiceOver activates | |
| 4.12 | Navigate to SOS button | Button announced as "SOS Emergency" | |
| 4.13 | Double-tap and hold | Countdown announced | |
| 4.14 | Release early | Cancellation announced | |

#### Edge Cases

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 4.15 | Trigger SOS with no network | Alert queued, sent when reconnected | |
| 4.16 | Trigger SOS outside circle | Error: "Must be in a circle" | |
| 4.17 | Multiple SOS in sequence | Only one active at a time | |

---

### Scenario 5: Subscription Purchase and Restore

**Priority:** P0 - Revenue-critical
**Estimated Time:** 25 minutes
**Required Devices:** iPhone with Sandbox tester account

#### Pre-conditions
- Sandbox tester account configured
- Products configured in App Store Connect
- StoreKit testing enabled

#### Test Steps

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 5.1 | Navigate to subscription screen | Products load with prices | |
| 5.2 | Verify product display | Monthly, Annual, Lifetime options shown | |
| 5.3 | Tap "Subscribe" (Monthly) | Apple payment sheet appears | |
| 5.4 | Complete purchase | Subscription activates | |
| 5.5 | Verify premium features | All Plus features unlocked | |
| 5.6 | Sign out, sign back in | Subscription still active | |
| 5.7 | Delete and reinstall app | Tap "Restore Purchases" works | |

#### Subscription Management

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 5.8 | View subscription status | Expiration date shown correctly | |
| 5.9 | Tap "Manage Subscription" | Opens iOS subscription settings | |
| 5.10 | Cancel subscription | Subscription marked as expiring | |
| 5.11 | Wait for expiration | Features locked after expiration | |

#### Error Handling (Issues P2-03, P2-04)

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 5.12 | Purchase with declined card | Appropriate error shown | |
| 5.13 | Billing retry (grace period) | User notified, features remain | |
| 5.14 | Test revocation handling | Features locked immediately | |

#### Family Tier Testing

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 5.15 | Purchase Family plan | All family features unlocked | |
| 5.16 | Verify tier hierarchy | Family > Plus > Free | |

---

### Scenario 6: Account Deletion

**Priority:** P0 - Required by App Store
**Estimated Time:** 15 minutes
**Required Devices:** iPhone with test account

#### Pre-conditions
- Account with email/password (not Apple ID)
- User is member of at least one circle
- Has location history data

#### Test Steps

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 6.1 | Navigate to Settings > Delete Account | Delete account screen appears | |
| 6.2 | Read data deletion disclosure | Shows what will/won't be deleted | |
| 6.3 | Enter wrong email | Error: credentials don't match | |
| 6.4 | Enter wrong password | Error: credentials don't match | |
| 6.5 | Enter correct credentials | Fields validated | |
| 6.6 | Type "DELETE" incorrectly | Button remains disabled | |
| 6.7 | Type "DELETE" correctly | Button enabled | |
| 6.8 | Tap "Permanently Delete" | Confirmation alert appears | |
| 6.9 | Tap "Delete Forever" | Account deletion initiated | |
| 6.10 | Verify Firebase Auth | User deleted from Firebase Auth | |
| 6.11 | Verify Firestore | User profile deleted | |
| 6.12 | Verify circle membership | User removed from all circles | |
| 6.13 | Verify location history | All location data deleted | |

#### Subscription Guidance (Issue P2-09)

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 6.14 | With active subscription | Warning about cancellation displayed | |
| 6.15 | Link to manage subscription | Opens iOS subscription settings | |
| 6.16 | Return and continue deletion | Deletion proceeds | |

---

## End-to-End Test Plans

### E2E-01: Account Deletion with Active Subscription

**Purpose:** Verify complete flow when user deletes account while subscription is active
**Duration:** 30 minutes
**Priority:** P0

#### Scenario Flow

```
User creates account
    -> Purchases subscription
    -> Uses app (creates circle, adds places)
    -> Decides to delete account
    -> Sees subscription warning
    -> Manages/cancels subscription
    -> Completes account deletion
    -> Verifies all data removed
```

#### Detailed Steps

| # | Action | Verification | Pass/Fail |
|---|--------|--------------|-----------|
| 1 | Create new account | Profile in Firestore | |
| 2 | Purchase Plus subscription | Transaction in StoreKit | |
| 3 | Create circle "Test Circle" | Circle in Firestore | |
| 4 | Add place "Home" | Place in Firestore | |
| 5 | Navigate to Delete Account | Screen loads | |
| 6 | **VERIFY:** Subscription warning shown | Warning text visible | |
| 7 | Tap "Manage Subscription" | iOS Settings opens | |
| 8 | Cancel subscription | Subscription shows "Expires on..." | |
| 9 | Return to app | Delete screen still visible | |
| 10 | Complete deletion flow | All credentials entered | |
| 11 | Confirm deletion | Account deleted | |
| 12 | **VERIFY:** Auth account gone | `Auth.auth().currentUser` is nil | |
| 13 | **VERIFY:** Profile gone | Firestore doc deleted | |
| 14 | **VERIFY:** Circle membership removed | No orphan memberships | |
| 15 | **VERIFY:** Places deleted | Places collection empty | |
| 16 | **VERIFY:** Location history deleted | History collection empty | |
| 17 | Try to sign in again | "Account not found" error | |

#### Expected Database State After Deletion

```
users/{userId} -> DELETED
users/{userId}/places -> DELETED (cascade)
users/{userId}/locationHistory -> DELETED (cascade)
circles/{circleId}/memberIds -> userId REMOVED
```

---

### E2E-02: SOS Alert from Trigger to Family Notification

**Purpose:** Complete end-to-end SOS flow verification
**Duration:** 45 minutes
**Priority:** P0

#### Scenario Flow

```
User triggers SOS
    -> Countdown completes
    -> Alert stored in Firestore
    -> Push notification sent to circle
    -> Family member receives notification
    -> Family member views location
    -> Location streaming during SOS
    -> SOS resolved
    -> All parties notified
```

#### Detailed Steps

| # | Action | Verification | Pass/Fail |
|---|--------|--------------|-----------|
| 1 | User A and B in circle | Both see each other | |
| 2 | User B: Put app in background | App backgrounded | |
| 3 | User A: Long-press SOS | Countdown starts | |
| 4 | Wait 10 seconds | Countdown completes | |
| 5 | **VERIFY:** Firestore alert created | `circles/{id}/sosAlerts/{alertId}` exists | |
| 6 | **VERIFY:** Alert data correct | userId, location, timestamp present | |
| 7 | User B: Receive push | Notification appears (may need entitlement) | |
| 8 | **VERIFY:** Notification content | Shows User A name, "needs help" | |
| 9 | User B: Tap notification | App opens to map | |
| 10 | **VERIFY:** Location visible | User A's location highlighted | |
| 11 | Wait 5 seconds | Location stream update | |
| 12 | **VERIFY:** Location history | `sosAlerts/{id}/locationHistory` has entry | |
| 13 | User A: Cancel SOS | Resolution initiated | |
| 14 | **VERIFY:** Firestore updated | `isActive: false`, `resolvedAt` set | |
| 15 | User B: Alert clears | No longer in circleAlerts | |

#### Network Failure Scenarios

| Condition | Expected Behavior | Verified |
|-----------|-------------------|----------|
| No network at SOS trigger | Alert queued locally | |
| Network restored | Alert sent automatically | |
| Network lost during streaming | Streaming pauses | |
| Network restored | Streaming resumes | |

---

### E2E-03: Subscription Purchase, Restore, and Management

**Purpose:** Complete subscription lifecycle testing
**Duration:** 45 minutes
**Priority:** P0

#### Scenario Flow

```
User on free tier
    -> Views subscription options
    -> Purchases monthly subscription
    -> Uses premium features
    -> Subscription expires
    -> Features locked
    -> Restores purchase
    -> Features unlocked
    -> Upgrades to annual
    -> Cancels subscription
    -> Uses until expiration
```

#### Detailed Steps

| # | Action | Verification | Pass/Fail |
|---|--------|--------------|-----------|
| 1 | Fresh account on free tier | `currentTier == .free` | |
| 2 | Try to use SOS (premium) | Paywall shown | |
| 3 | Navigate to subscription screen | Products load | |
| 4 | **VERIFY:** Prices displayed | Monthly, Annual, Lifetime visible | |
| 5 | Purchase monthly | Transaction completes | |
| 6 | **VERIFY:** Tier updated | `currentTier == .plus` | |
| 7 | Use SOS feature | Feature works | |
| 8 | Sign out | Session ends | |
| 9 | Sign in on new device | Auto-restore entitlements | |
| 10 | **VERIFY:** Subscription restored | Premium features available | |
| 11 | Fast-forward to expiration (sandbox) | Time passes | |
| 12 | **VERIFY:** Features locked | Paywall appears | |
| 13 | Tap "Restore Purchases" | Restoration initiated | |
| 14 | **VERIFY:** If no subscription | "No purchases to restore" | |
| 15 | Purchase annual | Transaction completes | |
| 16 | **VERIFY:** Expiration extended | +1 year from now | |
| 17 | Open iOS Settings | Manage Subscriptions | |
| 18 | Cancel subscription | "Expires on..." shown | |
| 19 | Continue using until expiration | Features work | |
| 20 | After expiration | Features locked | |

#### Grace Period Testing (Issue P2-03)

| # | Condition | Expected Behavior | Verified |
|---|-----------|-------------------|----------|
| 1 | Payment method fails | Grace period starts | |
| 2 | During grace period | Features remain active | |
| 3 | User updates payment | Subscription continues | |
| 4 | Grace period expires | Features locked | |

---

### E2E-04: Geofence Arrival/Departure Notifications

**Purpose:** Verify geofencing functionality end-to-end
**Duration:** 60 minutes (requires physical movement or simulation)
**Priority:** P1

#### Scenario Flow

```
User A creates place "Home"
    -> Sets geofence radius
    -> User A leaves home
    -> Departure notification sent to circle
    -> User A arrives at work
    -> Arrival notification sent
    -> User A returns home
    -> Arrival notification sent
```

#### Detailed Steps

| # | Action | Verification | Pass/Fail |
|---|--------|--------------|-----------|
| 1 | Navigate to Places | Places list shown | |
| 2 | Tap "Add Place" | Place creation form | |
| 3 | Select current location | Map pin placed | |
| 4 | Name place "Home" | Name saved | |
| 5 | Set radius to 100m | Geofence configured | |
| 6 | Enable notifications | Toggle on | |
| 7 | Save place | Place created | |
| 8 | **VERIFY:** Firestore | Place document exists | |
| 9 | **VERIFY:** Geofence registered | CLLocationManager monitoring | |
| 10 | Move >100m away (or simulate) | Location changes | |
| 11 | **VERIFY:** Departure event | Notification sent | |
| 12 | Circle member receives | "User left Home" | |
| 13 | Move back within 100m | Location changes | |
| 14 | **VERIFY:** Arrival event | Notification sent | |
| 15 | Circle member receives | "User arrived at Home" | |

#### Simulation Commands (Xcode)

```bash
# Simulate location change
xcrun simctl location booted set 37.7749,-122.4194  # SF
xcrun simctl location booted set 37.3382,-121.8863  # San Jose
```

---

## TestFlight Beta Test Plan

### Beta Tester Requirements

#### Device Requirements

| Device Category | Minimum | Recommended | Notes |
|-----------------|---------|-------------|-------|
| **iPhone Models** | iPhone 8 | iPhone 12+ | Test on both notch and non-notch |
| **iOS Version** | iOS 16.0 | iOS 17.0+ | Test on minimum supported |
| **Storage** | 100MB free | 500MB free | For location cache |
| **Network** | WiFi/Cellular | Both | Test offline scenarios |

#### Tester Profile Requirements

| Tester Type | Count | Requirements |
|-------------|-------|--------------|
| Internal (Team) | 5-10 | Developer devices with logging |
| External (Family) | 20-50 | Diverse device types |
| External (Power Users) | 10-20 | Heavy location app users |

### Beta Test Scenarios

#### Week 1: Core Functionality

| Day | Focus Area | Scenarios |
|-----|------------|-----------|
| 1-2 | Authentication | Sign up, Sign in with Apple, Password reset |
| 3-4 | Circles | Create, Join, Leave, Invite members |
| 5-7 | Location | Enable/disable, Map accuracy, Battery impact |

#### Week 2: Advanced Features

| Day | Focus Area | Scenarios |
|-----|------------|-----------|
| 8-9 | Places | Add places, Geofence notifications |
| 10-11 | SOS | Trigger, Cancel, Family notification |
| 12-14 | Subscriptions | Purchase, Restore, Feature access |

#### Week 3: Edge Cases & Stability

| Day | Focus Area | Scenarios |
|-----|------------|-----------|
| 15-16 | Offline | No network, Sync on reconnect |
| 17-18 | Background | Location updates, Push notifications |
| 19-21 | Stress Testing | Many members, Rapid location updates |

### Feedback Collection Checklist

#### Required Feedback Points

- [ ] Device model and iOS version
- [ ] Steps to reproduce any issue
- [ ] Screenshot or screen recording
- [ ] Expected vs actual behavior
- [ ] Frequency (always, sometimes, once)

#### Feedback Categories

| Category | Priority | Response SLA |
|----------|----------|--------------|
| Crash | Critical | 24 hours |
| Data Loss | Critical | 24 hours |
| Security Issue | Critical | 24 hours |
| Feature Broken | High | 48 hours |
| UI/UX Issue | Medium | 1 week |
| Enhancement | Low | Backlog |

### Crash/Issue Reporting Process

#### For Testers

1. **If crash occurs:**
   - Note what you were doing
   - Relaunch app
   - Use in-app feedback (Settings > Beta Program > Send Feedback)
   - Include "CRASH:" in subject

2. **If bug occurs:**
   - Take screenshot
   - Use in-app feedback
   - Include steps to reproduce

3. **For performance issues:**
   - Note battery percentage before/after
   - Note time spent with app open
   - Include "BATTERY:" or "PERF:" in subject

#### For Development Team

1. **Daily:** Review crash reports in Xcode Organizer
2. **Daily:** Review TestFlight feedback submissions
3. **Weekly:** Triage and prioritize issues
4. **Weekly:** Release beta update with fixes

---

## Pre-Submission Verification Checklist

### Phase 2 Issues Resolution

| ID | Issue | Resolution Required | Verified |
|----|-------|---------------------|----------|
| P2-01 | COPPA age verification | Add age gate on signup | [ ] |
| P2-02 | GDPR data export | Implement real export (not simulated) | [ ] |
| P2-03 | Billing retry/grace period | Add StoreKit grace period handling | [ ] |
| P2-04 | Revocation check | Check `Transaction.revocationDate` | [ ] |
| P2-05 | Intro offer display | Display introductory pricing (optional) | [ ] |
| P2-06 | lastAuthTime storage | Move from UserDefaults to Keychain | [ ] |
| P2-07 | Critical Alerts | Obtain entitlement from Apple OR remove `.critical` | [ ] |
| P2-08 | Encryption declaration | Change `ITSAppUsesNonExemptEncryption` to YES | [ ] |
| P2-09 | Subscription cancellation | Add guidance in Delete Account flow | [ ] |

### Phase 3 Issues Resolution

| ID | Issue | Resolution Required | Verified |
|----|-------|---------------------|----------|
| P3-01 | SOS VoiceOver | Add accessibility labels and traits | [ ] |
| P3-02 | Force unwrap | Replace `!` with safe unwrapping in CircleService | [ ] |
| P3-03 | Hardcoded key | Move signing key to secure storage | [ ] |
| P3-04 | Privacy policy URL | Deploy to https://life380.app/privacy | [ ] |
| P3-05 | Screenshots | Capture for 6.7", 6.5", and 5.5" devices | [ ] |

### Build Verification

| Check | Command/Action | Expected Result | Verified |
|-------|----------------|-----------------|----------|
| Clean build | Cmd+Shift+K, Cmd+B | Build Succeeded | [ ] |
| Zero warnings | Check Issue Navigator | 0 warnings | [ ] |
| Zero errors | Check Issue Navigator | 0 errors | [ ] |
| Archive builds | Product > Archive | Archive succeeds | [ ] |
| Validation passes | Organizer > Validate | No issues | [ ] |

### Test Verification

| Test Suite | Command | Expected Result | Verified |
|------------|---------|-----------------|----------|
| Unit tests | Cmd+U | All tests pass | [ ] |
| UI tests | Run scheme Life380UITests | All tests pass | [ ] |
| Snapshot tests | If applicable | No regressions | [ ] |

### Metadata Verification

| Item | Location | Status | Verified |
|------|----------|--------|----------|
| App name | App Store Connect | "Life380" | [ ] |
| Subtitle | App Store Connect | "Family Location & Safety" | [ ] |
| Description | App Store Connect | Complete (4000 chars max) | [ ] |
| Keywords | App Store Connect | Complete (100 chars max) | [ ] |
| Support URL | App Store Connect | https://life380.app/support | [ ] |
| Marketing URL | App Store Connect | https://life380.app | [ ] |
| Privacy Policy URL | App Store Connect | https://life380.app/privacy | [ ] |
| App category | App Store Connect | Social Networking | [ ] |
| Age rating | App Store Connect | 4+ (no objectionable content) | [ ] |

### Screenshots Verification

| Device | Dimensions | Required | Status |
|--------|------------|----------|--------|
| iPhone 6.7" | 1290 x 2796 | YES | [ ] |
| iPhone 6.5" | 1284 x 2778 | YES | [ ] |
| iPhone 5.5" | 1242 x 2208 | Recommended | [ ] |
| iPad 12.9" | 2048 x 2732 | If iPad support | [ ] |

### App Privacy (Nutrition Labels)

| Data Type | Purpose | Linked | Tracking | Verified |
|-----------|---------|--------|----------|----------|
| Precise Location | App Functionality | Yes | No | [ ] |
| Email Address | Account | Yes | No | [ ] |
| Name | Account | Yes | No | [ ] |
| User ID | App Functionality | Yes | No | [ ] |
| Device ID | Analytics | No | No | [ ] |

### Demo Account for Review

| Field | Value | Verified |
|-------|-------|----------|
| Email | demo@life380.app | [ ] |
| Password | TestFlight2024! | [ ] |
| Account works | Sign in succeeds | [ ] |
| Demo data present | Circle with members | [ ] |

### Final Submission Checks

| Check | Action | Verified |
|-------|--------|----------|
| All blockers resolved | Review issue tracker | [ ] |
| Build uploaded | Transporter/Xcode | [ ] |
| Build processing complete | App Store Connect shows "Ready to Submit" | [ ] |
| All metadata saved | App Store Connect | [ ] |
| Review notes added | App Store Connect | [ ] |
| Export compliance answered | YES for encryption | [ ] |
| Content rights confirmed | Own all content | [ ] |
| Advertising ID usage declared | If applicable | [ ] |

---

## Appendix: Test Data Requirements

### Firebase Test Data Setup

```javascript
// Users collection
users/testuser1: {
  uid: "testuser1",
  email: "test1@life380.app",
  displayName: "Test User 1",
  circleIds: ["circle1"],
  latitude: 37.7749,
  longitude: -122.4194
}

users/testuser2: {
  uid: "testuser2",
  email: "test2@life380.app",
  displayName: "Test User 2",
  circleIds: ["circle1"],
  latitude: 37.7849,
  longitude: -122.4094
}

// Circles collection
circles/circle1: {
  id: "circle1",
  name: "Test Family",
  createdBy: "testuser1",
  memberIds: ["testuser1", "testuser2"],
  inviteCode: "TEST01",
  createdAt: Timestamp
}

// Places collection
users/testuser1/places/place1: {
  id: "place1",
  name: "Home",
  latitude: 37.7749,
  longitude: -122.4194,
  radius: 100,
  notifyOnArrival: true,
  notifyOnDeparture: true
}
```

### Sandbox Tester Accounts

| Email | Purpose |
|-------|---------|
| sandbox1@life380test.com | Primary purchase testing |
| sandbox2@life380test.com | Family sharing testing |
| sandbox3@life380test.com | Restore testing |

### StoreKit Configuration File

Create `Life380.storekit` with:
- life380_plus_monthly ($4.99)
- life380_plus_annual ($39.99)
- life380_plus_lifetime ($99.99)
- life380_family_monthly ($9.99)
- life380_family_annual ($79.99)
- life380_family_lifetime ($199.99)

---

## Document Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| QA Lead | | | |
| Dev Lead | | | |
| Product Owner | | | |
| Release Manager | | | |

---

**Document Version:** 1.0
**Last Updated:** 2026-02-04
**Next Review:** Before each submission attempt
