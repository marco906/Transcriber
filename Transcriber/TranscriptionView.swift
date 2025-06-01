//
//  TranscriptionView.swift
//  Transcriber
//
//  Created by Marco Wenzel on 29.05.25.
//

import SwiftUI

struct TranscriptionView: View {
	let transcription: Transcription
	
	init(_ transcription: Transcription) {
		self.transcription = transcription
	}
	
    var body: some View {
		Text(transcription.text)
    }
}

#Preview {
	NavigationStack {
		VStack {
			TranscriptionView(.preview1)
		}
	}
}
