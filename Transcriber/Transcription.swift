//
//  Transcribtion.swift
//  Transcriber
//
//  Created by Marco Wenzel on 29.05.25.
//

import Foundation

struct Transcription: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
	var speakerId: Int
	var start: Float
	var end: Float
	var text: String
}
