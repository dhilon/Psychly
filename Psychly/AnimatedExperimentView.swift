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
    @State private var animationPhase: CGFloat = 0

    // Timer for frame advancement (2 seconds per frame)
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Current frame with animations
            Image(uiImage: frames[currentFrameIndex])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .id(currentFrameIndex) // Forces view recreation for transition
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.05)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .animation(.easeInOut(duration: 0.5), value: currentFrameIndex)

            // Subtle movement overlay (characters "breathing"/moving)
            Image(uiImage: frames[currentFrameIndex])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(0.1)
                .scaleEffect(1.0 + sin(animationPhase) * 0.02)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animationPhase)
        }
        .onAppear {
            animationPhase = 1.0 // Trigger continuous subtle animation
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentFrameIndex = (currentFrameIndex + 1) % frames.count
            }
        }
    }
}

#Preview {
    AnimatedExperimentView(frames: [UIImage(systemName: "photo")!])
}
