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
        transcription.speakerId == 0 ? .teal.opacity(0.3) : .init(uiColor: .secondarySystemGroupedBackground)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: trailingAlignment ? .trailing : .leading) {
                if (!transcription.isContinuation) {
                    Text("Speaker \(transcription.speakerName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transcription.text)
                    Text(String(format: "% 2.0fs", transcription.start))
                        .font(.caption)
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
        .padding(.top, transcription.isContinuation ? 4 : 20)
    }
}
