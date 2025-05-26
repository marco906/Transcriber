import AVFoundation
import Foundation
import Speech
import WhisperKit
import AudioKit
import Observation

@Observable
class TranscribeViewModel {
    let segmentationModel = getResource("pyannote_segmentation", "onnx")
    let embeddingExtractorModel = getResource("nemo_en_speakernet_embedding", "onnx")
    
    // Audio conversion parameters for speech model
    private let requiredSampleRate: Double = 16000
    private let requiredBitDepth: UInt32 = 32
    private let requiredChannels: UInt32 = 1
    
    var running = false
    var convertedAudioURL: URL? = nil
    var transcriptionResults: [String] = []
    
    func runDiarization(waveFileName: String, numSpeakers: Int = 0, fullPath: URL? = nil) async {
        
        let waveFilePath = fullPath?.path ?? getResource(waveFileName, "wav")
        
        var config = sherpaOnnxOfflineSpeakerDiarizationConfig(
            segmentation: sherpaOnnxOfflineSpeakerSegmentationModelConfig(
                pyannote: sherpaOnnxOfflineSpeakerSegmentationPyannoteModelConfig(model: segmentationModel)),
            embedding: sherpaOnnxSpeakerEmbeddingExtractorConfig(model: embeddingExtractorModel),
            clustering: sherpaOnnxFastClusteringConfig(numClusters: numSpeakers)
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
            let pipe = try await WhisperKit()
            
            for segment in segments {
                try await transcribeSegment(segment: segment, audioArray: array, audioFormat: audioFormat, pipe: pipe)
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
        
        await MainActor.run {
            running = false
        }
    }
    
    private func transcribeSegment(segment: SherpaOnnxOfflineSpeakerDiarizationSegmentWrapper, audioArray: [Float], audioFormat: AVAudioFormat, pipe: WhisperKit) async throws {
        let start = String(format: "%.2f", segment.start)
        let end = String(format: "%.2f", segment.end)
        let speaker = segment.speaker
        
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
            transcriptionResults.append("\(start)\t-- \(end)\tspeaker_\(speaker)")
            transcriptionResults.append(text)
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
