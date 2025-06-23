//
//  DiarzationMetrics.swift
//  Transcriber
//
//  Created by Marco Wenzel on 09.06.2025.
//

import Foundation

struct DiarizationMetrics {
    struct DERComponents {
        let confusion: Float
        let falseAlarm: Float
        let missedDetection: Float
        let totalDuration: Float
        
        var der: Float {
            guard totalDuration > 0 else { return 0 }
            return (confusion + falseAlarm + missedDetection) / totalDuration
        }
    }
    
    struct WERComponents {
        let substitutions: Int
        let deletions: Int
        let insertions: Int
        let totalWords: Int
        
        var wer: Float {
            guard totalWords > 0 else { return 0 }
            return Float(substitutions + deletions + insertions) / Float(totalWords)
        }
        
        var accuracy: Float {
            return max(0, 1.0 - wer)
        }
    }
    
    static func calculateDER(reference: [Segment], hypothesis: [Segment], collar: Float = 0.0) -> DERComponents {
        // Apply collar by removing regions around segment boundaries
        let (collaredReference, collaredHypothesis) = applyCollar(
            reference: reference, 
            hypothesis: hypothesis, 
            collar: collar
        )
        
        // Find greedy mapping
        let mapping = findGreedyMapping(hypothesis: collaredHypothesis, reference: collaredReference)
        
        // Calculate total duration
        let totalDuration = collaredReference.reduce(0) { $0 + ($1.end - $1.start) }
        
        var confusion: Float = 0
        var falseAlarm: Float = 0
        var missedDetection: Float = 0
        
        // Process each reference segment
        for gt in collaredReference {
            var coveredDuration: Float = 0
            var maxOverlap: (String, Float) = ("", 0)
            
            for hyp in collaredHypothesis {
                let overlapStart = max(gt.start, hyp.start)
                let overlapEnd = min(gt.end, hyp.end)
                
                if overlapEnd > overlapStart {
                    let overlapDuration = overlapEnd - overlapStart
                    coveredDuration += overlapDuration
                    
                    if overlapDuration > maxOverlap.1 {
                        maxOverlap = (hyp.speaker, overlapDuration)
                    }
                }
            }
            
            // Calculate missed detection
            let uncoveredDuration = (gt.end - gt.start) - coveredDuration
            if uncoveredDuration > 0 {
                missedDetection += uncoveredDuration
            }
            
            // Calculate speaker confusion
            if maxOverlap.1 > 0 {
                let mappedSpeaker = mapping[maxOverlap.0] ?? maxOverlap.0
                if mappedSpeaker != gt.speaker {
                    confusion += maxOverlap.1
                }
            }
        }
        
        // Calculate false alarms
        for hyp in collaredHypothesis {
            var coveredDuration: Float = 0
            
            for gt in collaredReference {
                let overlapStart = max(gt.start, hyp.start)
                let overlapEnd = min(gt.end, hyp.end)
                
                if overlapEnd > overlapStart {
                    coveredDuration += (overlapEnd - overlapStart)
                }
            }
            
            let uncoveredDuration = (hyp.end - hyp.start) - coveredDuration
            if uncoveredDuration > 0 {
                falseAlarm += uncoveredDuration
            }
        }
        
        return DERComponents(
            confusion: confusion,
            falseAlarm: falseAlarm,
            missedDetection: missedDetection,
            totalDuration: totalDuration
        )
    }
    
    static func calculateWER(reference: String, hypothesis: String) -> WERComponents {
        let referenceFormatted = reference.lowercased()
        let hypothesisFormatted = hypothesis.lowercased()
        // Tokenize the strings into words
        let referenceWords = tokenizeWords(referenceFormatted)
        let hypothesisWords = tokenizeWords(hypothesisFormatted)
        
        return calculateWER(referenceWords: referenceWords, hypothesisWords: hypothesisWords)
    }
    
