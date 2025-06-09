//
//  AudioRecorder.swift
//  Transcriber
//
//  Created by Marco Wenzel on 08.06.2025.
//

import Foundation
import AVFoundation

/// Defines possible errors for the audio recorder, conforming to `LocalizedError`.
enum AudioRecordingServiceError: LocalizedError {
    case permissionDenied
    case sessionSetupFailed(underlying: Error)
    case noActiveRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission was denied."
        case .sessionSetupFailed(let underlying):
            return "Failed to set up audio session: \(underlying.localizedDescription)"
        case .noActiveRecording:
            return "No active recording to stop."
        }
    }
}

/// A simple audio recorder that saves a .wav file to the temp directory, using async/await and `AudioRecorderError`.
final class AudioRecordingService: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private let fileURL: URL

    override init() {
        let filename = UUID().uuidString + ".wav"
        self.fileURL = URL.temporaryDirectory.appendingPathComponent(filename)
        super.init()
    }
    
    static let shared = AudioRecordingService()

    /// Requests microphone permission, throws `AudioRecorderError.permissionDenied` or `AudioRecorderError.sessionSetupFailed`.
    private func requestPermission() async throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            throw AudioRecordingServiceError.sessionSetupFailed(underlying: error)
        }
        
        if await AVAudioApplication.requestRecordPermission() {
            return
        } else {
            throw AudioRecordingServiceError.permissionDenied
        }
    }

    /// Starts recording audio to a .wav file. Throws `AudioRecorderError`.
    func startRecording() async throws {
        // 1. Ensure permission
        try await requestPermission()

        // 2. Recording settings for WAV (Linear PCM)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        // 3. Create the recorder
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        } catch {
            throw AudioRecordingServiceError.sessionSetupFailed(underlying: error)
        }
        audioRecorder?.delegate = self
        audioRecorder?.prepareToRecord()

        // 4. Start recording
        audioRecorder?.record()
        print("▶️ Recording started: \(fileURL.path)")
    }

    /// Stops recording and returns the URL of the .wav file. Throws `AudioRecorderError.noActiveRecording`.
    func stopRecording() async throws -> URL {
        guard let recorder = audioRecorder, recorder.isRecording else {
            throw AudioRecordingServiceError.noActiveRecording
        }

        recorder.stop()
        audioRecorder = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            // If deactivating fails, we still have the file on disk.
            print("⚠️ Warning: Failed to deactivate audio session: \(error.localizedDescription)")
        }

        print("⏹ Recording stopped. File saved to: \(fileURL.path)")
        return fileURL
    }
}

extension AudioRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("✅ Recording finished successfully.")
        } else {
            print("⚠️ Recording finished unsuccessfully.")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let err = error {
            print("❌ Encoding error occurred: \(err.localizedDescription)")
        }
    }
}
