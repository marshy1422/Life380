# REPORT 02: MAP INITIALIZATION BUG FIX

## Problem Identified

The map was initializing with **hardcoded San Francisco coordinates** (37.7749, -122.4194) as the default camera position. This caused the map to momentarily show San Francisco before centering on the user's actual location, creating a confusing user experience.

### Files Affected
- `Features/Home/Views/MapView.swift` (lines 11-14)
- `Features/Home/ViewModels/HomeViewModel.swift` (lines 18-21)

### Original Code
```swift
@State private var cameraPosition = MapCameraPosition.region(MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
))
```

---

## Fixes Implemented

### 1. Changed Initial Camera Position (MapView.swift)

**Before:**
```swift
@State private var cameraPosition = MapCameraPosition.region(MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
))
```

**After:**
```swift
// Start with user location tracking instead of hardcoded coordinates
@State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
@State private var isLoadingLocation: Bool = true
@State private var locationError: String?
```

### 2. Added Loading State Overlay

Shows a loading indicator while waiting for the first location fix:

```swift
private var locationLoadingOverlay: some View {
    VStack(spacing: 16) {
        ProgressView()
            .scaleEffect(1.5)
            .tint(.white)

        Text("Getting your location...")
            .font(.headline)
            .foregroundColor(.white)

        Text("Please ensure location services are enabled")
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.5))
}
```

### 3. Added Error Banner for Permission Issues

Displays an actionable error message when location access is denied:

```swift
private func locationErrorBanner(_ message: String) -> some View {
    HStack {
        Image(systemName: "location.slash.fill")
            .foregroundColor(.white)

        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)

        Spacer()

        Button("Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        .font(.subheadline.bold())
        .foregroundColor(.white)
    }
    .padding()
    .background(Color.orange)
}
```

### 4. Added Permission Status Handler

Monitors authorization status changes and updates UI accordingly:

```swift
.onChange(of: locationManager.authorizationStatus) { _, newStatus in
    switch newStatus {
    case .denied, .restricted:
        isLoadingLocation = false
        locationError = "Location access denied. Enable in Settings to see your location."
    case .authorizedWhenInUse, .authorizedAlways:
        locationError = nil
    default:
        break
    }
}
```

### 5. Added Location Timeout

Prevents infinite loading state with a 15-second timeout:

```swift
.task {
    try? await Task.sleep(nanoseconds: 15_000_000_000)
    if locationManager.currentLocation == nil && isLoadingLocation {
        isLoadingLocation = false
        if locationManager.authorizationStatus == .notDetermined {
            locationError = "Waiting for location permission..."
        } else if locationManager.authorizationStatus == .denied {
            locationError = "Location access denied. Enable in Settings."
        } else {
            locationError = "Unable to get location. Please try again."
        }
    }
}
```

### 6. Updated HomeViewModel (HomeViewModel.swift)

Removed hardcoded coordinates and made mapRegion optional:

**Before:**
```swift
@Published var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
)
```

**After:**
```swift
// Map region - nil until real location is available
@Published var mapRegion: MKCoordinateRegion?
@Published var hasInitialLocation = false
```

---

## Edge Cases Handled

| Scenario | Behavior |
|----------|----------|
| **Permission not determined** | Shows loading overlay, waits for user to grant permission |
| **Permission denied** | Shows orange error banner with "Settings" button |
| **Permission granted, location loading** | Shows loading overlay with spinner |
| **Permission granted, location available** | Map centers on user, loading dismissed |
| **Location timeout (15s)** | Shows error message based on status |
| **Background/foreground transitions** | Handled by existing handlers |

---

## Testing Checklist

- [ ] Fresh install - verify loading state appears
- [ ] Deny location permission - verify error banner appears
- [ ] Grant "When In Use" permission - verify map centers on user
- [ ] Grant "Always" permission - verify background tracking works
- [ ] Kill app and relaunch - verify no SF flash
- [ ] Slow network - verify timeout shows appropriate message
- [ ] Settings button opens iOS Settings

---

## Build Status

**BUILD SUCCEEDED** - All changes compile without errors or warnings.

---

## Summary

The map initialization bug has been fixed by:
1. Using `.userLocation(fallback: .automatic)` instead of hardcoded SF coordinates
2. Adding a loading overlay while waiting for location
3. Adding error handling for permission denied scenarios
4. Adding a 15-second timeout to prevent infinite loading
5. Removing hardcoded coordinates from HomeViewModel

Users will no longer see the map briefly centered on San Francisco before their actual location loads.
