//
//  TranscriberTests.swift
//  TranscriberTests
//
//  Created by Marco Wenzel on 09.06.2025.
//

import Testing
import Foundation
@testable import Transcriber

@Suite("TranscriberTests")
class TranscriberTests {
    
    @Test
    func testMetricsPerfect() async throws {
        let reference = [
            Segment(speaker: "A", start: 0.0, end: 2.3),
            Segment(speaker: "B", start: 2.3, end: 5.0),
            Segment(speaker: "A", start: 5.0, end: 7.5)
        ]
        
        let hypothesis = [
            Segment(speaker: "A", start: 0.0, end: 2.3),
            Segment(speaker: "B", start: 2.3, end: 5.0),
            Segment(speaker: "A", start: 5.0, end: 7.5)
        ]
        
        let result = DiarizationMetrics.calculateDER(reference: reference, hypothesis: hypothesis, collar: 0.25)
        #expect(result.der == 0)
    }
    
    @Test
    func testMetricsFailure() async throws {
        let reference = [
            Segment(speaker: "A", start: 0.0, end: 2.3),
            Segment(speaker: "B", start: 2.3, end: 5.0),
            Segment(speaker: "A", start: 5.0, end: 7.5)
        ]
        
        let hypothesis = [Segment]()
        
        let result = DiarizationMetrics.calculateDER(reference: reference, hypothesis: hypothesis, collar: 0.25)
        #expect(result.der == 1.0)
    }
    
    @Test
    func testDiarizationWithCustomSegments() {
        // Create reference segments
        let reference = [
            Segment(speaker: "C", start: 0, end: 5),
            Segment(speaker: "D", start: 5, end: 9),
            Segment(speaker: "A", start: 10, end: 14),
            Segment(speaker: "D", start: 14, end: 15),
            Segment(speaker: "C", start: 17, end: 20),
            Segment(speaker: "B", start: 22, end: 25)
        ]
        
        // Create hypothesis segments
        let hypothesis = [
            Segment(speaker: "C", start: 0, end: 8),
            Segment(speaker: "A", start: 11, end: 15),
            Segment(speaker: "C", start: 17, end: 21),
            Segment(speaker: "B", start: 23, end: 25)
        ]
        
        let result = DiarizationMetrics.calculateDER(reference: reference, hypothesis: hypothesis, collar: 0.0)
        #expect(result.der == 0.4)
    }
    
    @Test
    func testDiarizationForAcademicData() async throws {
        try await testDiarizationFor(dataSet: "academic")
    }
    
    @Test
    func testDiarizationForPhoneCallData() async throws {
        try await testDiarizationFor(dataSet: "phonecall")
    }
    
    func testDiarizationFor(dataSet: String, count: Int = 5) async throws {
        let bundle = Bundle.init(for: TranscriberTests.self)
        let audioService = AudioFileService.shared
        let diarizationService = DiarizationService.shared
        diarizationService.config.numThreads = 8
        diarizationService.config.minDurationOn = 0.10
        diarizationService.config.minDurationOff = 0.55
        diarizationService.config.numSpeakers = 2
        diarizationService.config.threshold = 0.7
        
        // Print table header
        print("\nDiarization Test Results for \(dataSet):")
        print("┌─────┬────────────┬──────────────┬──────────┬──────────┬──────────┬──────────┐")
        print("│ ID  │ Duration   │ Diarization  │   DER    │ Confusion│ FAlarm   │ Missed   │")
        print("├─────┼────────────┼──────────────┼──────────┼──────────┼──────────┼──────────┤")
        
        // Test files 1-5
        for fileId in 1...5 {
            let basePath = "en_\(dataSet)_\(fileId)"
            // Load ground truth data
            let groundTruthURL = bundle.url(forResource: basePath + "_segments", withExtension: "json")!
            let groundTruthData = try Data(contentsOf: groundTruthURL)
            let groundTruth = try JSONDecoder().decode(GroundTruthData.self, from: groundTruthData)
            let reference = groundTruth.segments
            
            // Load audio file
            let audioURL = bundle.url(forResource: basePath + "_audio", withExtension: "wav")!
            let samples = try audioService.createAudioBufferArray(from: audioURL)
            
            // Run diarization and measure time
            let startTime = Date()
            let predictions = diarizationService.rundDiarization(samples: samples)
            let diarizationTime = Date().timeIntervalSince(startTime)
            
            // Convert predictions to Segment format
            let hypothesis = predictions.map { segment in
                Segment(speakerId: segment.speaker, start: segment.start, end: segment.end)
            }
            
            // Calculate metrics
            let result = DiarizationMetrics.calculateDER(reference: reference, hypothesis: hypothesis, collar: 0.25)
            
            // Print results row
            print(String(format: "│ %2d  │ %10.2f │ %12.2f │ %8.3f │ %8.3f │ %8.3f │ %8.3f │",
                        fileId,
                        groundTruth.duration,
                        diarizationTime,
                        result.der,
                        result.confusion / result.totalDuration,
                        result.falseAlarm / result.totalDuration,
                        result.missedDetection / result.totalDuration))
        }
        
        // Print table footer
        print("└─────┴────────────┴──────────────┴──────────┴──────────┴──────────┴──────────┘")
    }
}
