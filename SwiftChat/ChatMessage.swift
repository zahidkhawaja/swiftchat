//
//  ChatMessage.swift
//  SwiftChat
//

import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let message: String
    let isUser: Bool
}
