//
//  Photo.swift
//  VirtualTourist
//
//  Created by Gunel Aydinova on 6/5/24.
//

import Foundation

struct PhotoSearchResponse: Codable, Equatable {
    let photos: Photos

    enum CodingKeys: String, CodingKey {
        case photos = "photos"
    }
}

struct Photos: Codable, Equatable {
    let currentPage: Int
    let itemsPerPage: Int
    let totalPages: Int
    let totalItems: Int
    let photoList: [PhotoDetails]

    enum CodingKeys: String, CodingKey {
        case currentPage = "page"
        case itemsPerPage = "perpage"
        case totalPages = "pages"
        case totalItems = "total"
        case photoList = "photo"
    }
}

struct PhotoDetails: Codable, Equatable {
    let identifier: String
    let ownerId: String
    let secretKey: String
    let serverId: String
    let farmId: Int
    let title: String
    let isPublic: Int
    let isFriend: Int
    let isFamily: Int

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case ownerId = "owner"
        case secretKey = "secret"
        case serverId = "server"
        case farmId = "farm"
        case title
        case isPublic = "ispublic"
        case isFriend = "isfriend"
        case isFamily = "isfamily"
    }
}
