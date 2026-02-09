//
//  GeminiService.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import Foundation
import UIKit

class GeminiService {
    static let shared = GeminiService()

    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    private init() {
        // Load API key from Secrets.plist
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["GEMINI_API_KEY"] as? String {
            self.apiKey = key
        } else {
            print("🔴 Warning: Could not load GEMINI_API_KEY from Secrets.plist")
            self.apiKey = ""
        }
    }

    func getRandomExperiment(excludingNames: [String]) async throws -> Experiment {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let excludeList = excludingNames.isEmpty ? "none" : excludingNames.joined(separator: ", ")

        let prompt = """
        Generate a random famous psychology experiment or study. Do NOT use any of these experiments: \(excludeList).

        Respond ONLY with valid JSON in this exact format (no markdown, no code blocks, just raw JSON):
        {
            "name": "Name of the experiment",
            "info": "A brief 2-3 sentence description of what the experiment was about and what happened, without mentioning the experiment name",
            "date": "Year or date range when it was conducted",
            "researchers": "Names of the primary researchers",
            "hypothesis": "The main hypothesis that the researchers were testing",
            "rejected": true or false (whether the null hypothesis was rejected, meaning the experiment found significant results)
        }
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        // Log raw response
        if let httpResponse = response as? HTTPURLResponse {
            print("🔵 Gemini API Status Code: \(httpResponse.statusCode)")
        }

        if let rawString = String(data: data, encoding: .utf8) {
            print("🔵 Gemini Raw Response: \(rawString)")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = geminiResponse.candidates?.first?.content?.parts?.first?.text {
            print("🔵 Gemini Text Content: \(text)")

            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            print("🔵 Cleaned JSON: \(cleaned)")

            if let jsonData = cleaned.data(using: .utf8) {
                do {
                    let experiment = try JSONDecoder().decode(Experiment.self, from: jsonData)
                    print("🟢 Successfully parsed experiment: \(experiment.name)")
                    return experiment
                } catch {
                    print("🔴 JSON Decode Error: \(error)")
                    throw error
                }
            }
        } else {
            print("🔴 No text content in Gemini response")
        }

        // Fallback to local experiments if API fails
        print("🟡 Using fallback experiment")
        return getRandomFallbackExperiment(excludingNames: excludingNames)
    }

    struct GuessResult {
        let isCorrect: Bool
        let reasoning: String?
    }

    func checkGuess(userGuess: String, actualName: String) async throws -> GuessResult {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        I'm playing a psychology experiment guessing game. The actual experiment name is "\(actualName)".
        The user guessed: "\(userGuess)"

        STRICT RULES - The guess must demonstrate specific knowledge of THIS experiment:

        REJECT the guess if:
        - It's too generic (e.g., "experiment", "psychology study", "the study")
        - It only mentions a broad concept without the specific experiment name (e.g., "obedience" alone is not enough for "Milgram Obedience Study")
        - It names a completely different experiment
        - It's just random words or gibberish

        ACCEPT the guess if:
        - It contains the distinctive identifier (e.g., "Milgram", "Stanford Prison", "Bobo Doll", "Marshmallow")
        - It's an abbreviated but specific version (e.g., "stanford prison" for "Stanford Prison Experiment")
        - It's a well-known alternate name for the same experiment
        - It has minor typos but the specific experiment is clearly identifiable
        - It uses slightly different wording but refers to the same specific experiment

        The key test: Would a psychology professor agree the student knows which specific experiment this is?

        Respond ONLY with valid JSON in this exact format (no markdown, no code blocks):
        {"correct": true} or {"correct": false, "reasoning": "brief explanation of why it's wrong"}
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = response.candidates?.first?.content?.parts?.first?.text {
            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let jsonData = cleaned.data(using: .utf8) {
                let result = try JSONDecoder().decode(GuessCheckResult.self, from: jsonData)
                return GuessResult(isCorrect: result.correct, reasoning: result.reasoning)
            }
        }

        return GuessResult(isCorrect: false, reasoning: nil)
    }

    func generateHypothesisForExperiment(name: String, info: String) async throws -> (hypothesis: String, rejected: Bool) {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        For the psychology experiment called "\(name)" with this description: "\(info)"

        Respond ONLY with valid JSON in this exact format (no markdown, no code blocks, just raw JSON):
        {
            "hypothesis": "The main hypothesis that the researchers were testing",
            "rejected": true or false (whether the null hypothesis was rejected, meaning the experiment found significant results)
        }
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = response.candidates?.first?.content?.parts?.first?.text {
            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let jsonData = cleaned.data(using: .utf8) {
                let result = try JSONDecoder().decode(HypothesisResult.self, from: jsonData)
                return (result.hypothesis, result.rejected)
            }
        }

        // Fallback
        return ("The researchers hypothesized that their experimental manipulation would produce significant behavioral changes.", false)
    }

    func categorizeExperiment(name: String, info: String) async throws -> String {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Categorize this psychology experiment into ONE of these categories:
        - social (social psychology, group dynamics)
        - cognitive (thinking, decision making)
        - developmental (child development, aging)
        - behavioral (conditioning, behavior modification)
        - emotional (emotions, affect)
        - memory (memory, recall)
        - perception (sensory, attention)
        - learning (education, skill acquisition)
        - obedience (authority, compliance)
        - conformity (social pressure, norms)
        - attachment (bonding, relationships)
        - aggression (violence, hostility)
        - motivation (goals, drives)
        - stress (anxiety, coping)

        Experiment: "\(name)"
        Description: "\(info)"

        Respond with ONLY the category name, nothing else.
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = response.candidates?.first?.content?.parts?.first?.text {
            let category = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            print("🔵 Categorized experiment '\(name)' as: \(category)")
            return category
        }

        return "default"
    }

    // MARK: - Animation Generation

    /// Generate a storyboard of 50 frame descriptions for a flipbook-style animation
    func generate50FrameStoryboard(experiment: Experiment) async throws -> [String] {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Given this psychology experiment:
        Name: \(experiment.name)
        Description: \(experiment.info)
        Researchers: \(experiment.researchers)
        Year: \(experiment.date)

        Create a 50-frame storyboard for a 25-second flipbook animation (0.5 seconds per frame) showing this experiment.

        Structure the animation in 3 acts:
        - Act 1 (Frames 1-15): SETUP - Show the lab/room environment, researcher enters, participant arrives and is greeted
        - Act 2 (Frames 16-35): EXPERIMENT - Show the actual procedure, key moments, participant reactions, researcher observations
        - Act 3 (Frames 36-50): CONCLUSION - Show results revealed, debriefing conversation, participants departing

        Each frame description must include:
        - Character positions (left/center/right, distance from edge as percentage)
        - Character poses (standing, sitting, pointing, arms up, leaning, etc.)
        - Small motion changes from previous frame (for flipbook effect)
        - Props visible in scene (clipboard, table, chair, equipment specific to the experiment)
        - Brief action description

        Keep descriptions concise but specific for programmatic rendering.

        Respond ONLY with a valid JSON array of exactly 50 frame descriptions (no markdown, no code blocks):
        ["Frame 1: ...", "Frame 2: ...", ..., "Frame 50: ..."]
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = response.candidates?.first?.content?.parts?.first?.text {
            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let jsonData = cleaned.data(using: .utf8) {
                let scenes = try JSONDecoder().decode([String].self, from: jsonData)
                print("🟢 Generated \(scenes.count) frame descriptions")
                return scenes
            }
        }

        // Fallback: generate 50 generic frames
        return generate50FrameFallbackStoryboard(experiment: experiment)
    }

    /// Legacy method - now calls generate50FrameStoryboard
    func generateExperimentStoryboard(experiment: Experiment) async throws -> [String] {
        return try await generate50FrameStoryboard(experiment: experiment)
    }

    /// Generate an image for a scene description with detailed styling
    func generateSceneImage(description: String, experimentName: String, frameIndex: Int = 0) async throws -> UIImage {
        print("🔵 Generating frame \(frameIndex + 1) for: \(description.prefix(40))...")
        return generateFlipbookFrame(description: description, frameIndex: frameIndex)
    }

    /// Generate a flipbook frame with consistent styling
    /// - Blue oval body (#3B82F6) for researcher
    /// - Green oval body (#22C55E) for participant
    /// - Light gray background (#F0F0F0)
    /// - 512x512 canvas, 4px line thickness
    /// - Characters ~150 pixels tall
    private func generateFlipbookFrame(description: String, frameIndex: Int) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)

        // Consistent colors per spec
        let backgroundColor = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0) // #F0F0F0
        let researcherColor = UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0) // #3B82F6
        let participantColor = UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1.0) // #22C55E

        // Parse description for positioning and actions
        let desc = description.lowercased()
        let isGroupScene = desc.contains("group") || desc.contains("participants") || desc.contains("multiple")
        let hasInteraction = desc.contains("interact") || desc.contains("talk") || desc.contains("speak") || desc.contains("explain")
        let isObserving = desc.contains("observ") || desc.contains("watch") || desc.contains("note")
        let isSitting = desc.contains("sit") || desc.contains("seated") || desc.contains("chair")
        let isPointing = desc.contains("point") || desc.contains("gesture") || desc.contains("show")
        let hasTable = desc.contains("table") || desc.contains("desk")
        let hasChair = desc.contains("chair") || desc.contains("seated")
        let isEntering = desc.contains("enter") || desc.contains("arrive") || desc.contains("walk")
        let isLeaving = desc.contains("leave") || desc.contains("depart") || desc.contains("exit")

        // Calculate positions based on frame index for subtle animation
        let frameOffset = CGFloat(frameIndex % 5) * 2 // Small oscillation for flipbook effect
        let breathingOffset = sin(CGFloat(frameIndex) * 0.3) * 3 // Subtle breathing motion

        // Base positions
        var researcherX = size.width * 0.25
        var participantX = size.width * 0.7

        // Adjust positions based on scene
        if isEntering {
            participantX = size.width * (0.85 - CGFloat(frameIndex % 15) * 0.01)
        } else if isLeaving {
            participantX = size.width * (0.7 + CGFloat(frameIndex % 15) * 0.01)
        }

        if hasInteraction {
            researcherX = size.width * 0.35
            participantX = size.width * 0.65
        }

        let image = renderer.image { context in
            let ctx = context.cgContext

            // Light gray background
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw floor line
            UIColor.systemGray4.setStroke()
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: 0, y: size.height * 0.78))
            ctx.addLine(to: CGPoint(x: size.width, y: size.height * 0.78))
            ctx.strokePath()

            // Draw props first (behind characters)
            if hasTable {
                drawTable(context: ctx, x: size.width * 0.5, y: size.height * 0.65, width: 120, height: 35)
            }

            if hasChair {
                drawChair(context: ctx, x: participantX - 15, y: size.height * 0.6)
            }

            // Determine arm positions
            let researcherArm: ArmPosition = isObserving ? .crossed : (isPointing ? .pointing : .down)
            let participantArm: ArmPosition = hasInteraction ? .up : (isSitting ? .onLap : .down)

            // Draw researcher (left side, blue)
            drawStickFigure(
                context: ctx,
                centerX: researcherX + frameOffset,
                baseY: size.height * 0.78,
                color: researcherColor,
                hasClipboard: true,
                armPosition: researcherArm,
                isSitting: false,
                breathingOffset: breathingOffset
            )

            // Draw participant(s) (right side, green)
            if isGroupScene {
                // Multiple participants
                drawStickFigure(
                    context: ctx,
                    centerX: participantX - 40 + frameOffset,
                    baseY: size.height * 0.78,
                    color: participantColor,
                    hasClipboard: false,
                    armPosition: participantArm,
                    isSitting: isSitting,
                    breathingOffset: breathingOffset
                )
                drawStickFigure(
                    context: ctx,
                    centerX: participantX + 40 - frameOffset,
                    baseY: size.height * 0.78,
                    color: participantColor.withAlphaComponent(0.85),
                    hasClipboard: false,
                    armPosition: .down,
                    isSitting: isSitting,
                    breathingOffset: -breathingOffset
                )
            } else {
                // Single participant
                drawStickFigure(
                    context: ctx,
                    centerX: participantX + frameOffset,
                    baseY: size.height * 0.78,
                    color: participantColor,
                    hasClipboard: false,
                    armPosition: participantArm,
                    isSitting: isSitting,
                    breathingOffset: breathingOffset
                )
            }
        }

        return image
    }

    private enum ArmPosition {
        case up, down, crossed, pointing, onLap
    }

    /// Draw a stick figure with oval body, ~150 pixels tall, 4px line thickness
    private func drawStickFigure(context: CGContext, centerX: CGFloat, baseY: CGFloat, color: UIColor, hasClipboard: Bool, armPosition: ArmPosition, isSitting: Bool, breathingOffset: CGFloat) {
        // Character height ~150 pixels
        let headRadius: CGFloat = 18
        let bodyHeight: CGFloat = 50
        let bodyWidth: CGFloat = 30
        let limbLength: CGFloat = 45
        let lineWidth: CGFloat = 4

        // Adjust base Y for sitting
        let adjustedBaseY = isSitting ? baseY - 20 : baseY

        // Calculate positions
        let headCenterY = adjustedBaseY - limbLength - bodyHeight - headRadius + breathingOffset
        let bodyTopY = headCenterY + headRadius
        let bodyBottomY = bodyTopY + bodyHeight

        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Head (filled circle)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(
            x: centerX - headRadius,
            y: headCenterY - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))

        // Body (oval)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(
            x: centerX - bodyWidth / 2,
            y: bodyTopY,
            width: bodyWidth,
            height: bodyHeight
        ))

        // Arms
        context.setStrokeColor(color.cgColor)
        let armY = bodyTopY + 15

        switch armPosition {
        case .up:
            context.move(to: CGPoint(x: centerX - bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX - limbLength * 0.8, y: armY - 25))
            context.move(to: CGPoint(x: centerX + bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX + limbLength * 0.8, y: armY - 25))
        case .crossed:
            context.move(to: CGPoint(x: centerX - bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX + 10, y: armY + 20))
            context.move(to: CGPoint(x: centerX + bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX - 10, y: armY + 20))
        case .pointing:
            context.move(to: CGPoint(x: centerX - bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX - limbLength * 0.6, y: armY + 15))
            context.move(to: CGPoint(x: centerX + bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX + limbLength, y: armY - 10))
        case .onLap:
            context.move(to: CGPoint(x: centerX - bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX - 15, y: bodyBottomY + 5))
            context.move(to: CGPoint(x: centerX + bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX + 15, y: bodyBottomY + 5))
        case .down:
            context.move(to: CGPoint(x: centerX - bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX - limbLength * 0.5, y: armY + 35))
            context.move(to: CGPoint(x: centerX + bodyWidth/2, y: armY))
            context.addLine(to: CGPoint(x: centerX + limbLength * 0.5, y: armY + 35))
        }
        context.strokePath()

        // Legs
        if isSitting {
            // Sitting legs (bent)
            context.move(to: CGPoint(x: centerX - 10, y: bodyBottomY))
            context.addLine(to: CGPoint(x: centerX - 25, y: bodyBottomY + 20))
            context.addLine(to: CGPoint(x: centerX - 25, y: baseY))
            context.move(to: CGPoint(x: centerX + 10, y: bodyBottomY))
            context.addLine(to: CGPoint(x: centerX + 25, y: bodyBottomY + 20))
            context.addLine(to: CGPoint(x: centerX + 25, y: baseY))
        } else {
            // Standing legs
            context.move(to: CGPoint(x: centerX - 10, y: bodyBottomY))
            context.addLine(to: CGPoint(x: centerX - limbLength * 0.5, y: baseY))
            context.move(to: CGPoint(x: centerX + 10, y: bodyBottomY))
            context.addLine(to: CGPoint(x: centerX + limbLength * 0.5, y: baseY))
        }
        context.strokePath()

        // Clipboard for researcher
        if hasClipboard {
            let clipboardX = centerX + limbLength * 0.5 - 5
            let clipboardY = armY + 30
            context.setFillColor(UIColor.systemYellow.cgColor)
            context.fill(CGRect(x: clipboardX, y: clipboardY, width: 18, height: 24))
            context.setStrokeColor(UIColor.systemOrange.cgColor)
            context.setLineWidth(2)
            context.stroke(CGRect(x: clipboardX, y: clipboardY, width: 18, height: 24))
            // Lines on clipboard
            context.setStrokeColor(UIColor.systemGray.cgColor)
            context.setLineWidth(1)
            for i in 0..<3 {
                let lineY = clipboardY + 6 + CGFloat(i) * 6
                context.move(to: CGPoint(x: clipboardX + 3, y: lineY))
                context.addLine(to: CGPoint(x: clipboardX + 15, y: lineY))
            }
            context.strokePath()
        }
    }

    private func drawTable(context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        // Table top
        context.setFillColor(UIColor(red: 139/255, green: 90/255, blue: 43/255, alpha: 1.0).cgColor)
        context.fill(CGRect(x: x - width/2, y: y, width: width, height: height))

        // Table legs
        context.setLineWidth(8)
        context.setStrokeColor(UIColor(red: 101/255, green: 67/255, blue: 33/255, alpha: 1.0).cgColor)
        context.move(to: CGPoint(x: x - width/2 + 12, y: y + height))
        context.addLine(to: CGPoint(x: x - width/2 + 12, y: y + height + 45))
        context.move(to: CGPoint(x: x + width/2 - 12, y: y + height))
        context.addLine(to: CGPoint(x: x + width/2 - 12, y: y + height + 45))
        context.strokePath()
    }

    private func drawChair(context: CGContext, x: CGFloat, y: CGFloat) {
        let chairColor = UIColor(red: 100/255, green: 100/255, blue: 100/255, alpha: 1.0)

        // Seat
        context.setFillColor(chairColor.cgColor)
        context.fill(CGRect(x: x, y: y + 30, width: 40, height: 8))

        // Back
        context.setLineWidth(6)
        context.setStrokeColor(chairColor.cgColor)
        context.move(to: CGPoint(x: x, y: y))
        context.addLine(to: CGPoint(x: x, y: y + 38))

        // Legs
        context.move(to: CGPoint(x: x + 5, y: y + 38))
        context.addLine(to: CGPoint(x: x + 5, y: y + 70))
        context.move(to: CGPoint(x: x + 35, y: y + 38))
        context.addLine(to: CGPoint(x: x + 35, y: y + 70))
        context.strokePath()
    }

    /// Generate fallback 50-frame storyboard if API fails
    private func generate50FrameFallbackStoryboard(experiment: Experiment) -> [String] {
        var frames: [String] = []

        // Act 1: Setup (Frames 1-15)
        frames.append("Frame 1: Empty laboratory room with table and chairs, light gray background")
        frames.append("Frame 2: Laboratory room, researcher enters from left side at 10%")
        frames.append("Frame 3: Researcher walking, now at 15% from left")
        frames.append("Frame 4: Researcher at 20%, walking toward center")
        frames.append("Frame 5: Researcher at 25%, clipboard in hand")
        frames.append("Frame 6: Researcher standing at center-left (25%), checking clipboard")
        frames.append("Frame 7: Researcher looking toward right side, clipboard raised")
        frames.append("Frame 8: Participant enters from right at 90%")
        frames.append("Frame 9: Participant walking, now at 85%")
        frames.append("Frame 10: Participant at 80%, researcher gestures welcome")
        frames.append("Frame 11: Participant at 75%, researcher pointing to chair")
        frames.append("Frame 12: Participant at 70%, approaching chair near table")
        frames.append("Frame 13: Participant sitting down on chair, researcher standing nearby")
        frames.append("Frame 14: Participant seated, researcher explaining with gestures")
        frames.append("Frame 15: Participant seated listening, researcher holding clipboard, talking")

        // Act 2: Experiment (Frames 16-35)
        frames.append("Frame 16: Researcher points to equipment on table, participant watches")
        frames.append("Frame 17: Participant leans forward with interest, researcher explaining")
        frames.append("Frame 18: Researcher demonstrates procedure, participant observing closely")
        frames.append("Frame 19: Participant begins experimental task, researcher steps back")
        frames.append("Frame 20: Participant focused on task, researcher taking notes")
        frames.append("Frame 21: Participant working, researcher observing from left side")
        frames.append("Frame 22: Participant shows concentration, slight movement")
        frames.append("Frame 23: Researcher writes on clipboard, participant continues task")
        frames.append("Frame 24: Key moment - participant reacts to stimulus")
        frames.append("Frame 25: Participant shows surprise, arms slightly raised")
        frames.append("Frame 26: Researcher notes reaction, participant processing")
        frames.append("Frame 27: Participant continues with modified behavior")
        frames.append("Frame 28: Researcher moves closer to observe")
        frames.append("Frame 29: Participant shows second reaction, researcher watching intently")
        frames.append("Frame 30: Critical experimental moment, participant engaged")
        frames.append("Frame 31: Researcher takes detailed notes, participant focused")
        frames.append("Frame 32: Participant shows emotional response")
        frames.append("Frame 33: Researcher maintains neutral observation stance")
        frames.append("Frame 34: Participant nearing completion of task")
        frames.append("Frame 35: Task complete, participant looks to researcher")

        // Act 3: Conclusion (Frames 36-50)
        frames.append("Frame 36: Researcher approaches participant with clipboard")
        frames.append("Frame 37: Researcher begins debriefing, gesturing while speaking")
        frames.append("Frame 38: Participant listening to explanation, seated")
        frames.append("Frame 39: Researcher reveals study purpose, participant reacts")
        frames.append("Frame 40: Discussion continues, participant nods understanding")
        frames.append("Frame 41: Researcher shows results on clipboard to participant")
        frames.append("Frame 42: Participant examines information, leaning forward")
        frames.append("Frame 43: Both discussing findings, interactive conversation")
        frames.append("Frame 44: Participant stands up from chair")
        frames.append("Frame 45: Researcher extends hand, participant shakes it")
        frames.append("Frame 46: Participant begins walking toward exit at 75%")
        frames.append("Frame 47: Participant at 80%, researcher waves goodbye")
        frames.append("Frame 48: Participant at 85%, walking toward right")
        frames.append("Frame 49: Participant at 90%, nearly exited")
        frames.append("Frame 50: Participant exited, researcher alone writing final notes")

        return frames
    }

    /// Legacy fallback method
    private func generateFallbackStoryboard(experiment: Experiment) -> [String] {
        return generate50FrameFallbackStoryboard(experiment: experiment)
    }

    private func getRandomFallbackExperiment(excludingNames: [String]) -> Experiment {
        let fallbackExperiments = [
            Experiment(
                name: "Stanford Prison Experiment",
                info: "Participants were randomly assigned to be 'prisoners' or 'guards' in a simulated prison. The study was ended early after guards became abusive and prisoners showed signs of extreme stress and emotional disturbance.",
                date: "1971",
                researchers: "Philip Zimbardo",
                hypothesis: "Social roles and situational factors significantly influence human behavior, potentially overriding individual personality traits.",
                rejected: false
            ),
            Experiment(
                name: "Milgram Obedience Study",
                info: "Participants were instructed to administer increasingly powerful electric shocks to a learner (actually an actor). 65% of participants continued to the maximum 450-volt shock despite hearing screams of pain.",
                date: "1961",
                researchers: "Stanley Milgram",
                hypothesis: "Ordinary people will obey authority figures even when asked to perform actions that conflict with their personal conscience.",
                rejected: false
            ),
            Experiment(
                name: "Little Albert Experiment",
                info: "A 9-month-old infant was conditioned to fear a white rat by pairing it with a loud, frightening noise. The fear generalized to other white, furry objects including a rabbit and a Santa Claus mask.",
                date: "1920",
                researchers: "John B. Watson, Rosalie Rayner",
                hypothesis: "Emotional responses like fear can be classically conditioned in humans and will generalize to similar stimuli.",
                rejected: false
            ),
            Experiment(
                name: "Bobo Doll Experiment",
                info: "Children observed adults behaving aggressively toward an inflatable doll. Those who watched aggressive models were significantly more likely to imitate the aggressive behavior when given the opportunity.",
                date: "1961",
                researchers: "Albert Bandura",
                hypothesis: "Children learn and imitate aggressive behaviors by observing adult role models.",
                rejected: false
            ),
            Experiment(
                name: "Asch Conformity Experiments",
                info: "Participants were asked to match line lengths in a group setting where confederates gave obviously wrong answers. About 75% of participants conformed to the incorrect group answer at least once.",
                date: "1951",
                researchers: "Solomon Asch",
                hypothesis: "Individuals will conform to group consensus even when the group's answer is clearly incorrect.",
                rejected: false
            ),
            Experiment(
                name: "Harlow's Monkey Experiments",
                info: "Infant monkeys were given a choice between a wire 'mother' with food and a soft cloth 'mother' without food. The monkeys overwhelmingly preferred the comfort of the cloth mother, challenging behaviorist theories.",
                date: "1958",
                researchers: "Harry Harlow",
                hypothesis: "Attachment in infants is based primarily on contact comfort rather than feeding.",
                rejected: false
            ),
            Experiment(
                name: "Marshmallow Test",
                info: "Children were offered a choice between one marshmallow immediately or two if they waited 15 minutes. Follow-up studies found that children who waited tended to have better life outcomes decades later.",
                date: "1972",
                researchers: "Walter Mischel",
                hypothesis: "The ability to delay gratification in childhood predicts better outcomes in adolescence and adulthood.",
                rejected: false
            ),
            Experiment(
                name: "Robbers Cave Experiment",
                info: "Two groups of boys at a summer camp were put in competition, leading to hostility. Conflict was reduced when the groups had to work together on superordinate goals requiring cooperation.",
                date: "1954",
                researchers: "Muzafer Sherif",
                hypothesis: "Intergroup conflict can be reduced through cooperative activities that require groups to work together toward common goals.",
                rejected: false
            ),
            Experiment(
                name: "Bystander Effect Study",
                info: "Participants heard what they believed was someone having a seizure. When alone, 85% helped, but when they believed others were present, only 31% took action.",
                date: "1968",
                researchers: "John Darley, Bibb Latané",
                hypothesis: "The presence of other bystanders reduces an individual's likelihood of helping someone in distress.",
                rejected: false
            ),
            Experiment(
                name: "Cognitive Dissonance Experiment",
                info: "Participants performed boring tasks then were paid either $1 or $20 to tell the next participant it was enjoyable. Those paid $1 rated the task more enjoyable, having less justification for lying.",
                date: "1959",
                researchers: "Leon Festinger, James Carlsmith",
                hypothesis: "When behavior conflicts with beliefs, people will change their beliefs to reduce psychological discomfort.",
                rejected: false
            )
        ]

        let available = fallbackExperiments.filter { !excludingNames.contains($0.name) }
        return available.randomElement() ?? fallbackExperiments[0]
    }
}

struct GeminiResponse: Codable {
    let candidates: [Candidate]?
}

struct Candidate: Codable {
    let content: Content?
}

struct Content: Codable {
    let parts: [Part]?
}

struct Part: Codable {
    let text: String?
}

struct HypothesisResult: Codable {
    let hypothesis: String
    let rejected: Bool
}

struct GuessCheckResult: Codable {
    let correct: Bool
    let reasoning: String?
}

// MARK: - Theory Generation

extension GeminiService {
    func getRandomTheory(excludingNames: [String]) async throws -> Theory {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let excludeList = excludingNames.isEmpty ? "none" : excludingNames.joined(separator: ", ")

        let prompt = """
        Generate a random famous psychology theory. Do NOT use any of these theories: \(excludeList).

        Respond ONLY with valid JSON in this exact format (no markdown, no code blocks, just raw JSON):
        {
            "name": "Name of the theory",
            "info": "A brief 2-3 sentence description of what the theory explains and its key concepts, without mentioning the theory name",
            "yearCreated": "Year or decade when it was first proposed",
            "theorists": "Names of the primary theorists who developed it"
        }
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("🔵 Gemini API Status Code (Theory): \(httpResponse.statusCode)")
        }

