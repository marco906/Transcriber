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
    
    enum CodingKeys: String, CodingKey {
        case segments
        case duration
        case samplingRate = "sampling_rate"
    }
}
