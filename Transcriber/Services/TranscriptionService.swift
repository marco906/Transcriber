//
//  TranscriptionService.swift
//  Transcriber
//
//  Created by Marco Wenzel on 09.06.2025.
//

import Foundation
import Speech

enum TranscriptionServiceError: LocalizedError {
    case recognizerNotAvailable
    case audioBufferCreationFailed
    case noTranscriptionResult
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "Speech recognition is not available for the specified locale"
        case .audioBufferCreationFailed:
            return "Failed to create audio buffer for transcription"
        case .noTranscriptionResult:
            return "No transcription result was available"
        case .notAuthorized:
            return "Speech recognition is not authorized"
        }
    }
}

class TranscriptionService {
    static let shared = TranscriptionService()
    
    func checkAuthorization() async throws {
        guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
            throw TranscriptionServiceError.notAuthorized
        }
    }
    
    func transcribeSegment(start: Float, end: Float, audioArray: [Float], audioFormat: AVAudioFormat, locale: Locale = Locale(identifier: "en-US")) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw TranscriptionServiceError.recognizerNotAvailable
        }
        
        let sampleRate = Float(audioFormat.sampleRate)
        let startFrame = Int(start * sampleRate)
        let endIndex = audioArray.endIndex
        let endFrame = min(endIndex, Int(end * sampleRate))
        
        var segmentArray = Array(audioArray[startFrame..<endFrame])
        var buffer: AVAudioPCMBuffer? = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(segmentArray.count))
        
        segmentArray.withUnsafeMutableBufferPointer { umrbp in
            let audioBuffer = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(umrbp.count * MemoryLayout<Float>.size), mData: umrbp.baseAddress)
            var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
            buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, bufferListNoCopy: &bufferList)
        }

        guard let buffer else {
            throw TranscriptionServiceError.audioBufferCreationFailed
        }
        
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        recognizer.supportsOnDeviceRecognition = true
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = false

        recognitionRequest.append(buffer)
        recognitionRequest.endAudio()
        
        let text = try await recognizer.recognize(request: recognitionRequest)
        return text
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
    /// - Throws: A `TranscriptionServiceError` if recognition fails or if no transcription is available.
    func recognize(request: SFSpeechAudioBufferRecognitionRequest) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            recognitionTask(with: request) { (transcriptionResult, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = transcriptionResult else {
                    continuation.resume(throwing: TranscriptionServiceError.noTranscriptionResult)
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
