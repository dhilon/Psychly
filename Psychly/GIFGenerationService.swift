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
    private let maxFrames = 50

    private init() {}

    // MARK: - Public Methods

    /// Progress callback type for frame generation updates
    typealias ProgressCallback = (Int, Int) -> Void

    /// Generate 50 frames for a flipbook-style experiment animation
    func generateExperimentFrames(experiment: Experiment, onProgress: ProgressCallback? = nil) async throws -> [UIImage] {
        print("🔵 Generating 50 frames for experiment: \(experiment.name)")

        // 1. Generate storyboard (50 frame descriptions)
        let scenes = try await GeminiService.shared.generate50FrameStoryboard(experiment: experiment)
        print("🔵 Generated \(scenes.count) frame descriptions")

        // 2. Generate images for each scene
        var frames: [UIImage] = []
        for (index, scene) in scenes.enumerated() {
            print("🔵 Generating frame \(index + 1)/\(scenes.count)")
            onProgress?(index + 1, scenes.count)

            do {
                let image = try await GeminiService.shared.generateSceneImage(
                    description: scene,
                    experimentName: experiment.name,
                    frameIndex: index
                )
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
    /// Storage path: videos/{date}_{experimentName}/frame_X.png
    func getCachedFrames(experimentDate: String, experimentName: String) async -> [UIImage]? {
        let sanitizedName = sanitizeExperimentName(experimentName)
        let basePath = "videos/\(experimentDate)_\(sanitizedName)"
        print("🔵 Checking cache at: \(basePath)")

        var frames: [UIImage] = []

        for index in 0..<maxFrames {
            let path = "\(basePath)/frame_\(index).png"
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

        // Require all 50 frames for valid cache
        if frames.count < maxFrames {
            print("🟡 Incomplete cache: found \(frames.count)/\(maxFrames) frames")
            return nil
        }

        print("🟢 Loaded \(frames.count) cached frames")
        return frames
    }

    /// Cache frames to Firebase Storage
    /// Storage path: videos/{date}_{experimentName}/frame_X.png
    func cacheFrames(frames: [UIImage], experimentDate: String, experimentName: String) async throws {
        let sanitizedName = sanitizeExperimentName(experimentName)
        let basePath = "videos/\(experimentDate)_\(sanitizedName)"
        print("🔵 Caching \(frames.count) frames to: \(basePath)")

        for (index, frame) in frames.enumerated() {
            guard let data = frame.pngData() else { continue }

            let path = "\(basePath)/frame_\(index).png"
            let ref = storage.reference().child(path)

            let metadata = StorageMetadata()
            metadata.contentType = "image/png"

            _ = try await ref.putDataAsync(data, metadata: metadata)
            print("🔵 Cached frame \(index + 1)/\(frames.count)")
        }

        print("🟢 Successfully cached all frames")
    }

    // MARK: - Private Helpers

    /// Sanitize experiment name for use in storage path
    private func sanitizeExperimentName(_ name: String) -> String {
        return name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
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
