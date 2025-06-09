import AVFoundation
import Foundation
import Speech
import AudioKit
import Observation

enum TranscriptionModelState {
    case initial
    case recording
    case segmentation
    case transcribing
    case finished
}

enum TranscriptionError: LocalizedError {
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .transcriptionFailed:
            return "Failed to transcribe audio"
        }
    }
}

@Observable
class TranscriptionViewModel {
    var state: TranscriptionModelState = .initial
    var convertedAudioURL: URL? = nil
    var results: [Transcription] = []
    
    private var recorder = AudioRecordingService.shared
    private var transcriber = TranscriptionService.shared
    private var audioFileService = AudioFileService.shared
    private var diarizationService = DiarizationService.shared
    
    func startRecordAudio() async {
        do {
            state = .recording
            try await recorder.startRecording()
        } catch {
            state = .initial
            print(error.localizedDescription)
        }
    }

    func stopRecordAudio() async {
        do {
            state = .segmentation
            let url = try await recorder.stopRecording()
            await runDiarization(waveFileName: url.lastPathComponent, fullPath: url)
        } catch {
            state = .initial
            print(error.localizedDescription)
        }
    }
    
    func audioFileSelected(_ result: Result<[URL], Error>) {
        do {
            let selectedFiles = try result.get()
            guard let url = selectedFiles.first else { return }
            Task {
                let convertedAudioURL = try await audioFileService.convertMediaToMonoFloat32WAV(inputURL: url)
                let fileName = convertedAudioURL.deletingPathExtension().lastPathComponent
                await runDiarization(waveFileName: fileName, fullPath: convertedAudioURL)
            }
        } catch {
            print("Failed to import file: \(error.localizedDescription)")
        }
    }
    
    func runDiarization(waveFileName: String, fullPath: URL? = nil) async {
        let waveFilePath = fullPath?.path ?? getResource(waveFileName, "wav")
        let fileURL = URL(filePath: waveFilePath)
        
        var config = diarizationService.createDiarizationConfig()
        let sd = SherpaOnnxOfflineSpeakerDiarizationWrapper(config: &config)
        
        let startTime = Date.now.timeIntervalSince1970
        state = .segmentation
        
        let audioFile = try! audioFileService.createAudioFile(from: fileURL)
        let array = try! audioFileService.createAudioBufferArray(from: audioFile)
        let audioFormat = audioFile.processingFormat
        
        // Start segmentation timing
        let segmentationStartTime = Date.now.timeIntervalSince1970
        let segments = sd.process(samples: array)
        let segmentationEndTime = Date.now.timeIntervalSince1970
        let segmentationTime = segmentationEndTime - segmentationStartTime
        print("Segmentation time: \(String(format: "%.2f", segmentationTime)) seconds")
        
        // Start transcription timing
        let transcriptionStartTime = Date.now.timeIntervalSince1970

        do {            
            try await transcriber.checkAuthorization()
            
            for segment in segments {
                print("Segment: Speaker \(segment.speaker), start: \(String(format: "%.2f", segment.start))")
                try? await transcribeSegmentNative(segment: segment, audioArray: array, audioFormat: audioFormat)
                if state != .transcribing {
                    state = .transcribing
                }
            }
            
            state = .finished
            
        } catch {
            print(error)
            state = .initial
        }
        
        let transcriptionEndTime = Date.now.timeIntervalSince1970
        let transcriptionTime = transcriptionEndTime - transcriptionStartTime
        print("Transcription time: \(String(format: "%.2f", transcriptionTime)) seconds")
        
        let endTime = Date.now.timeIntervalSince1970
        let totalTime = endTime - startTime
        print("Total processing time: \(String(format: "%.2f", totalTime)) seconds")
    }
    
    private func transcribeSegmentNative(segment: SherpaOnnxOfflineSpeakerDiarizationSegmentWrapper, audioArray: [Float], audioFormat: AVAudioFormat) async throws {
        let text = try await transcriber.transcribeSegment(
            start: segment.start,
            end: segment.end,
            audioArray: audioArray,
            audioFormat: audioFormat
        )
        
        let isContinuation = results.last?.speakerId == segment.speaker
        
        await MainActor.run {
            self.results.append(
                .init(speakerId: segment.speaker, start: segment.start, end: segment.end, text: text, isContinuation: isContinuation)
            )
        }
    }
    
    private func getResource(_ forResource: String, _ ofType: String) -> String {
        let path = Bundle.main.path(forResource: forResource, ofType: ofType)
        return path!
    }
}
