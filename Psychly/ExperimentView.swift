//
//  ExperimentView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI

struct ExperimentView: View {
    let date: Date
    @State private var selectedFeedback: Feedback? = nil

    enum Feedback {
        case like, dislike
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Experiment for \(formattedDate)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .padding(.top, 24)

            // Experiment info box
            VStack(alignment: .leading, spacing: 12) {
                Text("Experiment Name")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)

                Text("Info")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)

                // Two stick figures looking at each other
                StickFiguresView()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            // Like and Dislike buttons
            HStack(spacing: 40) {
                Button {
                    selectedFeedback = selectedFeedback == .dislike ? nil : .dislike
                } label: {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(selectedFeedback == .dislike ? .gray : .red.opacity(0.8))
                        .frame(width: 70, height: 70)
                        .background(selectedFeedback == .dislike ? Color.purple : Color(.systemGray6))
                        .cornerRadius(35)
                }

                Button {
                    selectedFeedback = selectedFeedback == .like ? nil : .like
                } label: {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(selectedFeedback == .like ? .gray : .green.opacity(0.8))
                        .frame(width: 70, height: 70)
                        .background(selectedFeedback == .like ? Color.purple : Color(.systemGray6))
                        .cornerRadius(35)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .navigationTitle("Experiment")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StickFiguresView: View {
    var body: some View {
        Canvas { context, size in
            let figureHeight: CGFloat = 100
            let figureWidth: CGFloat = 50
            let spacing: CGFloat = 60
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Left figure (facing right)
            drawStickFigure(
                context: context,
                centerX: centerX - spacing,
                centerY: centerY,
                figureHeight: figureHeight,
                figureWidth: figureWidth,
                facingRight: true
            )

            // Right figure (facing left)
            drawStickFigure(
                context: context,
                centerX: centerX + spacing,
                centerY: centerY,
                figureHeight: figureHeight,
                figureWidth: figureWidth,
                facingRight: false
            )
        }
    }

    private func drawStickFigure(context: GraphicsContext, centerX: CGFloat, centerY: CGFloat, figureHeight: CGFloat, figureWidth: CGFloat, facingRight: Bool) {
        let headRadius: CGFloat = 12
        let bodyLength: CGFloat = 35
        let legLength: CGFloat = 30
        let armLength: CGFloat = 25

        let headCenterY = centerY - figureHeight / 2 + headRadius
        let neckY = headCenterY + headRadius
        let bodyEndY = neckY + bodyLength
        let eyeOffsetX: CGFloat = facingRight ? 4 : -4

        let strokeColor = Color.gray
        var strokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)

        // Head
        let headPath = Path(ellipseIn: CGRect(
            x: centerX - headRadius,
            y: headCenterY - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))
        context.stroke(headPath, with: .color(strokeColor), lineWidth: 3)

        // Eye (small dot)
        let eyePath = Path(ellipseIn: CGRect(
            x: centerX + eyeOffsetX - 2,
            y: headCenterY - 2,
            width: 4,
            height: 4
        ))
        context.fill(eyePath, with: .color(strokeColor))

        // Body
        var bodyPath = Path()
        bodyPath.move(to: CGPoint(x: centerX, y: neckY))
        bodyPath.addLine(to: CGPoint(x: centerX, y: bodyEndY))
        context.stroke(bodyPath, with: .color(strokeColor), lineWidth: 3)

        // Arms
        var armsPath = Path()
        let armY = neckY + 10
        armsPath.move(to: CGPoint(x: centerX - armLength, y: armY + 15))
        armsPath.addLine(to: CGPoint(x: centerX, y: armY))
        armsPath.addLine(to: CGPoint(x: centerX + armLength, y: armY + 15))
        context.stroke(armsPath, with: .color(strokeColor), lineWidth: 3)

        // Legs
        var legsPath = Path()
        legsPath.move(to: CGPoint(x: centerX - 15, y: bodyEndY + legLength))
        legsPath.addLine(to: CGPoint(x: centerX, y: bodyEndY))
        legsPath.addLine(to: CGPoint(x: centerX + 15, y: bodyEndY + legLength))
        context.stroke(legsPath, with: .color(strokeColor), lineWidth: 3)
    }
}

#Preview {
    NavigationStack {
        ExperimentView(date: Date())
    }
}
