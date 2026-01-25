//
//  VideoView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI

struct VideoView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Stick figures
            StickFiguresView()
                .frame(height: 200)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        VideoView()
    }
}
