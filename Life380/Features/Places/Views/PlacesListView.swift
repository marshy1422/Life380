import SwiftUI
import MapKit

struct PlacesView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var showingAddPlace = false

    var body: some View {
        NavigationStack {
            Group {
                if firestoreService.places.isEmpty {
                    ContentUnavailableView(
                        "No Places",
                        systemImage: "mappin.slash",
                        description: Text("Add places like Home or Work to get arrival and departure notifications.")
                    )
                } else {
                    List {
                        ForEach(firestoreService.places) { place in
                            PlaceRow(place: place)
                        }
                        .onDelete(perform: deletePlace)
                    }
                }
            }
            .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPlace = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlace) {
                AddPlaceView()
            }
        }
    }

    private func deletePlace(at offsets: IndexSet) {
        guard let circleId = firestoreService.currentCircleId else { return }

        for index in offsets {
            let place = firestoreService.places[index]
            Task {
                try? await firestoreService.deletePlace(placeId: place.id, circleId: circleId)
            }
        }
    }
}

struct PlaceRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: place.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(place.color)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                Text(place.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if place.notificationsEnabled {
                Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreService: FirestoreService

    @State private var name = ""
    @State private var address = ""
    @State private var selectedIcon = "mappin"
    @State private var selectedColor = Color.blue
    @State private var notificationsEnabled = true
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var isSearching = false

    let icons = ["house.fill", "building.2.fill", "graduationcap.fill", "cart.fill", "sportscourt.fill", "cross.fill", "fork.knife", "gym.bag.fill", "airplane", "car.fill"]
    let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .teal]

    var body: some View {
        NavigationStack {
            Form {
                Section("Place Details") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                        .onChange(of: address) { _, newValue in
                            searchAddress(newValue)
                        }

                    if !searchResults.isEmpty {
                        ForEach(searchResults, id: \.self) { item in
                            Button(action: { selectPlace(item) }) {
                                VStack(alignment: .leading) {
                                    Text(item.name ?? "Unknown")
                                        .foregroundColor(.primary)
                                    if let address = item.placemark.formattedAddress {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? selectedColor : Color(.systemGray5))
                                .foregroundColor(selectedIcon == icon ? .white : .primary)
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                }

                Section {
                    Toggle("Arrival & Departure Notifications", isOn: $notificationsEnabled)
                }
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlace()
                    }
                    .disabled(name.isEmpty || selectedLocation == nil)
                }
            }
        }
    }

    private func searchAddress(_ query: String) {
        guard query.count > 2 else {
            searchResults = []
            return
        }

        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            if let response = response {
                searchResults = Array(response.mapItems.prefix(5))
            }
        }
    }

    private func selectPlace(_ item: MKMapItem) {
        name = item.name ?? ""
        address = item.placemark.formattedAddress ?? ""
        selectedLocation = item.placemark.coordinate
        searchResults = []
    }

    private func savePlace() {
        guard let location = selectedLocation,
              let circleId = firestoreService.currentCircleId else { return }

        let place = Place(
            name: name,
            address: address,
            icon: selectedIcon,
            color: selectedColor,
            notificationsEnabled: notificationsEnabled,
            latitude: location.latitude,
            longitude: location.longitude
        )

        Task {
            try? await firestoreService.addPlace(place, circleId: circleId)
            dismiss()
        }
    }
}

extension MKPlacemark {
    var formattedAddress: String? {
        [subThoroughfare, thoroughfare, locality, administrativeArea, postalCode]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

#Preview {
    PlacesView()
        .environmentObject(FirestoreService.shared)
}
