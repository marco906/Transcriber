//
//  Transcribtion.swift
//  Transcriber
//
//  Created by Marco Wenzel on 29.05.25.
//

import Foundation

struct Segment: Codable {
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

struct Transcription: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var speakerName: String
	var speakerId: Int
	var start: Float
	var end: Float
	var text: String
    var isContinuation: Bool
    
    init(speakerId: Int, start: Float, end: Float, text: String, isContinuation: Bool = false) {
        self.speakerName = speakerId.toLetter() ?? "\(speakerId)"
        self.speakerId = speakerId
        self.start = start
        self.end = end
        self.text = text
        self.isContinuation = isContinuation
    }
}

extension Int {
    func toLetter() -> String? {
        let value = self
        let scalar = UnicodeScalar("A").value + UInt32(value)
        guard value >= 0 && value < 26, let letter = UnicodeScalar(scalar) else {
            return nil
        }
        return String(letter)
    }
}

