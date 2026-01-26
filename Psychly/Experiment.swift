//
//  Experiment.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import Foundation

struct Experiment: Codable {
    let name: String
    let info: String
    let date: String
    let researchers: String
    let hypothesis: String
    let rejected: Bool
    var badgeIcon: String?
    var badgeCategory: String?

    var displayBadgeIcon: String {
        badgeIcon ?? "flask.fill"
    }
}