        if let rawString = String(data: data, encoding: .utf8) {
            print("🔵 Gemini Raw Response (Theory): \(rawString)")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = geminiResponse.candidates?.first?.content?.parts?.first?.text {
            print("🔵 Gemini Text Content (Theory): \(text)")

            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            print("🔵 Cleaned JSON (Theory): \(cleaned)")

            if let jsonData = cleaned.data(using: .utf8) {
                do {
                    let theory = try JSONDecoder().decode(Theory.self, from: jsonData)
                    print("🟢 Successfully parsed theory: \(theory.name)")
                    return theory
                } catch {
                    print("🔴 JSON Decode Error (Theory): \(error)")
                    throw error
                }
            }
        } else {
            print("🔴 No text content in Gemini response (Theory)")
        }

        // Fallback to local theories if API fails
        print("🟡 Using fallback theory")
        return getRandomFallbackTheory(excludingNames: excludingNames)
    }

    func checkTheoryGuess(userGuess: String, actualName: String) async throws -> GuessResult {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        I'm playing a psychology theory guessing game. The actual theory name is "\(actualName)".
        The user guessed: "\(userGuess)"

        STRICT RULES - The guess must demonstrate specific knowledge of THIS theory:

        REJECT the guess if:
        - It's too generic (e.g., "theory", "psychology theory", "the theory")
        - It only mentions a broad concept without the specific theory name
        - It names a completely different theory
        - It's just random words or gibberish

        ACCEPT the guess if:
        - It contains the distinctive identifier (e.g., "Attachment", "Maslow", "Cognitive Dissonance")
        - It's an abbreviated but specific version (e.g., "maslow's hierarchy" for "Maslow's Hierarchy of Needs")
        - It's a well-known alternate name for the same theory
        - It has minor typos but the specific theory is clearly identifiable
        - It uses slightly different wording but refers to the same specific theory

        The key test: Would a psychology professor agree the student knows which specific theory this is?

        Respond ONLY with valid JSON in this exact format (no markdown, no code blocks):
        {"correct": true} or {"correct": false, "reasoning": "brief explanation of why it's wrong"}
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = response.candidates?.first?.content?.parts?.first?.text {
            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let jsonData = cleaned.data(using: .utf8) {
                let result = try JSONDecoder().decode(GuessCheckResult.self, from: jsonData)
                return GuessResult(isCorrect: result.correct, reasoning: result.reasoning)
            }
        }

        return GuessResult(isCorrect: false, reasoning: nil)
    }

