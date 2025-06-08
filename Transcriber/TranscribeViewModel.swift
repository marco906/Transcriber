import AVFoundation
import Foundation
import Speech
import WhisperKit
import AudioKit
import Observation

enum TranscriptionError: LocalizedError {
    case recognizerNotAvailable
    case transcriptionFailed
    case noTranscriptionResult
    case notAuthorized
    case audioBufferCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "Speech recognizer is not available"
        case .transcriptionFailed:
            return "Failed to transcribe audio"
        case .noTranscriptionResult:
            return "No transcription result available"
        case .notAuthorized:
            return "Speech recognition is not authorized"
        case .audioBufferCreationFailed:
            return "Failed to create audio buffer"
        }
    }
}

@Observable
class TranscribeViewModel {
    let segmentationModel = getResource("pyannote_segmentation", "onnx")
    let embeddingExtractorModel = getResource("nemo_en_titanet_small", "onnx")
    
    // Audio conversion parameters for speech model
    private let requiredSampleRate: Double = 16000
    private let requiredBitDepth: UInt32 = 32
    private let requiredChannels: UInt32 = 1
    
    var running = false
    var convertedAudioURL: URL? = nil
    var results: [Transcription] = []
    
    func runDiarization(waveFileName: String, numSpeakers: Int = 0, fullPath: URL? = nil) async {
        
        let waveFilePath = fullPath?.path ?? getResource(waveFileName, "wav")
        
        var config = sherpaOnnxOfflineSpeakerDiarizationConfig(
            segmentation: sherpaOnnxOfflineSpeakerSegmentationModelConfig(
                pyannote: sherpaOnnxOfflineSpeakerSegmentationPyannoteModelConfig(model: segmentationModel),
                numThreads: 4
            ),
            embedding: sherpaOnnxSpeakerEmbeddingExtractorConfig(
                model: embeddingExtractorModel,
                numThreads: 4
            ),
            clustering: sherpaOnnxFastClusteringConfig(numClusters: numSpeakers),
            minDurationOn: 0.1,
            minDurationOff: 0.6
        )
        
        let sd = SherpaOnnxOfflineSpeakerDiarizationWrapper(config: &config)
        
        let fileURL = URL(string: waveFilePath)!
        let audioFile = try! AVAudioFile(forReading: fileURL)
        
        let audioFormat = audioFile.processingFormat
        let audioFrameCount = UInt32(audioFile.length)
        
        guard let audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount) else {
            print("Failed to create audio buffer")
            return
        }
        
        try! audioFile.read(into: audioFileBuffer)
        let array: [Float]! = audioFileBuffer.array()
        
        let startTime = Date.now.timeIntervalSince1970
        
        await MainActor.run {
            running = true
        }
        
        // Start segmentation timing
        let segmentationStartTime = Date.now.timeIntervalSince1970
        let segments = sd.process(samples: array)
        let segmentationEndTime = Date.now.timeIntervalSince1970
        let segmentationTime = segmentationEndTime - segmentationStartTime
        print("Segmentation time: \(String(format: "%.2f", segmentationTime)) seconds")
        
        // Start transcription timing
        let transcriptionStartTime = Date.now.timeIntervalSince1970
        
        do {
            await MainActor.run {
                running = false
            }
            
            guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                throw TranscriptionError.notAuthorized
            }
            
