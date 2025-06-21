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
    func testDERPerfect() async throws {
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
    func testDERFailure() async throws {
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
    func testDERWithCustomSegments() {
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
    
    // MARK: - WER Tests
    
    @Test
    func testWERPerfectMatch() async throws {
        let reference = "the quick brown fox jumps over the lazy dog"
        let hypothesis = "the quick brown fox jumps over the lazy dog"
        
        let result = DiarizationMetrics.calculateWER(reference: reference, hypothesis: hypothesis)
        
        #expect(result.wer == 0.0)
        #expect(result.accuracy == 1.0)
        #expect(result.substitutions == 0)
        #expect(result.deletions == 0)
        #expect(result.insertions == 0)
        #expect(result.totalWords == 9)
    }
    
    @Test
    func testWERSubstitutions() async throws {
        let reference = "the quick brown fox jumps"
        let hypothesis = "the slow brown dog runs"
        
        let result = DiarizationMetrics.calculateWER(reference: reference, hypothesis: hypothesis)
        
        #expect(result.substitutions == 3) // quick->slow, fox->dog, jumps->runs
        #expect(result.deletions == 0)
        #expect(result.insertions == 0)
        #expect(result.totalWords == 5)
        #expect(result.wer == 0.6) // 3 errors out of 5 words
        #expect(abs(result.accuracy - 0.4) < 0.001)
    }
    
    @Test
    func testWERDeletions() async throws {
        let reference = "the quick brown fox jumps over the lazy dog"
        let hypothesis = "the brown fox jumps the dog"
        
        let result = DiarizationMetrics.calculateWER(reference: reference, hypothesis: hypothesis)
        
        #expect(result.deletions == 3) // "quick", "over", "lazy" deleted
        #expect(result.substitutions == 0)
        #expect(result.insertions == 0)
        #expect(result.totalWords == 9)
        #expect(abs(result.wer - 0.333) < 0.01) // 3 errors out of 9 words ≈ 0.333
    }
    
    @Test
    func testWERInsertions() async throws {
        let reference = "the fox jumps"
        let hypothesis = "the quick brown fox jumps over"
        
        let result = DiarizationMetrics.calculateWER(reference: reference, hypothesis: hypothesis)
        
        #expect(result.insertions == 3) // "quick", "brown", "over" inserted
        #expect(result.substitutions == 0)
        #expect(result.deletions == 0)
        #expect(result.totalWords == 3)
        #expect(result.wer == 1.0) // 3 errors out of 3 words
        #expect(result.accuracy == 0.0)
    }
    
    @Test
    func testWERMixedErrors() async throws {
        let reference = "hello world how are you"
        let hypothesis = "hi world what you doing"
        
        let result = DiarizationMetrics.calculateWER(reference: reference, hypothesis: hypothesis)
        
        // Expected operations: hello->hi (sub), how->what (sub), are->deleted, you->you (match), ->doing (ins)
        // The current DP algorithm might produce a different combination of ops with the same total error count.
        // For example, 4 substitutions and 0 deletions/insertions.
        // We will assert the total error count and WER.
        let totalErrors = result.substitutions + result.deletions + result.insertions
        #expect(totalErrors == 4)
        #expect(result.totalWords == 5)
        #expect(result.wer == 0.8) // 4 errors out of 5 words
    }
    
    @Test
    func testWERCaseInsensitive() async throws {
        let reference = "Hello World"
        let hypothesis = "hello world"
        
        let result = DiarizationMetrics.calculateWER(reference: reference, hypothesis: hypothesis)
        
        #expect(result.wer == 0.0) // Should be case insensitive
        #expect(result.substitutions == 0)
        #expect(result.deletions == 0)
        #expect(result.insertions == 0)
    }
    
    @Test
    func testWERWithPunctuation() async throws {
        let reference = "Hello, world! How are you?"
        let hypothesis = "Hello world How are you"
        
        let result = DiarizationMetrics.calculateWER(reference: reference, hypothesis: hypothesis)
        
        // Punctuation should be filtered out, so these should match perfectly
        #expect(result.wer == 0.0)
        #expect(result.totalWords == 5) // "Hello", "world", "How", "are", "you"
    }
    
    @Test
    func testWEREmptyHypothesis() async throws {
        let reference = "hello world"
        let hypothesis = ""
        
        let result = DiarizationMetrics.calculateWER(reference: reference, hypothesis: hypothesis)
        
        #expect(result.deletions == 2) // Both words deleted
        #expect(result.substitutions == 0)
        #expect(result.insertions == 0)
        #expect(result.totalWords == 2)
        #expect(result.wer == 1.0) // 100% error rate
    }
    
    @Test
    func testWEREmptyReference() async throws {
        let reference = ""
        let hypothesis = "hello world"
        
        let result = DiarizationMetrics.calculateWER(reference: reference, hypothesis: hypothesis)
        
        #expect(result.insertions == 2) // Both words inserted
        #expect(result.substitutions == 0)
        #expect(result.deletions == 0)
        #expect(result.totalWords == 0)
        #expect(result.wer == 0.0) // WER is 0 when reference is empty (by convention)
    }
    
    @Test
    func testWERWithWordArrays() async throws {
        let referenceWords = ["the", "quick", "brown", "fox"]
        let hypothesisWords = ["the", "fast", "brown", "dog"]
        
        let result = DiarizationMetrics.calculateWER(referenceWords: referenceWords, hypothesisWords: hypothesisWords)
        
        #expect(result.substitutions == 2) // quick->fast, fox->dog
        #expect(result.deletions == 0)
        #expect(result.insertions == 0)
        #expect(result.totalWords == 4)
        #expect(result.wer == 0.5) // 2 errors out of 4 words
    }
}
