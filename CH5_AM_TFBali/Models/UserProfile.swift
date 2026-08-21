//
//  UserProfile.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 21/08/26.
//

import SwiftData
import Foundation

@Model
final class UserProfile {
    @Relationship(deleteRule: .cascade) var historyItems: [HistoryItem] = []
    
    init(historyItems: [HistoryItem] = []) {
        self.historyItems = historyItems
    }
}

@Model
final class HistoryItem {
    var id: UUID
    var title: String
    var date: Date
    var videoPath: String?
    @Attribute(.externalStorage) var thumbnailData: Data?
    
    init(title: String, date: Date = Date(), videoPath: String? = nil, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.videoPath = videoPath
        self.thumbnailData = thumbnailData
    }
}
