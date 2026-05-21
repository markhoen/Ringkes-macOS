import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct PDFItem: Identifiable {
    let id = UUID()
    let url: URL
    var progress: Double = 0
    var status: String = "Waiting"
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
                        VStack(spacing: 10) {
                            
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 40))
                            
                            Text("Drag & Drop Multiple PDF")
                                .font(.title3)
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

            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier,
                              options: nil) { item, error in

                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data,
                                    relativeTo: nil) else {
                    return
                }

                DispatchQueue.main.async {

                    pdfs.append(PDFItem(url: url))

                    let index = pdfs.count - 1

                    processPDF(at: index)
                }
            }
        }
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

            let outputURL: URL
            let finalURL: URL

            if overwriteExisting {

                finalURL = inputURL

                outputURL = inputURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(UUID().uuidString + ".pdf")

            } else {

                finalURL = inputURL
                    .deletingPathExtension()
                    .appendingPathExtension("ringkes.pdf")

                outputURL = finalURL
            }

            let task = Process()

            guard let gsPath = Bundle.main.path(forResource: "gs", ofType: nil) else {

                DispatchQueue.main.async {
                    pdfs[index].status = "Ghostscript not found"
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
            task.standardError = Pipe()
            
            let errorPipe = Pipe()
            task.standardError = errorPipe

            DispatchQueue.main.async {
                pdfs[index].progress = 0.3
            }

            do {

                try task.run()
                print("Using GS:", actualGhostscriptPath)

            } catch {

                print("REAL ERROR:", error)

                DispatchQueue.main.async {
                    pdfs[index].status = "Error: \(error.localizedDescription)"
                    pdfs[index].progress = 0
                }

                return
            }

            task.waitUntilExit()
            
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if let errorOutput = String(data: errorData,
                                        encoding: .utf8) {

                print("GS ERROR:", errorOutput)
            }
            
            print("Termination Status:", task.terminationStatus)
            
            if overwriteExisting && task.terminationStatus == 0 {

                do {

                    try FileManager.default.removeItem(at: inputURL)

                    try FileManager.default.moveItem(at: outputURL,
                                                     to: finalURL)

                } catch {

                    DispatchQueue.main.async {
                        pdfs[index].status = "Replace failed"
                        pdfs[index].progress = 0
                    }

                    return
                }
            }

            if task.terminationStatus == 0 {

                DispatchQueue.main.async {
                    pdfs[index].progress = 1.0
                    pdfs[index].status = "Finished → \(finalURL.lastPathComponent)"
                }

            } else {

                DispatchQueue.main.async {
                    pdfs[index].status = "Ghostscript failed"
                    pdfs[index].progress = 0
                }
            }
        }
    }
    func checkGhostscript() {

        let possibleBrewPaths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]

        homebrewAvailable = possibleBrewPaths.contains {
            FileManager.default.fileExists(atPath: $0)
        }

        if let embeddedGS = Bundle.main.path(forResource: "gs",
                                             ofType: nil) {

            ghostscriptAvailable = true
            usingEmbeddedGhostscript = true
            ghostscriptPath = "Embedded Ghostscript"
            actualGhostscriptPath = embeddedGS

            return
        }

        let possibleGSPaths = [
            "/opt/homebrew/bin/gs",
            "/usr/local/bin/gs"
        ]

        if let foundGS = possibleGSPaths.first(where: {
            FileManager.default.fileExists(atPath: $0)
        }) {

            ghostscriptAvailable = true
            usingEmbeddedGhostscript = false
            ghostscriptPath = foundGS
            actualGhostscriptPath = foundGS

        } else {

            ghostscriptAvailable = false
            ghostscriptPath = "Ghostscript not found"
            showGhostscriptAlert = true
        }
    }
}

#Preview {
    ContentView()
}

