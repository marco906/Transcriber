//
//  AudioFileService.swift
//  Transcriber
//
//  Created by Marco Wenzel on 09.06.2025.
//

import Foundation
import AudioKit
import AVFoundation

enum AudioFileServiceError: LocalizedError {
    case bufferCreationFailed
    case arrayCreationFailed
    case fileReadFailed(Error)
    case conversionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .arrayCreationFailed:
            return "Failed to create audio array"
        case .fileReadFailed(let error):
            return "Failed to read audio file: \(error.localizedDescription)"
        case .conversionFailed(let error):
            return "Failed to convert audio file: \(error.localizedDescription)"
        }
    }
}

struct AudioFileServiceConfig {
    let requiredSampleRate: Double = 16000
    let requiredBitDepth: UInt32 = 32
    let requiredChannels: UInt32 = 1
}

class AudioFileService {
    static let shared = AudioFileService()
    
    var config = AudioFileServiceConfig()
    
    func convertMediaToMonoFloat32WAV(inputURL: URL) async throws -> URL {
        // Build the output WAV URL in the Documents directory.
        let finalWAVURL = makeWavOutputURL(for: inputURL)
        
        // Set up conversion options.
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = config.requiredSampleRate
        options.bitDepth = config.requiredBitDepth
        options.channels = config.requiredChannels
        
        // Create the converter.
        let converter = FormatConverter(inputURL: inputURL, outputURL: finalWAVURL, options: options)
        
        return try await withCheckedThrowingContinuation { continuation in
            converter.start { error in
                if let error {
                    continuation.resume(throwing: AudioFileServiceError.conversionFailed(error))
                } else {
                    continuation.resume(returning: finalWAVURL)
                }
            }
        }
    }
    
    /// Creates an AVAudioFile from a file URL
    /// - Parameter fileURL: The URL of the audio file
    /// - Returns: An AVAudioFile instance
    /// - Throws: AudioFileServiceError.fileReadFailed if the file cannot be read
    func createAudioFile(from fileURL: URL) throws -> AVAudioFile {
        do {
            return try AVAudioFile(forReading: fileURL)
        } catch {
            throw AudioFileServiceError.fileReadFailed(error)
        }
    }
    
    /// Creates an audio buffer array from an AVAudioFile
    /// - Parameter audioFile: The AVAudioFile to create the buffer from
    /// - Returns: The audio buffer array
    /// - Throws: AudioFileServiceError.bufferCreationFailed or AudioFileServiceError.arrayCreationFailed if buffer creation fails
    func createAudioBufferArray(from audioFile: AVAudioFile) throws -> [Float] {
        let audioFormat = audioFile.processingFormat
        let audioFrameCount = UInt32(audioFile.length)
        
        guard let audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount) else {
            throw AudioFileServiceError.bufferCreationFailed
        }
        
        do {
            try audioFile.read(into: audioFileBuffer)
        } catch {
            throw AudioFileServiceError.fileReadFailed(error)
        }
        
        return audioFileBuffer.array()
    }
    
    /// Creates an audio buffer array from a file URL
    /// - Parameter fileURL: The URL of the audio file
    /// - Returns: The audio buffer array
    /// - Throws: AudioFileServiceError if any step of the process fails
    func createAudioBufferSequence(from fileURL: URL) throws -> AudioBufferSequence {
        let audioFile = try createAudioFile(from: fileURL)
        let values = try createAudioBufferArray(from: audioFile)
        return AudioBufferSequence(values: values, format: audioFile.processingFormat)
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

struct AudioBufferSequence {
    var values: [Float]
    var format: AVAudioFormat
}

extension AudioBuffer {
    func array() -> [Float] {
        return Array(UnsafeBufferPointer(self))
    }
}

extension AVAudioPCMBuffer {
    func array() -> [Float] {
        return self.audioBufferList.pointee.mBuffers.array()
    }
}
