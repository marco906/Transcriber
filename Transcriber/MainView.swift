import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import Speech

struct MainView: View {
    @State private var model = TranscribeViewModel()
    @State private var showingFileImporter = false
    
    var body: some View {
        VStack(spacing: 10) {
            switch model.state {
            case .initial:
                newTranscriptionView
            case .recording:
                recordingView
            case .segmentation:
                processingView
            case .transcribing, .finished:
                resultsView
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Transcriber")
        .toolbar {
            toolbarContent
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            switch model.state {
            case .initial, .segmentation, .recording:
                EmptyView()
            case .transcribing:
                HStack(spacing: 12) {
                    Text("Transcribing...")
                        .font(.callout)
                    ProgressView()
                }
                .foregroundStyle(.secondary)
            case .finished:
                Button("Clear") {
                    model.results = []
                    model.state = .initial
                }
            }
        }
    }
    
    var recordingView: some View {
        VStack(spacing: 48) {
            VStack(spacing: 24) {
                waveIconView
                
                Text("Recording audio...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                ProgressView()
                
                Button {
                    stopRecordingClicked()
                } label: {
                    Label("Stop Recording", systemImage: "stop.circle")
                }
                .labelStyle(IconButtonLabelStyle())
                .buttonStyle(CustomButtonStyle())
            }
            .padding(.top, 100)

            Spacer()
        }
    }
    
    var processingView: some View {
        VStack(spacing: 48) {
            VStack(spacing: 24) {
                waveIconView
                
                Text("Identifying speakers...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                ProgressView()
            }
            .padding(.top, 100)

            Spacer()
        }
        .padding()
    }

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(model.results) { transcription in
                    TranscriptionView(transcription)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical)
        }
        .animation(.default, value: model.results)
    }
    
    private var newTranscriptionView: some View {
        VStack(spacing: 48) {            
            VStack(spacing: 24) {
                waveIconView
                
                Text("Start recording or import an audio file to begin the transcription.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 100)
            
            HStack(spacing: 16) {
                Button {
                    startRecordingClicked()
                } label: {
                    Label("Record", systemImage: "record.circle")
                }
                
                Button {
                    importFileClicked()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .fileImporter(
                    isPresented: $showingFileImporter,
                    allowedContentTypes: [UTType.audio],
                    allowsMultipleSelection: false
                ) { result in
                    fileSelected(result)
                }
                
                Button {
                    demoFileClicked()
                } label: {
                    Label("Demo", systemImage: "music.note.list")
                }
            }
            .labelStyle(IconButtonLabelStyle())
            .buttonStyle(CustomButtonStyle())
            
            Spacer()
        }
        .padding()
    }

    private var waveIconView: some View {
        Image(systemName: "waveform")
            .foregroundStyle(Color.accentColor)
            .font(.system(size: 120))
    }

    private func startRecordingClicked() {
        Task {
            await model.startRecordAudio()
        }
    }
    
    private func stopRecordingClicked() {
        Task {
            await model.stopRecordAudio()
        }
    }
    
    private func importFileClicked() {
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
    
    private func demoFileClicked() {
        Task {
            let fileName = "en_audio_1"
            await model.runDiarization(waveFileName: fileName)
        }
    }
}

struct IconButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 4) {
            configuration.icon
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24)
            configuration.title
                .font(.subheadline)
        }
    }
}

struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                shape
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .overlay {
                shape.stroke(Color(uiColor: .secondarySystemFill) , lineWidth: 1.5)
            }
            .foregroundStyle(.primary)
            .contentShape(shape)
    }
    
    var shape: some Shape {
        RoundedRectangle(cornerRadius: 8)
    }
}
