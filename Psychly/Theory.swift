//
//  Theory.swift
//  Psychly
//
//  Created by Dhilon Prasad on 2/6/26.
//

import Foundation

struct Theory: Codable {
    let name: String           // e.g., "Attachment Theory"
    let info: String           // What the theory explains
    let yearCreated: String    // When created (for hint)
    let theorists: String      // Who theorized it (for hint)
    var badgeIcon: String?
    var badgeCategory: String?

    var displayBadgeIcon: String {
        badgeIcon ?? "lightbulb.fill"
    }
}
