import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft }) private var finishedWorkouts: [Workout]
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
    /// Unit of the CSV being imported when its header doesn't say (Strong's bare "Weight" column). Converted to kg on import.
    @State private var importUnit: UnitPreference = .kg

    private var user: User? { users.first }
    private var onAppearUnit: UnitPreference { user?.unitPreference ?? .kg }

    var onBack: (() -> Void)? = nil

    private var workoutCount: Int { finishedWorkouts.count }

    var body: some View {
        VStack(spacing: 0) {
            if let onBack {
                MoreScreenHeader(title: "IMPORT / EXPORT", onBack: onBack)
            }
            ScrollView {
                VStack(spacing: 0) {
                    Text("Export your workout data to keep a backup or use in other apps.")
                        .font(.archivo(14))
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    MoreSectionLabel(title: "IMPORT")
                    ForEach(DataImportService.ImportSource.allCases) { source in
                        MoreRow(icon: "square.and.arrow.down",
                                label: "Import from \(source.displayName)", value: "CSV") {
                            selectedImportSource = source
                            showImportPicker = true
                        }
                    }
                    MoreMenuRow(icon: "scalemass", label: "File Weight Unit",
                                selection: $importUnit,
                                options: Array(UnitPreference.allCases), title: { $0.displayName })
                    Text("Export a CSV from Strong or Hevy and select it here. Weights are converted to kg for storage; pick the unit the file uses.")
                        .font(.spaceMono(11))
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.top, 8)

                    MoreSectionLabel(title: "EXPORT FORMATS")
                    Text("Exports always use kg (the unit weights are stored in); a Unit column / weightUnit field says so.")
                        .font(.spaceMono(11))
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.top, 8)
                    MoreRow(icon: "doc.text", label: "Export as JSON",
                            value: "\(workoutCount) WORKOUTS") { exportJSON() }
                    MoreRow(icon: "doc.text", label: "Export as CSV",
                            value: "\(workoutCount) WORKOUTS") { exportCSV() }
                    Spacer().frame(height: 32)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .navigationTitle(onBack == nil ? "Import / Export" : "")
        .navigationBarHidden(onBack != nil)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .onAppear { importUnit = onAppearUnit }
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
                    importedCount = try DataImportService.importStrongCSV(csvString, modelContext: modelContext, user: user, sourceUnit: importUnit)
                case .hevy:
                    importedCount = try DataImportService.importHevyCSV(csvString, modelContext: modelContext, user: user, sourceUnit: importUnit)
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

/// More-tab entry point: same screen, drawn with the More header and a back button.
struct DataImportScreen: View {
    let onBack: () -> Void
    var body: some View { DataExportView(onBack: onBack) }
}
