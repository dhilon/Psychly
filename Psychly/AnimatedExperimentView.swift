//
//  AnimatedExperimentView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/26/26.
//

import SwiftUI
import UIKit

struct AnimatedExperimentView: View {
    let frames: [UIImage]
    @State private var currentFrameIndex = 0

    // Timer for flipbook frame advancement (0.5 seconds per frame = 25 second loop for 50 frames)
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        // Simple frame display for smooth flipbook effect
        Image(uiImage: frames[currentFrameIndex])
            .resizable()
            .aspectRatio(contentMode: .fit)
            .onReceive(timer) { _ in
                // Direct frame swap without animation for flipbook effect
                currentFrameIndex = (currentFrameIndex + 1) % frames.count
            }
    }
}

#Preview {
    AnimatedExperimentView(frames: [UIImage(systemName: "photo")!])
}
