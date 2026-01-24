//
//  GeminiService.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import Foundation

class GeminiService {
    static let shared = GeminiService()

    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

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
            "info": "A brief 2-3 sentence description of what the experiment was about and what happened",
            "date": "Year or date range when it was conducted",
            "researchers": "Names of the primary researchers",
            "question": "An interesting question about the results or implications that makes people think"
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

    private func getRandomFallbackExperiment(excludingNames: [String]) -> Experiment {
        let fallbackExperiments = [
            Experiment(
                name: "Stanford Prison Experiment",
                info: "Participants were randomly assigned to be 'prisoners' or 'guards' in a simulated prison. The study was ended early after guards became abusive and prisoners showed signs of extreme stress and emotional disturbance.",
                date: "1971",
                researchers: "Philip Zimbardo",
                question: "How much of our behavior is determined by the roles we're assigned versus our individual personalities?"
            ),
            Experiment(
                name: "Milgram Obedience Study",
                info: "Participants were instructed to administer increasingly powerful electric shocks to a learner (actually an actor). 65% of participants continued to the maximum 450-volt shock despite hearing screams of pain.",
                date: "1961",
                researchers: "Stanley Milgram",
                question: "Under what conditions do ordinary people follow orders that harm others?"
            ),
            Experiment(
                name: "Little Albert Experiment",
                info: "A 9-month-old infant was conditioned to fear a white rat by pairing it with a loud, frightening noise. The fear generalized to other white, furry objects including a rabbit and a Santa Claus mask.",
                date: "1920",
                researchers: "John B. Watson, Rosalie Rayner",
                question: "How do our early experiences shape our fears and emotional responses throughout life?"
            ),
            Experiment(
                name: "Bobo Doll Experiment",
                info: "Children observed adults behaving aggressively toward an inflatable doll. Those who watched aggressive models were significantly more likely to imitate the aggressive behavior when given the opportunity.",
                date: "1961",
                researchers: "Albert Bandura",
                question: "To what extent do children learn violent behavior from observing adults?"
            ),
            Experiment(
                name: "Asch Conformity Experiments",
                info: "Participants were asked to match line lengths in a group setting where confederates gave obviously wrong answers. About 75% of participants conformed to the incorrect group answer at least once.",
                date: "1951",
                researchers: "Solomon Asch",
                question: "Why do people conform to group opinions even when they know the group is wrong?"
            ),
            Experiment(
                name: "Harlow's Monkey Experiments",
                info: "Infant monkeys were given a choice between a wire 'mother' with food and a soft cloth 'mother' without food. The monkeys overwhelmingly preferred the comfort of the cloth mother, challenging behaviorist theories.",
                date: "1958",
                researchers: "Harry Harlow",
                question: "What does this tell us about the importance of emotional attachment versus physical needs?"
            ),
            Experiment(
                name: "Marshmallow Test",
                info: "Children were offered a choice between one marshmallow immediately or two if they waited 15 minutes. Follow-up studies found that children who waited tended to have better life outcomes decades later.",
                date: "1972",
                researchers: "Walter Mischel",
                question: "Is self-control in childhood a reliable predictor of success in adulthood?"
            ),
            Experiment(
                name: "Robbers Cave Experiment",
                info: "Two groups of boys at a summer camp were put in competition, leading to hostility. Conflict was reduced when the groups had to work together on superordinate goals requiring cooperation.",
                date: "1954",
                researchers: "Muzafer Sherif",
                question: "How can we reduce conflict between opposing groups in society?"
            ),
            Experiment(
                name: "Bystander Effect Study",
                info: "Participants heard what they believed was someone having a seizure. When alone, 85% helped, but when they believed others were present, only 31% took action.",
                date: "1968",
                researchers: "John Darley, Bibb Latané",
                question: "Why does the presence of others reduce our likelihood of helping someone in need?"
            ),
            Experiment(
                name: "Cognitive Dissonance Experiment",
                info: "Participants performed boring tasks then were paid either $1 or $20 to tell the next participant it was enjoyable. Those paid $1 rated the task more enjoyable, having less justification for lying.",
                date: "1959",
                researchers: "Leon Festinger, James Carlsmith",
                question: "How do we change our beliefs to match our behaviors when they conflict?"
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
