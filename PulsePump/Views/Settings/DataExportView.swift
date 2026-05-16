import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var exportedJSON: Data?
    @State private var exportedCSV: String?
    @State private var showShareSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var exportURL: URL?
    @State private var showImportPicker = false
    @State private var selectedImportSource: DataImportService.ImportSource = .strong
    @State private var showImportSuccess = false
    @State private var importedCount = 0

    private var user: User? { users.first }

    var body: some View {
        List {
            Section {
                Text("Export your workout data to keep a backup or use in other apps.")
                    .font(.mono(14))
                    .foregroundStyle(.secondary)
            }

            Section("Export Formats") {
                Button {
                    exportJSON()
                } label: {
                    Label("Export as JSON", systemImage: "doc.text")
                }

                Button {
                    exportCSV()
                } label: {
                    Label("Export as CSV", systemImage: "tablecells")
                }
            }

            Section("Import") {
                ForEach(DataImportService.ImportSource.allCases) { source in
                    Button {
                        selectedImportSource = source
                        showImportPicker = true
                    } label: {
                        Label("Import from \(source.displayName)", systemImage: "square.and.arrow.down")
                    }
                }
                Text("Export a CSV from \(selectedImportSource.displayName) and select it here.")
                    .font(.mono(11))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Import / Export")
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            handleImport(result)
        }
        .alert("Export Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Import Complete", isPresented: $showImportSuccess) {
            Button("OK") {}
        } message: {
            Text("Successfully imported \(importedCount) workouts from \(selectedImportSource.displayName).")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let csvString = try String(contentsOf: url, encoding: .utf8)
                guard let user else { return }

                switch selectedImportSource {
                case .strong:
                    importedCount = try DataImportService.importStrongCSV(csvString, modelContext: modelContext, user: user)
                case .hevy:
                    importedCount = try DataImportService.importHevyCSV(csvString, modelContext: modelContext, user: user)
                }
                showImportSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func exportJSON() {
        do {
            let data = try DataExportService.exportWorkouts(from: modelContext)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("pump_workouts.json")
            try data.write(to: url)
            exportURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func exportCSV() {
        do {
            let csv = try DataExportService.generateCSV(from: modelContext)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("pump_workouts.csv")
            try csv.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