    static func calculateWER(referenceWords: [String], hypothesisWords: [String]) -> WERComponents {
        let refCount = referenceWords.count
        let hypCount = hypothesisWords.count
        
        // Handle edge cases
        if refCount == 0 && hypCount == 0 {
            return WERComponents(substitutions: 0, deletions: 0, insertions: 0, totalWords: 0)
        }
        
        if refCount == 0 {
            // Empty reference, all hypothesis words are insertions
            return WERComponents(substitutions: 0, deletions: 0, insertions: hypCount, totalWords: 0)
        }
        
        if hypCount == 0 {
            // Empty hypothesis, all reference words are deletions
            return WERComponents(substitutions: 0, deletions: refCount, insertions: 0, totalWords: refCount)
        }
        
        // Create DP table for edit distance
        // dp[i][j] represents the minimum edit distance between first i reference words and first j hypothesis words
        var dp = Array(repeating: Array(repeating: (distance: 0, ops: (sub: 0, del: 0, ins: 0)), count: hypCount + 1), count: refCount + 1)
        
        // Initialize base cases
        for i in 0...refCount {
            dp[i][0] = (distance: i, ops: (sub: 0, del: i, ins: 0))
        }
        for j in 0...hypCount {
            dp[0][j] = (distance: j, ops: (sub: 0, del: 0, ins: j))
        }
        
        // Fill the DP table
        for i in 1...refCount {
            for j in 1...hypCount {
                if referenceWords[i-1].lowercased() == hypothesisWords[j-1].lowercased() {
                    // Words match, no operation needed
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    // Consider all three operations
                    let substitution = (
                        distance: dp[i-1][j-1].distance + 1,
                        ops: (sub: dp[i-1][j-1].ops.sub + 1, del: dp[i-1][j-1].ops.del, ins: dp[i-1][j-1].ops.ins)
                    )
                    let deletion = (
                        distance: dp[i-1][j].distance + 1,
                        ops: (sub: dp[i-1][j].ops.sub, del: dp[i-1][j].ops.del + 1, ins: dp[i-1][j].ops.ins)
                    )
                    let insertion = (
                        distance: dp[i][j-1].distance + 1,
                        ops: (sub: dp[i][j-1].ops.sub, del: dp[i][j-1].ops.del, ins: dp[i][j-1].ops.ins + 1)
                    )
                    
                    // Choose the operation with minimum distance
                    if substitution.distance <= deletion.distance && substitution.distance <= insertion.distance {
                        dp[i][j] = substitution
                    } else if deletion.distance <= insertion.distance {
                        dp[i][j] = deletion
                    } else {
                        dp[i][j] = insertion
                    }
                }
            }
        }
        
        let result = dp[refCount][hypCount]
        return WERComponents(
            substitutions: result.ops.sub,
            deletions: result.ops.del,
            insertions: result.ops.ins,
            totalWords: refCount
        )
    }
    
