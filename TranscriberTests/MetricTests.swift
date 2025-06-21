//
//  MetricTests.swift
//  Transcriber
//
//  Created by Marco Wenzel on 21.06.2025.
//

import Testing
import Foundation
@testable import Transcriber

@Suite("MetricTests")
class MetricTests {
    
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
}
