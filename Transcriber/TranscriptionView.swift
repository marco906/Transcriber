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
    
    var trailingAlignment: Bool {
        transcription.speakerId == 0 ? true : false
    }
    
    var color: Color {
        transcription.speakerId == 0 ? .teal.opacity(0.3) : .gray.opacity(0.30)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: trailingAlignment ? .trailing : .leading) {
                Text("Speaker \(transcription.speakerId)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                VStack(alignment: .trailing, spacing: 8) {
                    Text(transcription.text)
                    Text(String(format: "% 2.0fs", transcription.start))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(color)
                )
            }
            .frame(maxWidth: .infinity, alignment: trailingAlignment ? .trailing : .leading)
        }
        .padding(.bottom)
    }
}