    func categorizeTheory(name: String, info: String) async throws -> String {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Categorize this psychology theory into ONE of these categories:
        - social (social psychology, group dynamics)
        - cognitive (thinking, decision making, mental processes)
        - developmental (child development, aging, lifespan)
        - behavioral (conditioning, behavior modification)
        - emotional (emotions, affect, mood)
        - personality (traits, individual differences)
        - learning (education, skill acquisition)
        - motivation (goals, drives, needs)
        - attachment (bonding, relationships)
        - humanistic (self-actualization, growth)
        - psychodynamic (unconscious, defense mechanisms)
        - biological (brain, genetics, evolution)

        Theory: "\(name)"
        Description: "\(info)"

        Respond with ONLY the category name, nothing else.
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = response.candidates?.first?.content?.parts?.first?.text {
            let category = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            print("🔵 Categorized theory '\(name)' as: \(category)")
            return category
        }

        return "default"
    }

    private func getRandomFallbackTheory(excludingNames: [String]) -> Theory {
        let fallbackTheories = [
            Theory(
                name: "Attachment Theory",
                info: "This theory explains how early emotional bonds between infants and caregivers shape social and emotional development throughout life. It identifies different attachment styles that influence relationships and behavior in adulthood.",
                yearCreated: "1969",
                theorists: "John Bowlby, Mary Ainsworth"
            ),
            Theory(
                name: "Maslow's Hierarchy of Needs",
                info: "A motivational theory proposing that human needs are arranged in a hierarchical structure, from basic physiological needs to self-actualization. Lower-level needs must be satisfied before higher-level needs become motivating.",
                yearCreated: "1943",
                theorists: "Abraham Maslow"
            ),
            Theory(
                name: "Cognitive Dissonance Theory",
                info: "This theory describes the mental discomfort experienced when holding contradictory beliefs, values, or attitudes. People are motivated to reduce this discomfort by changing their attitudes or rationalizing their behavior.",
                yearCreated: "1957",
                theorists: "Leon Festinger"
            ),
            Theory(
                name: "Social Learning Theory",
                info: "A theory explaining how people learn behaviors by observing others and imitating their actions. It emphasizes the role of modeling, reinforcement, and cognitive processes in learning.",
                yearCreated: "1977",
                theorists: "Albert Bandura"
            ),
            Theory(
                name: "Psychoanalytic Theory",
                info: "A comprehensive theory of personality and psychotherapy that emphasizes the role of unconscious mental processes, early childhood experiences, and internal conflicts in shaping behavior and mental health.",
                yearCreated: "1900",
                theorists: "Sigmund Freud"
            ),
            Theory(
                name: "Erikson's Stages of Psychosocial Development",
                info: "A developmental theory proposing eight stages of psychosocial development throughout the lifespan, each characterized by a specific crisis or challenge that must be resolved for healthy development.",
                yearCreated: "1950",
                theorists: "Erik Erikson"
            ),
            Theory(
                name: "Piaget's Theory of Cognitive Development",
                info: "A stage theory describing how children construct knowledge through interaction with their environment, progressing through distinct stages of cognitive development from infancy to adolescence.",
                yearCreated: "1936",
                theorists: "Jean Piaget"
            ),
            Theory(
                name: "Classical Conditioning",
                info: "A learning process where a neutral stimulus becomes associated with a meaningful stimulus, eventually triggering a similar response. This explains how emotional and physiological responses can be learned.",
                yearCreated: "1897",
                theorists: "Ivan Pavlov"
            ),
            Theory(
                name: "Operant Conditioning",
                info: "A learning theory based on the principle that behaviors are strengthened or weakened by their consequences. Reinforcement increases behavior frequency while punishment decreases it.",
                yearCreated: "1938",
                theorists: "B.F. Skinner"
            ),
            Theory(
                name: "Self-Determination Theory",
                info: "A theory of motivation focusing on three innate psychological needs: autonomy, competence, and relatedness. Fulfillment of these needs promotes intrinsic motivation and psychological well-being.",
                yearCreated: "1985",
                theorists: "Edward Deci, Richard Ryan"
            )
        ]

        let available = fallbackTheories.filter { !excludingNames.contains($0.name) }
        return available.randomElement() ?? fallbackTheories[0]
    }
}
