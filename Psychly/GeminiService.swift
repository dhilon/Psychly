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
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    private let imagenURL = "https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-001:predict"

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

    func getRandomNumber() async throws -> Int {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Generate a random number between 1 and 10. Only respond with the number, nothing else."]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = response.candidates?.first?.content?.parts?.first?.text {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let number = Int(trimmed) {
                return number
            }
        }

        return Int.random(in: 1...10)
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

    /// Generate a storyboard of 10 scene descriptions for an experiment animation
    func generateExperimentStoryboard(experiment: Experiment) async throws -> [String] {
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

        Create a 10-scene storyboard for a 20-second animation showing this experiment.
        Each scene should be a single frame description that:
        - Uses colorful stick figures (researchers in blue coats, participants in green)
        - Shows specific actions and poses (standing, sitting, pointing, reacting)
        - Includes relevant props, costumes, or devices used in the experiment
        - Has a simple colored background appropriate to the setting (lab, room, outdoors)
        - Tells the story of what happened in the experiment sequentially

        Respond ONLY with a valid JSON array of 10 scene descriptions (no markdown, no code blocks):
        ["Scene 1 description", "Scene 2 description", ..., "Scene 10 description"]
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
                print("🟢 Generated \(scenes.count) scene descriptions")
                return scenes
            }
        }

        // Fallback: generate generic scenes
        return generateFallbackStoryboard(experiment: experiment)
    }

    /// Generate an image for a scene description using Imagen 3
    func generateSceneImage(description: String, experimentName: String) async throws -> UIImage {
        let url = URL(string: "\(imagenURL)?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let imagePrompt = """
        Create a simple, colorful cartoon illustration showing:
        \(description)

        Style requirements:
        - Simple stick figure characters with colored bodies (not just black lines)
        - Researchers wear blue, participants wear green
        - Bright, cheerful colors
        - Clean white or light colored background
        - Simple shapes and clear composition
        - Suitable for animation frame
        - No text or labels in the image
        """

        let body: [String: Any] = [
            "instances": [
                ["prompt": imagePrompt]
            ],
            "parameters": [
                "sampleCount": 1,
                "aspectRatio": "1:1",
                "safetyFilterLevel": "block_few"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("🔵 Imagen API Status Code: \(httpResponse.statusCode)")
        }

        // Parse Imagen response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let predictions = json["predictions"] as? [[String: Any]],
           let firstPrediction = predictions.first,
           let bytesBase64 = firstPrediction["bytesBase64Encoded"] as? String,
           let imageData = Data(base64Encoded: bytesBase64),
           let image = UIImage(data: imageData) {
            print("🟢 Successfully generated image")
            return image
        }

        // If Imagen fails, try generating with Gemini's native image generation
        print("🟡 Imagen failed, trying fallback image generation")
        return try await generateFallbackImage(description: description)
    }

    /// Fallback image generation using a placeholder
    private func generateFallbackImage(description: String) async throws -> UIImage {
        // Create a simple colored placeholder image
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            // Background
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw simple stick figures
            let figureColor = UIColor.systemBlue
            figureColor.setStroke()

            let path = UIBezierPath()
            // Simple stick figure
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Head
            path.move(to: CGPoint(x: centerX, y: centerY - 60))
            path.addArc(withCenter: CGPoint(x: centerX, y: centerY - 80), radius: 20, startAngle: 0, endAngle: .pi * 2, clockwise: true)

            // Body
            path.move(to: CGPoint(x: centerX, y: centerY - 60))
            path.addLine(to: CGPoint(x: centerX, y: centerY + 20))

            // Arms
            path.move(to: CGPoint(x: centerX - 40, y: centerY - 20))
            path.addLine(to: CGPoint(x: centerX + 40, y: centerY - 20))

            // Legs
            path.move(to: CGPoint(x: centerX, y: centerY + 20))
            path.addLine(to: CGPoint(x: centerX - 30, y: centerY + 80))
            path.move(to: CGPoint(x: centerX, y: centerY + 20))
            path.addLine(to: CGPoint(x: centerX + 30, y: centerY + 80))

            path.lineWidth = 4
            path.stroke()
        }

        return image
    }

    /// Generate fallback storyboard if API fails
    private func generateFallbackStoryboard(experiment: Experiment) -> [String] {
        return [
            "A researcher in a blue coat stands in a laboratory setting, clipboard in hand",
            "Participants in green arrive and are greeted by the researcher",
            "The researcher explains the experiment procedure to the participants",
            "Participants begin the experimental task",
            "A participant shows concentration while performing the task",
            "The researcher observes and takes notes",
            "Participants interact with experimental materials or each other",
            "A key moment in the experiment occurs",
            "Participants react to the experimental condition",
            "The experiment concludes with the researcher thanking participants"
        ]
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