    private static func tokenizeWords(_ text: String) -> [String] {
        // Simple word tokenization - split on whitespace and punctuation, filter empty strings
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: .punctuationCharacters) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return words
    }
    
    private static func findGreedyMapping(hypothesis: [Segment], reference: [Segment]) -> [String: String] {
        let gtSpeakers = Set(reference.map { $0.speaker })
        let hypSpeakers = Set(hypothesis.map { $0.speaker })
        
        var mapping: [String: String] = [:]
        var usedGtSpeakers = Set<String>()
        
        // For each hypothesis speaker, find the best matching ground truth speaker
        for hypSpeaker in hypSpeakers {
            var bestGtSpeaker: String? = nil
            var bestOverlap: Float = 0
            
            for gtSpeaker in gtSpeakers where !usedGtSpeakers.contains(gtSpeaker) {
                var totalOverlap: Float = 0
                
                // Calculate total overlap between this speaker pair
                for hyp in hypothesis where hyp.speaker == hypSpeaker {
                    for gt in reference where gt.speaker == gtSpeaker {
                        let overlapStart = max(hyp.start, gt.start)
                        let overlapEnd = min(hyp.end, gt.end)
                        
                        if overlapEnd > overlapStart {
                            totalOverlap += (overlapEnd - overlapStart)
                        }
                    }
                }
                
                if totalOverlap > bestOverlap {
                    bestOverlap = totalOverlap
                    bestGtSpeaker = gtSpeaker
                }
            }
            
            // If we found a match, add it to the mapping
            if let bestGtSpeaker = bestGtSpeaker {
                mapping[hypSpeaker] = bestGtSpeaker
                usedGtSpeakers.insert(bestGtSpeaker)
            }
        }
        
        return mapping
    }
    
    private static func applyCollar(reference: [Segment], hypothesis: [Segment], collar: Float) -> ([Segment], [Segment]) {
        guard collar > 0 else {
            return (reference, hypothesis)
        }
        
        // Create collar regions around reference segment boundaries
        let collarRegions = createCollarRegions(segments: reference, collar: collar)
        
        // Remove collar regions from both reference and hypothesis
        let collaredReference = removeCollarRegions(segments: reference, collarRegions: collarRegions)
        let collaredHypothesis = removeCollarRegions(segments: hypothesis, collarRegions: collarRegions)
        
        return (collaredReference, collaredHypothesis)
    }
    
    private static func createCollarRegions(segments: [Segment], collar: Float) -> [(start: Float, end: Float)] {
        var boundaries = Set<Float>()
        
        // Collect all segment boundaries
        for segment in segments {
            boundaries.insert(segment.start)
            boundaries.insert(segment.end)
        }
        
        // Create collar regions around each boundary
        var collarRegions: [(start: Float, end: Float)] = []
        let halfCollar = collar
        
        for boundary in boundaries {
            let collarStart = boundary - halfCollar
            let collarEnd = boundary + halfCollar
            collarRegions.append((start: collarStart, end: collarEnd))
        }
        
        // Merge overlapping collar regions
        return mergeOverlappingRegions(collarRegions)
    }
    
    private static func mergeOverlappingRegions(_ regions: [(start: Float, end: Float)]) -> [(start: Float, end: Float)] {
        guard !regions.isEmpty else { return [] }
        
        let sortedRegions = regions.sorted { $0.start < $1.start }
        var merged: [(start: Float, end: Float)] = []
        
        var currentStart = sortedRegions[0].start
        var currentEnd = sortedRegions[0].end
        
        for i in 1..<sortedRegions.count {
            let region = sortedRegions[i]
            
            if region.start <= currentEnd {
                // Overlapping or adjacent regions, merge them
                currentEnd = max(currentEnd, region.end)
            } else {
                // Non-overlapping region, add the current merged region
                merged.append((start: currentStart, end: currentEnd))
                currentStart = region.start
                currentEnd = region.end
            }
        }
        
        // Add the final merged region
        merged.append((start: currentStart, end: currentEnd))
        return merged
    }
    
    private static func removeCollarRegions(segments: [Segment], collarRegions: [(start: Float, end: Float)]) -> [Segment] {
        var result: [Segment] = []
        
        for segment in segments {
            var remainingParts: [(start: Float, end: Float)] = []
            remainingParts.append((start: segment.start, end: segment.end))
            
            // Remove each collar region from this segment
            for collarRegion in collarRegions {
                var newParts: [(start: Float, end: Float)] = []
                
                for part in remainingParts {
                    let intersectionStart = max(part.start, collarRegion.start)
                    let intersectionEnd = min(part.end, collarRegion.end)
                    
                    if intersectionEnd > intersectionStart {
                        // There's an intersection, split the segment
                        if part.start < intersectionStart {
                            // Keep the part before the collar
                            newParts.append((start: part.start, end: intersectionStart))
                        }
                        if intersectionEnd < part.end {
                            // Keep the part after the collar
                            newParts.append((start: intersectionEnd, end: part.end))
                        }
                    } else {
                        // No intersection, keep the whole part
                        newParts.append(part)
                    }
                }
                
                remainingParts = newParts
            }
            
            // Create segments from remaining parts (only if they have positive duration)
            for part in remainingParts {
                if part.end > part.start {
                    result.append(Segment(
                        speaker: segment.speaker,
                        start: part.start,
                        end: part.end
                    ))
                }
            }
        }
        
        return result
    }
}

struct Segment: Encodable {
    var speakerId: Int = 0
    var speaker: String
    var start: Float
    var end: Float
    
    init(speakerId: Int, start: Float, end: Float) {
        self.speakerId = speakerId
        self.speaker = speakerId.toLetter() ?? "\(speakerId)"
        self.start = start
        self.end = end
    }
    
    init(speaker: String, start: Float, end: Float) {
        self.speakerId = Int(speaker) ?? 0
        self.speaker = speaker
        self.start = start
        self.end = end
    }
}

extension Segment: Decodable {
    enum CodingKeys: String, CodingKey {
        case speaker
        case start
        case end
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.speaker = try container.decode(String.self, forKey: .speaker)
        self.start = try container.decode(Float.self, forKey: .start)
        self.end = try container.decode(Float.self, forKey: .end)
        self.speakerId = Int(speaker) ?? 0
    }
}

struct GroundTruthData: Codable {
    let segments: [Segment]
    let duration: Double
    let samplingRate: Int
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case segments
        case duration
        case samplingRate = "sampling_rate"
        case text
    }
}
