import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import Speech

struct MainView: View {
    @State private var model = TranscribeViewModel()
    @State private var showingFileImporter = false
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button("Select File with Audio") {
                    selectFileClicked()
                }
                Button("Use TestFile") {
                    testFileClicked()
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [UTType.audio],
                allowsMultipleSelection: false
            ) { result in
                fileSelected(result)
            }
            
            if model.running {
                ProgressView()
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Diarization Results:")
                        .font(.headline)
					ForEach(model.results) { transcription in
						TranscriptionView(transcription)
					}
                }
                .padding()
            }
        }
        .padding()
    }
    
    private func selectFileClicked() {
        showingFileImporter = true
    }
    
    private func fileSelected(_ result: Result<[URL], Error>) {
        do {
            let selectedFiles = try result.get()
            guard let url = selectedFiles.first else { return }
            Task {
                let convertedAudioURL = try await model.convertMediaToMonoFloat32WAV(inputURL: url)
                let fileName = convertedAudioURL.deletingPathExtension().lastPathComponent
                await model.runDiarization(waveFileName: fileName, fullPath: convertedAudioURL)
            }
        } catch {
            print("Failed to import file: \(error.localizedDescription)")
        }
    }
    
    private func testFileClicked() {
        Task {
            let fileName = "2-two-speakers-en"
            await model.runDiarization(waveFileName: fileName)
        }
    }
}

