//
//  TranscriberTests.swift
//  TranscriberTests
//
//  Created by Marco Wenzel on 09.06.2025.
//

import Testing
import Foundation
@testable import Transcriber

@Suite("EvaluationTests")
class EvaluationTests {
    @Test
    func testDiarizationForAcademicData() async throws {
        try await testDiarizationFor(dataSet: "academic")
    }
    
    @Test
    func testDiarizationForPhoneCallData() async throws {
        try await testDiarizationFor(dataSet: "phonecall")
    }
    
    func testDiarizationFor(dataSet: String, count: Int = 5) async throws {
        let bundle = Bundle.init(for: EvaluationTests.self)
        let audioService = AudioFileService.shared
        let diarizationService = DiarizationService.shared
        diarizationService.config.numThreads = 4
        diarizationService.config.minDurationOn = 0.10
        diarizationService.config.minDurationOff = 0.55
        diarizationService.config.numSpeakers = 2
        diarizationService.config.threshold = 0.7
        
        let transcriptionService = TranscriptionService.shared
        try await transcriptionService.checkAuthorization()
        
        var totalDuration: Double = 0
        var totalDiarizationTime: Double = 0
        var totalWER: Double = 0
        var totalDER: Double = 0
        var totalConfusion: Double = 0
        var totalFalseAlarm: Double = 0
        var totalMissed: Double = 0
        var totalReferenceDuration: Double = 0
        var totalTranscriptionTime: Double = 0
        var totalProcessingTime: Double = 0
        
        // Print table header
        print("\nDiarization Test Results for \(dataSet) num Threads: \(diarizationService.config.numThreads)")
        print("┌─────┬────────────┬──────────────┬──────────────┬──────────────┬──────────┬──────────┬──────────┬──────────┬──────────┐")
        print("│ ID  │ Duration   │ Time Diariz. │ Time Transcr.│ Time Total   │   WER    │   DER    │ Confuse  │ FAlarm   │ Missed   │")
        print("├─────┼────────────┼──────────────┼──────────────┼──────────────┼──────────┼──────────┼──────────┼──────────┤──────────┤")
        
        // Test files 1-5
        for fileId in 1...count {
            let basePath = "en_\(dataSet)_\(fileId)"
            // Load ground truth data
            let groundTruthURL = bundle.url(forResource: basePath + "_segments", withExtension: "json")!
            let groundTruthData = try Data(contentsOf: groundTruthURL)
            let groundTruth = try JSONDecoder().decode(GroundTruthData.self, from: groundTruthData)
            let reference = groundTruth.segments
            
            // Load audio file
            let audioURL = bundle.url(forResource: basePath + "_audio", withExtension: "wav")!
            let audioBufferSequence = try audioService.createAudioBufferSequence(from: audioURL)
            let samples = audioBufferSequence.values
            let audioFormat = audioBufferSequence.format
            
            // Run diarization and measure time
            let startTime = Date()
            let predictions = diarizationService.rundDiarization(samples: samples)
            let diarizationTime = Date().timeIntervalSince(startTime)
            
            // Convert predictions to Segment format
            let hypothesis = predictions.map { segment in
                Segment(speakerId: segment.speaker, start: segment.start, end: segment.end)
            }
            
            // Calculate DER metrics
            let derResult = DiarizationMetrics.calculateDER(reference: reference, hypothesis: hypothesis, collar: 0.25)
            
            // Transcribe
            let transcriptionStartTime = Date()
            var hypothesisText: String = ""
            for prediction in predictions {
                if let segmentTranscription = try? await transcriptionService.transcribeSegment(
                    start: prediction.start,
                    end: prediction.end,
                    audioArray: samples,
                    audioFormat: audioFormat
                ) {
                    hypothesisText += " " + segmentTranscription
                }
            }
            let transcriptionTime = Date().timeIntervalSince(transcriptionStartTime)
            
            let processingTime = diarizationTime + transcriptionTime
            
            // Calculate WER metric
            let referenceText = groundTruth.text
            let werResult = DiarizationMetrics.calculateWER(reference: referenceText, hypothesis: hypothesisText)
            
            totalDuration += groundTruth.duration
            totalDiarizationTime += diarizationTime
            totalTranscriptionTime += transcriptionTime
            totalProcessingTime += processingTime
            totalWER += Double(werResult.wer)
            totalDER += Double(derResult.der)
            totalConfusion += Double(derResult.confusion)
            totalFalseAlarm += Double(derResult.falseAlarm)
            totalMissed += Double(derResult.missedDetection)
            totalReferenceDuration += Double(derResult.totalDuration)
            
            // Print results row
            print(String(format: "│ %2d  │ %10.2f │ %12.2f │ %12.2f │ %12.2f │ %8.3f │ %8.3f │ %8.3f │ %8.3f │ %8.3f │",
                         fileId,
                         groundTruth.duration,
                         diarizationTime,
                         transcriptionTime,
                         processingTime,
                         werResult.wer,
                         derResult.der,
                         derResult.confusion / derResult.totalDuration,
                         derResult.falseAlarm / derResult.totalDuration,
                         derResult.missedDetection / derResult.totalDuration))
        }
        
        let fileCount = Double(count)
        print("├─────┼────────────┼──────────────┼──────────────┼──────────────┼──────────┼──────────┼──────────┼──────────┤──────────┤")
        print(String(format: "│ AVG │ %10.2f │ %12.2f │ %12.2f │ %12.2f │ %8.3f │ %8.3f │ %8.3f │ %8.3f │ %8.3f │",
                     totalDuration / fileCount,
                     totalDiarizationTime / fileCount,
                     totalTranscriptionTime / fileCount,
                     totalProcessingTime / fileCount,
                     totalWER / fileCount,
                     totalDER / fileCount,
                     totalConfusion / totalReferenceDuration,
                     totalFalseAlarm / totalReferenceDuration,
                     totalMissed / totalReferenceDuration))
        
        // Print table footer
        print("└─────┴────────────┴──────────────┴──────────────┴──────────────┴──────────┴──────────┴──────────┴──────────┴─────────┘")
    }
}
