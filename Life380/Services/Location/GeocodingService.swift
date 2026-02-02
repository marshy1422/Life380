import Foundation
import CoreLocation

/// Service for geocoding and reverse geocoding operations
class GeocodingService {
    static let shared = GeocodingService()

    private let geocoder = CLGeocoder()

    private init() {}

    // MARK: - Reverse Geocoding

    /// Gets address from coordinates
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw GeocodingError.noResults
        }

        return formatAddress(from: placemark)
    }

    /// Gets address components from coordinates
    func reverseGeocodeDetailed(coordinate: CLLocationCoordinate2D) async throws -> AddressComponents {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw GeocodingError.noResults
        }

        return AddressComponents(
            streetNumber: placemark.subThoroughfare,
            streetName: placemark.thoroughfare,
            city: placemark.locality,
            state: placemark.administrativeArea,
            postalCode: placemark.postalCode,
            country: placemark.country,
            countryCode: placemark.isoCountryCode
        )
    }

    // MARK: - Forward Geocoding

    /// Gets coordinates from an address string
    func geocode(address: String) async throws -> CLLocationCoordinate2D {
        let placemarks = try await geocoder.geocodeAddressString(address)

        guard let placemark = placemarks.first,
              let location = placemark.location else {
            throw GeocodingError.noResults
        }

        return location.coordinate
    }

    /// Searches for places matching a query
    func searchPlaces(query: String, near coordinate: CLLocationCoordinate2D? = nil) async throws -> [PlaceSearchResult] {
        let placemarks: [CLPlacemark]

        if let coordinate = coordinate {
            let region = CLCircularRegion(
                center: coordinate,
                radius: 10000, // 10km radius
                identifier: "search"
            )
            placemarks = try await geocoder.geocodeAddressString(query, in: region)
        } else {
            placemarks = try await geocoder.geocodeAddressString(query)
        }

        return placemarks.compactMap { placemark -> PlaceSearchResult? in
            guard let location = placemark.location else { return nil }
            return PlaceSearchResult(
                name: placemark.name ?? query,
                address: formatAddress(from: placemark),
                coordinate: location.coordinate
            )
        }
    }

    // MARK: - Helpers

    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let streetNumber = placemark.subThoroughfare,
           let streetName = placemark.thoroughfare {
            components.append("\(streetNumber) \(streetName)")
        } else if let streetName = placemark.thoroughfare {
            components.append(streetName)
        }

        if let city = placemark.locality {
            components.append(city)
        }

        if let state = placemark.administrativeArea {
            components.append(state)
        }

        return components.joined(separator: ", ")
    }
}

// MARK: - Supporting Types

enum GeocodingError: Error, LocalizedError {
    case noResults
    case invalidCoordinate
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No results found for the given location"
        case .invalidCoordinate:
            return "Invalid coordinate provided"
        case .rateLimited:
            return "Too many requests. Please try again later."
        }
    }
}

struct AddressComponents {
    let streetNumber: String?
    let streetName: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    let countryCode: String?

    var shortAddress: String {
        var parts: [String] = []
        if let number = streetNumber, let street = streetName {
            parts.append("\(number) \(street)")
        } else if let street = streetName {
            parts.append(street)
        }
        if let city = city {
            parts.append(city)
        }
        return parts.joined(separator: ", ")
    }

    var fullAddress: String {
        var parts: [String] = []
        if let number = streetNumber, let street = streetName {
            parts.append("\(number) \(street)")
        } else if let street = streetName {
            parts.append(street)
        }
        if let city = city {
            parts.append(city)
        }
        if let state = state {
            parts.append(state)
        }
        if let postal = postalCode {
            parts.append(postal)
        }
        return parts.joined(separator: ", ")
    }
}

struct PlaceSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}
