//
//  GIFGenerationService.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/26/26.
//

import Foundation
import UIKit
import FirebaseStorage

class GIFGenerationService {
    static let shared = GIFGenerationService()

    private let storage = Storage.storage()

    private init() {}

    // MARK: - Public Methods

    /// Generate frames for an experiment animation
    func generateExperimentFrames(experiment: Experiment) async throws -> [UIImage] {
        print("🔵 Generating frames for experiment: \(experiment.name)")

        // 1. Generate storyboard (10 scene descriptions)
        let scenes = try await GeminiService.shared.generateExperimentStoryboard(experiment: experiment)
        print("🔵 Generated \(scenes.count) scene descriptions")

        // 2. Generate images for each scene
        var frames: [UIImage] = []
        for (index, scene) in scenes.enumerated() {
            print("🔵 Generating frame \(index + 1)/\(scenes.count)")
            do {
                let image = try await GeminiService.shared.generateSceneImage(description: scene, experimentName: experiment.name)
                frames.append(image)
            } catch {
                print("🟡 Failed to generate frame \(index + 1): \(error.localizedDescription)")
                // Continue with other frames
            }
        }

        // Need at least 1 frame
        guard !frames.isEmpty else {
            throw GIFGenerationError.noFramesGenerated
        }

        print("🟢 Generated \(frames.count) frames successfully")
        return frames
    }

    /// Get cached frames from Firebase Storage
    func getCachedFrames(experimentDate: String) async -> [UIImage]? {
        print("🔵 Checking cache for date: \(experimentDate)")

        var frames: [UIImage] = []
        let maxFrames = 10

        for index in 0..<maxFrames {
            let path = "animations/\(experimentDate)/frame_\(index).png"
            let ref = storage.reference().child(path)

            do {
                let data = try await ref.data(maxSize: 5 * 1024 * 1024) // 5MB max
                if let image = UIImage(data: data) {
                    frames.append(image)
                }
            } catch {
                // No more frames or error
                break
            }
        }

        if frames.isEmpty {
            print("🟡 No cached frames found")
            return nil
        }

        print("🟢 Loaded \(frames.count) cached frames")
        return frames
    }

    /// Cache frames to Firebase Storage
    func cacheFrames(frames: [UIImage], experimentDate: String) async throws {
        print("🔵 Caching \(frames.count) frames for date: \(experimentDate)")

        for (index, frame) in frames.enumerated() {
            guard let data = frame.pngData() else { continue }

            let path = "animations/\(experimentDate)/frame_\(index).png"
            let ref = storage.reference().child(path)

            let metadata = StorageMetadata()
            metadata.contentType = "image/png"

            _ = try await ref.putDataAsync(data, metadata: metadata)
            print("🔵 Cached frame \(index + 1)/\(frames.count)")
        }

        print("🟢 Successfully cached all frames")
    }
}

// MARK: - Errors

enum GIFGenerationError: Error, LocalizedError {
    case noFramesGenerated
    case imageGenerationFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noFramesGenerated:
            return "No frames could be generated for this experiment"
        case .imageGenerationFailed:
            return "Failed to generate image"
        case .invalidResponse:
            return "Invalid response from image generation API"
        }
    }
}
