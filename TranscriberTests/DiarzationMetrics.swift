//
//  DiarzationMetrics.swift
//  Transcriber
//
//  Created by Marco Wenzel on 09.06.2025.
//

import Foundation

struct DiarizationMetrics {
    static func calculateDER(groundTruth: [Segment], predictions: [Segment], collar: Float = 0.0) -> Float {
        let totalDuration = max(
            groundTruth.map { $0.end }.max() ?? 0,
            predictions.map { $0.end }.max() ?? 0
        )
        
        var speakerError: Float = 0
        var falseAlarm: Float = 0
        var missedDetection: Float = 0
        
        // Process each ground truth segment
        for gt in groundTruth {
            var overlaps: [(String, Float)] = []
            
            for pred in predictions {
                let gtStart = gt.start + collar
                let gtEnd = gt.end - collar
                let predStart = pred.start + collar
                let predEnd = pred.end - collar
                
                let overlapStart = max(gtStart, predStart)
                let overlapEnd = min(gtEnd, predEnd)
                
                if overlapEnd > overlapStart {
                    overlaps.append((pred.speaker, overlapEnd - overlapStart))
                }
            }
            
            if overlaps.isEmpty {
                missedDetection += (gt.end - gt.start)
            } else {
                let maxOverlap = overlaps.max(by: { $0.1 < $1.1 })!
                if maxOverlap.0 != gt.speaker {
                    speakerError += maxOverlap.1
                }
            }
        }
        
        // Calculate false alarms
        for pred in predictions {
            let predStart = pred.start + collar
            let predEnd = pred.end - collar
            
            var hasOverlap = false
            for gt in groundTruth {
                let gtStart = gt.start + collar
                let gtEnd = gt.end - collar
                
                if max(gtStart, predStart) < min(gtEnd, predEnd) {
                    hasOverlap = true
                    break
                }
            }
            
            if !hasOverlap {
                falseAlarm += (pred.end - pred.start)
            }
        }
        
        return (speakerError + falseAlarm + missedDetection) / totalDuration
    }
    
    static func calculateJER(groundTruth: [Segment], predictions: [Segment]) -> Float {
        var intersection: Float = 0
        var union: Float = 0
        
        // Calculate intersection
        for gt in groundTruth {
            for pred in predictions {
                let overlapStart = max(gt.start, pred.start)
                let overlapEnd = min(gt.end, pred.end)
                
                if overlapEnd > overlapStart {
                    intersection += (overlapEnd - overlapStart)
                }
            }
        }
        
        // Calculate union
        let gtDuration = groundTruth.reduce(0) { $0 + ($1.end - $1.start) }
        let predDuration = predictions.reduce(0) { $0 + ($1.end - $1.start) }
        union = gtDuration + predDuration - intersection
        
        return union > 0 ? 1 - (intersection / union) : 1.0
    }
    
    static func evaluateDiarization(groundTruth: [Segment], predictions: [Segment], collar: Float = 0.0) -> [String: Float] {
        let der = calculateDER(groundTruth: groundTruth, predictions: predictions, collar: collar)
        let jer = calculateJER(groundTruth: groundTruth, predictions: predictions)
        
        return [
            "der": der,
            "jer": jer
        ]
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
