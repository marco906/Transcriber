//
//  TranscriberTests.swift
//  TranscriberTests
//
//  Created by Marco Wenzel on 09.06.2025.
//

import Testing
import Foundation

@testable import Transcriber

struct TranscriberTests {
    
    @Test func testMetricsPerfect() async throws {
        let groundTruthSegments = [
            Segment(speaker: "A", start: 0.0, end: 2.3),
            Segment(speaker: "B", start: 2.3, end: 5.0),
            Segment(speaker: "A", start: 5.0, end: 7.5)
        ]
        
        let predictions = [
            Segment(speaker: "A", start: 0.0, end: 2.3),
            Segment(speaker: "B", start: 2.3, end: 5.0),
            Segment(speaker: "A", start: 5.0, end: 7.5)
        ]
        
        // Calculate metrics
        let metrics = DiarizationMetrics.evaluateDiarization(
            groundTruth: groundTruthSegments,
            predictions: predictions,
            collar: 0.25
        )
        
        #expect(metrics["der"]! == 0)
        #expect(metrics["jer"]! == 0)
    }
    
    @Test func testMetricsFailure() async throws {
        let groundTruthSegments = [
            Segment(speaker: "A", start: 0.0, end: 2.3),
            Segment(speaker: "B", start: 2.3, end: 5.0),
            Segment(speaker: "A", start: 5.0, end: 7.5)
        ]
        
        let predictions = [Segment]()
        
        // Calculate metrics
        let metrics = DiarizationMetrics.evaluateDiarization(
            groundTruth: groundTruthSegments,
            predictions: predictions,
            collar: 0.25
        )
        
        #expect(metrics["der"]! == 1.0)
        #expect(metrics["jer"]! == 1.0)
    }
}