            for segment in segments {
                print("Segment: Speaker \(segment.speaker), start: \(String(format: "%.2f", segment.start))")
                try? await transcribeSegmentNative(segment: segment, audioArray: array, audioFormat: audioFormat)
            }
            
        } catch {
            print(error)
        }
        
        let transcriptionEndTime = Date.now.timeIntervalSince1970
        let transcriptionTime = transcriptionEndTime - transcriptionStartTime
        print("Transcription time: \(String(format: "%.2f", transcriptionTime)) seconds")
        
        let endTime = Date.now.timeIntervalSince1970
        let totalTime = endTime - startTime
        print("Total processing time: \(String(format: "%.2f", totalTime)) seconds")
    }
    
    private func transcribeSegment(segment: SherpaOnnxOfflineSpeakerDiarizationSegmentWrapper, audioArray: [Float], audioFormat: AVAudioFormat, pipe: WhisperKit) async throws {
        let sampleRate = Float(audioFormat.sampleRate)
        let startFrame = Int(segment.start * sampleRate)
        let endFrame = Int(segment.end * sampleRate)
        
        let segmentArray = Array(audioArray[startFrame..<endFrame])
        
        let transcriptions = try await pipe.transcribe(audioArray: segmentArray)
        let text = transcriptions.map { $0.text }.joined(separator: " ")
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        
        await MainActor.run {
			results.append(
				.init(speakerId: segment.speaker, start: segment.start, end: segment.end, text: text)
			)
        }
    }
    
    private func transcribeSegmentNative(segment: SherpaOnnxOfflineSpeakerDiarizationSegmentWrapper, audioArray: [Float], audioFormat: AVAudioFormat) async throws {
        let locale = Locale(identifier: "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw TranscriptionError.recognizerNotAvailable
        }
        
        let sampleRate = Float(audioFormat.sampleRate)
        let startFrame = Int(segment.start * sampleRate)
        let endFrame = Int(segment.end * sampleRate)
        
        var segmentArray = Array(audioArray[startFrame..<endFrame])
        var buffer: AVAudioPCMBuffer? = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(segmentArray.count))
        
        segmentArray.withUnsafeMutableBufferPointer { umrbp in
            let audioBuffer = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(umrbp.count * MemoryLayout<Float>.size), mData: umrbp.baseAddress)
            var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
            buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, bufferListNoCopy: &bufferList)
        }

        guard let buffer else {
            throw TranscriptionError.audioBufferCreationFailed
        }
        
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        recognizer.supportsOnDeviceRecognition = true
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = false

        recognitionRequest.append(buffer)
        recognitionRequest.endAudio()
        
        let text = try await recognizer.recognize(request: recognitionRequest)
        
        await MainActor.run {
            self.results.append(
                .init(speakerId: segment.speaker, start: segment.start, end: segment.end, text: text)
            )
        }
    }
    
    func convertMediaToMonoFloat32WAV(inputURL: URL) async throws -> URL {
        // Build the output WAV URL in the Documents directory.
        let finalWAVURL = makeWavOutputURL(for: inputURL)
        
        // Set up conversion options.
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = requiredSampleRate
        options.bitDepth = requiredBitDepth
        options.channels = requiredChannels
        
        // Create the converter.
        let converter = FormatConverter(inputURL: inputURL, outputURL: finalWAVURL, options: options)
        
        return try await withCheckedThrowingContinuation { continuation in
            converter.start { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: finalWAVURL)
                }
            }
        }
    }
    
    /// Helper: Builds a .wav output URL in the Documents directory based on the input file's name.
    private func makeWavOutputURL(for inputURL: URL) -> URL {
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        
        let fileName = "converted_\(dateString)_\(baseName).wav"
        let documentsDir = URL.temporaryDirectory
        return documentsDir.appendingPathComponent(fileName)
    }
}

extension SFSpeechRecognizer {
    /// Checks if the app has authorization to perform speech recognition.
    /// - Returns: `true` if authorized, `false` otherwise.
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// Performs speech recognition on an audio buffer request asynchronously.
    /// - Parameter request: The speech recognition request containing the audio buffer.
    /// - Returns: The transcribed text as a string.
    /// - Throws: A `TranscriptionError` if recognition fails or if no transcription is available.
    func recognize(request: SFSpeechAudioBufferRecognitionRequest) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            recognitionTask(with: request) { (transcriptionResult, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = transcriptionResult else {
                    continuation.resume(throwing: TranscriptionError.noTranscriptionResult)
                    return
                }
                
                if result.isFinal {
                    let text = result.bestTranscription.formattedString
                    continuation.resume(returning: text)
                }
            }
        }
    }
}
