//
//  Transcribtion.swift
//  Transcriber
//
//  Created by Marco Wenzel on 29.05.25.
//

struct Transcription: Identifiable, Equatable, Hashable {
	var id: Int
	var start: Float
	var end: Float
	var text: String
}

extension Transcription {
	static var preview1 = Transcription(id: 0, start: 0, end: 5, text: "Hello there I am speaker one! Some very long text that spans over multiple lines")
	static var preview2 = Transcription(id: 1, start: 5, end: 10, text: "Hi, I am the secon speaker! Some very long text that spans over multiple lines")
}
