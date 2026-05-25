
import SwiftUI
import UniformTypeIdentifiers
import AppKit
import PDFKit

struct PDFItem: Identifiable {

    let id = UUID()
    let url: URL
    
    var originalURL: URL? = nil

    var progress: Double = 0
    var status: String = "Waiting"

    var isTemporary: Bool = false
}

struct ContentView: View {

    @State private var isTargeted = false
    @State private var pdfs: [PDFItem] = []
    @State private var overwriteExisting = false
    @State private var ghostscriptAvailable = false
    @State private var homebrewAvailable = false
    @State private var usingEmbeddedGhostscript = false
    @State private var ghostscriptPath = "-"
    @State private var showGhostscriptAlert = false
    @State private var actualGhostscriptPath = ""

    var body: some View {

        VStack {
            VStack(spacing: 20) {
                
                HStack(alignment: .center) {
                    
                    Spacer()
                        .frame(width: 30)
                    
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .shadow(radius: 8)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        
                        Text("Ringkes")
                            .font(.largeTitle)
                            .bold()
                        
                        Text("Cilik Ukurane, Gedhe Manfaate")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("Overwrite Original File(s)", isOn: $overwriteExisting)
                        .toggleStyle(.checkbox)
                        .frame(width: 200)
                }
                .padding(.horizontal)
                HStack(spacing: 20) {

                    Label {

                        Text("Ghostscript")
                            .font(.caption)

                    } icon: {

                        Circle()
                            .fill(ghostscriptAvailable ? .green : .red)
                            .frame(width: 10, height: 10)
                    }

                    Label {

                        Text("Homebrew")
                            .font(.caption)

                    } icon: {

                        Circle()
                            .fill(homebrewAvailable ? .green : .red)
                            .frame(width: 10, height: 10)
                    }

                    Spacer()

                    Text(ghostscriptPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isTargeted ? .blue : .gray,
                            style: StrokeStyle(lineWidth: 3, dash: [10]))
                    .frame(height: 120)
                    .overlay(
                        VStack(spacing: 8) {
                            
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 40))
                            
                            Text("Drag & Drop PDF or Images")
                                .font(.title3)
                            
                            Text("PDF COMPRESS • IMAGE TO PDF")
                                .font(.caption2)
                                .tracking(1)
                                .foregroundStyle(.secondary)
                        }
                    )
                    .padding(.horizontal)
                    .onDrop(of: [UTType.fileURL],
                            isTargeted: $isTargeted) { providers in
                        
                        handleDrop(providers: providers)
                        return true
                    }
                
                List {
                    
                    ForEach(pdfs.indices, id: \.self) { index in
                        
                        VStack(alignment: .leading, spacing: 8) {
                            
                            Text(pdfs[index].url.lastPathComponent)
                                .font(.headline)
                            
                            ProgressView(value: pdfs[index].progress)
                            
                            Text(pdfs[index].status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            Spacer()
        }
        .frame(
            minWidth: 500,
            maxWidth: .infinity,
            minHeight: 400,
            maxHeight: .infinity,
            alignment: .top
        )
        .padding()
        .onAppear {

            checkGhostscript()
        }
        .alert("Ghostscript Required",
               isPresented: $showGhostscriptAlert) {

            Button("Open Website") {

                if let url = URL(string: "https://ghostscript.com/releases/gsdnld.html") {

                    NSWorkspace.shared.open(url)
                }
            }

            Button("OK", role: .cancel) { }

        } message: {

            Text("""
        Ringkes membutuhkan Ghostscript untuk memproses PDF.

        Install via Homebrew:

        brew install ghostscript
        """)
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) {

        for provider in providers {

            provider.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier,
                options: nil
            ) { item, error in

                guard let data = item as? Data,
                      let url = URL(
                        dataRepresentation: data,
                        relativeTo: nil
                      ) else {
                    return
                }

                DispatchQueue.main.async {

                    if isPDFFile(url) {

                        pdfs.append(PDFItem(url: url))

                        let index = pdfs.count - 1

                        processPDF(at: index)

                    } else if isImageFile(url) {

                        convertImageToPDF(imageURL: url)

                    } else {

                        print("Unsupported file:", url)
                    }
                }
            }
        }
    }
    
    func convertImageToPDF(imageURL: URL) {

        guard let image = NSImage(contentsOf: imageURL),
              let page = PDFPage(image: image) else {
            return
        }

        let pdfDocument = PDFDocument()

        pdfDocument.insert(page, at: 0)

        let tempPDFURL = imageURL
            .deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".pdf")

        pdfDocument.write(to: tempPDFURL)

        pdfs.append(
            PDFItem(
                url: tempPDFURL,
                originalURL: imageURL,
                progress: 0,
                status: "Converting...",
                isTemporary: true
            )
        )

        let index = pdfs.count - 1

        processPDF(at: index)
    }

    func processPDF(at index: Int) {
        
        if !ghostscriptAvailable {

            DispatchQueue.main.async {
                pdfs[index].status = "Ghostscript not installed"
            }

            return
        }

        DispatchQueue.global(qos: .userInitiated).async {

            DispatchQueue.main.async {
                pdfs[index].status = "Processing..."
                pdfs[index].progress = 0.1
            }

            let inputURL = pdfs[index].url

            let originalAttributes =
                try? FileManager.default.attributesOfItem(
                    atPath: inputURL.path
                )

            let originalModifiedDate =
                originalAttributes?[.modificationDate] as? Date

            // =========================================
            // DETECT REAL PDF OR IMAGE CONVERSION
            // =========================================

            let isRealPDF =
                pdfs[index].originalURL == nil

            let allowOverwrite =
                overwriteExisting && isRealPDF

            let namingSource =
                pdfs[index].originalURL ?? inputURL

            let outputURL: URL
            let finalURL: URL

            // =========================================
            // OVERWRITE ONLY FOR REAL PDF
            // =========================================

            if allowOverwrite {

                finalURL = inputURL

                outputURL = inputURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(
                        UUID().uuidString + ".pdf"
                    )

            } else {

                finalURL = namingSource
                    .deletingPathExtension()
                    .appendingPathExtension("ringkes.pdf")

                outputURL = finalURL
            }

            let task = Process()

            let gsPath = actualGhostscriptPath

            if gsPath.isEmpty {

                DispatchQueue.main.async {

                    pdfs[index].status =
                        "Ghostscript not found"

                    pdfs[index].progress = 0
                }

                return
            }

            task.launchPath = gsPath

            task.arguments = [
                "-sDEVICE=pdfwrite",
                "-dCompatibilityLevel=1.4",
                "-dPDFSETTINGS=/ebook",
                "-dDetectDuplicateImages=true",
                "-dCompressFonts=true",
                "-dSubsetFonts=true",
                "-dNOPAUSE",
                "-dBATCH",
                "-sOutputFile=\(outputURL.path)",
                inputURL.path
            ]

            task.standardOutput = Pipe()

            let errorPipe = Pipe()

            task.standardError = errorPipe

            DispatchQueue.main.async {
                pdfs[index].progress = 0.3
            }

            do {

                try task.run()

                print("Using GS:",
                      actualGhostscriptPath)

            } catch {

                print("REAL ERROR:", error)

                DispatchQueue.main.async {

                    pdfs[index].status =
                        "Error: \(error.localizedDescription)"

                    pdfs[index].progress = 0
                }

                return
            }

            task.waitUntilExit()

            let errorData =
                errorPipe.fileHandleForReading
                    .readDataToEndOfFile()

            if let errorOutput =
                String(data: errorData,
                       encoding: .utf8) {

                print("GS ERROR:", errorOutput)
            }

            print("Termination Status:",
                  task.terminationStatus)

            // =========================================
            // SUCCESS
            // =========================================

            if task.terminationStatus == 0 {

                // =====================================
                // REAL PDF OVERWRITE
                // =====================================

                if allowOverwrite {

                    do {

                        let backupURL =
                            finalURL.appendingPathExtension(
                                "backup"
                            )

                        try? FileManager.default
                            .removeItem(at: backupURL)

                        try FileManager.default.copyItem(
                            at: finalURL,
                            to: backupURL
                        )

                        try FileManager.default
                            .removeItem(at: finalURL)

                        try FileManager.default.moveItem(
                            at: outputURL,
                            to: finalURL
                        )

                        try? FileManager.default
                            .removeItem(at: backupURL)

                        // restore modified date
                        if let modifiedDate =
                            originalModifiedDate {

                            try? FileManager.default
                                .setAttributes(
                                    [.modificationDate:
                                        modifiedDate],
                                    ofItemAtPath:
                                        finalURL.path
                                )
                        }

                    } catch {

                        DispatchQueue.main.async {

                            pdfs[index].status =
                                "Overwrite failed"

                            pdfs[index].progress = 0
                        }

                        return
                    }
                }

                // =====================================
                // NON OVERWRITE PDF
                // =====================================

                else {

                    // preserve date ONLY for real PDF
                    if isRealPDF,
                       let modifiedDate =
                        originalModifiedDate {

                        try? FileManager.default
                            .setAttributes(
                                [.modificationDate:
                                    modifiedDate],
                                ofItemAtPath:
                                    finalURL.path
                            )
                    }
                }

                // =====================================
                // DELETE TEMP FILE
                // =====================================

                if pdfs[index].isTemporary {

                    try? FileManager.default
                        .removeItem(at: inputURL)
                }

                DispatchQueue.main.async {

                    pdfs[index].progress = 1.0

                    pdfs[index].status =
                        "Finished → \(finalURL.lastPathComponent)"
                }

            } else {

                DispatchQueue.main.async {

                    pdfs[index].status =
                        "Ghostscript failed"

                    pdfs[index].progress = 0
                }
            }
        }
    }
    func checkGhostscript() {

        // ================================
        // CHECK HOMEBREW
        // ================================

        let possibleBrewPaths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]

        homebrewAvailable = possibleBrewPaths.contains {
            FileManager.default.fileExists(atPath: $0)
        }

        // ================================
        // DETECT ARCHITECTURE
        // ================================

        let arch = currentArchitecture()

        print("Current Arch:", arch)

        // ================================
        // PRIORITY 1:
        // EMBEDDED GS
        // ================================

        var embeddedName = ""

        if arch == "arm64" {

            embeddedName = "gs-arm64"

        } else if arch == "x86_64" {

            embeddedName = "gs-x86_64"
        }

        if let embeddedGS =
            Bundle.main.path(
                forResource: embeddedName,
                ofType: nil
            ) {

            ghostscriptAvailable = true

            usingEmbeddedGhostscript = true

            actualGhostscriptPath = embeddedGS

            ghostscriptPath =
                "Embedded \(arch)"

            print("Using EMBEDDED GS:",
                  embeddedGS)

            return
        }

        // ================================
        // PRIORITY 2:
        // SYSTEM GS
        // ================================

        let systemGSPaths = [
            "/opt/homebrew/bin/gs",
            "/usr/local/bin/gs",
            "/opt/local/bin/gs"
        ]

        if let foundGS = systemGSPaths.first(where: {
            FileManager.default.fileExists(atPath: $0)
        }) {

            ghostscriptAvailable = true

            usingEmbeddedGhostscript = false

            actualGhostscriptPath = foundGS

            ghostscriptPath =
                "System GS"

            print("Using SYSTEM GS:",
                  foundGS)

            return
        }

        // ================================
        // GS NOT FOUND
        // ================================

        ghostscriptAvailable = false

        ghostscriptPath =
            "Ghostscript not found"

        showGhostscriptAlert = true
    }
    
    func currentArchitecture() -> String {

        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

func isImageFile(_ url: URL) -> Bool {

    guard let type =
        UTType(filenameExtension: url.pathExtension)
    else {
        return false
    }

    return type.conforms(to: .image)
}

func isPDFFile(_ url: URL) -> Bool {

    url.pathExtension.lowercased() == "pdf"
}

#Preview {
    ContentView()
}
