//
//  ViewModel.swift
//  SpeechDiarizationStarter
//
//  Created by Carlos Mbendera on 28/02/2025.
//

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
        
        print("\(Date.now.timeIntervalSince1970) Started!")
        await MainActor.run {
            running = true
        }
        
        let segments = sd.process(samples: array)
        
        await MainActor.run {
            running = false
        }

        
        do {
            let pipe = try await WhisperKit()
            
            for i in 0..<segments.count {
                let segment = segments[i]
                let start = String(format: "%.2f", segment.start)
                let end = String(format: "%.2f", segment.end)
                let speaker = segment.speaker
                
                
                let sampleRate = Float(audioFormat.sampleRate)
                let startFrame = Int(segment.start * sampleRate)
                let endFrame = Int(segment.end * sampleRate)
                
                let segmentArray = Array(array[startFrame..<endFrame])
                
                let transcriptions = try await pipe.transcribe(audioArray: segmentArray)
                if transcriptions.reduce(0, {$0 + $1.text.count}) == 0 {
                    continue
                }
                await MainActor.run {
                    transcriptionResults.append("\(start)\t-- \(end)\tspeaker_\(speaker)")
                    for result in transcriptions {
                        transcriptionResults.append(result.text)
                    }
                }
            }
            
        } catch {
            print(error)
        }

        print("\(Date.now.timeIntervalSince1970) Finish!")
    }
    
    func convertMediaToMonoFloat32WAV(inputURL: URL) async throws -> URL {
        // Build the output WAV URL in the Documents directory.
        let finalWAVURL = makeWavOutputURL(for: inputURL)
        
        // Set up conversion options.
        var options = FormatConverter.Options()
        options.format = .wav
        //The Speech Model Expects A Sample Rate of 16000 and a mono file
        options.sampleRate = 16000
        options.bitDepth = 32
        options.channels = 1
        
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
