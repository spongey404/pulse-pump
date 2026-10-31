import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }) private var finishedWorkouts: [Workout]
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
    @State private var importResult = DataImportService.ImportResult()

    private var user: User? { users.first }
    private var onAppearUnit: UnitPreference { user?.unitPreference ?? .kg }

    var onBack: (() -> Void)? = nil
    /// More › Data import shows only the import half; Settings › Import / export shows both.
    var showsExport = true

    static func howTo(_ source: DataImportService.ImportSource) -> String {
        switch source {
        case .strong: "In Strong: Settings, Export Data. Then pick the CSV here."
        case .hevy: "In Hevy: Profile, Settings, Export Data. Then pick the CSV here."
        }
    }

    private var workoutCount: Int { finishedWorkouts.count }

    var body: some View {
        VStack(spacing: 0) {
            if let onBack {
                MoreScreenHeader(title: showsExport ? "IMPORT / EXPORT" : "DATA IMPORT", onBack: onBack)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if showsExport { MorePageIntro(text: "Bring your history in, or keep a backup of everything you have logged.") }
                    MoreSectionLabel(title: "IMPORT")
                    ForEach(DataImportService.ImportSource.allCases) { source in
                        MoreRow(label: "From \(source.displayName)", description: Self.howTo(source), value: "CSV") {
                            selectedImportSource = source
                            showImportPicker = true
                        }
                    }
                    OreSegmentedRow(label: "File weight unit", description: "The unit the file's weights use. Weights are stored in kg.",
                                    options: UnitPreference.allCases.map { ($0 == .kg ? "KG" : "LB", $0) }, selection: $importUnit)
                    if showsExport {
                        MoreSectionLabel(title: "EXPORT")
                        MoreRow(label: "Export all workouts", description: "Every set as a spreadsheet. Weights are in kg.", value: "CSV") { exportCSV() }
                        MoreRow(label: "Export full backup", description: "\(workoutCount) workouts as JSON. Weights are in kg.", value: "JSON") { exportJSON() }
                    }
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
            Text(importMessage)
        }
    }

    private var importMessage: String {
        var lines = ["\(selectedImportSource.displayName): \(importResult.summary)."]
        if importResult.warmupSets > 0 { lines.append("\(importResult.warmupSets) warm-up sets were kept but are not counted in stats.") }
        if !importResult.unmatchedExercises.isEmpty {
            lines.append("Not in the library (added as custom): " + importResult.unmatchedExercises.prefix(5).joined(separator: ", ")
                + (importResult.unmatchedExercises.count > 5 ? "…" : ""))
        }
        if let firstError = importResult.errors.first { lines.append("e.g. \(firstError)") }
        return lines.joined(separator: "\n")
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
                    importResult = try DataImportService.importStrongCSV(csvString, modelContext: modelContext, user: user, sourceUnit: importUnit)
                case .hevy:
                    importResult = try DataImportService.importHevyCSV(csvString, modelContext: modelContext, user: user, sourceUnit: importUnit)
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
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ore_workouts.json")
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
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ore_workouts.csv")
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
    var body: some View { DataExportView(onBack: onBack, showsExport: false) }
}
