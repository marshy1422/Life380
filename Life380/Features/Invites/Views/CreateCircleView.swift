import SwiftUI
import UIKit

struct CreateCircleView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss

    @State private var circleName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var createdCircle: FamilyCircle?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Circle Name", text: $circleName)
                        .textContentType(.organizationName)
                } header: {
                    Text("Circle Details")
                } footer: {
                    Text("Choose a name that helps identify this circle, like \"Smith Family\" or \"Close Friends\"")
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }

                if let circle = createdCircle {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text("Circle Created!")
                                    .font(.headline)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Invite Code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Text(circle.inviteCode)
                                        .font(.system(.title2, design: .monospaced))
                                        .fontWeight(.bold)

                                    Spacer()

                                    Button {
                                        UIPasteboard.general.string = circle.inviteCode
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                }
                            }

                            Text("Share this code with family members so they can join your circle.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    Section {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share Invite", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            dismiss()
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                    }
                } else {
                    Section {
                        Button {
                            createCircle()
                        } label: {
                            HStack {
                                Spacer()
                                if isCreating {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text(isCreating ? "Creating..." : "Create Circle")
                                Spacer()
                            }
                        }
                        .disabled(circleName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    }
                }
            }
            .navigationTitle("Create Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let circle = createdCircle {
                    ShareSheet(items: [
                        "Join my Life380 circle \"\(circle.name)\"! Download the app and use invite code: \(circle.inviteCode)"
                    ])
                }
            }
        }
    }

    private func createCircle() {
        let name = circleName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let circle = try await firestoreService.createCircle(name: name)
                createdCircle = circle
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

// Simple ShareSheet wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    CreateCircleView()
        .environmentObject(FirestoreService.shared)
}
