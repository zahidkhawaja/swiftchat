//
//  APIService.swift
//  SwiftChat
//

import Foundation
import OpenAIKit

class APIService {
    private var openAIClient: OpenAIKit.Client
    private var messages: [Chat.Message] = []
    let settings: AppSettings
    var currentModel: ModelID = Model.GPT3.gpt3_5Turbo
    var currentTask: Task<Void, Never>?
    
    init(settings: AppSettings) {
        // Store API keys in secrets.plist
        // Example: secrets.plist.example
        let apiKey = getConfigValue(for: "OPENAI_API_KEY")
        let organization = getConfigValue(for: "OPENAI_ORG_ID")
        let urlSession = URLSession(configuration: .default)
        let configuration = Configuration(apiKey: apiKey, organization: organization)
        self.openAIClient = OpenAIKit.Client(session: urlSession, configuration: configuration)
        self.settings = settings
        // System message initialization as the beginning of the conversation.
        self.messages.append(Chat.Message.system(content: settings.systemPrompt))
    }
    
    func sendStreamMessage(_ message: String, completion: @escaping (Result<String, Error>) -> Void) {
        
        currentTask?.cancel()
        
        currentTask = Task<Void, Never> {
            do {
                // Create a new user message and add it to the messages array.
                let userMessage = Chat.Message.user(content: message)
                self.messages.append(userMessage)
                
                let stream = try await self.openAIClient.chats.stream(
                    model: currentModel,
                    messages: self.messages
                )
                
                for try await chat in stream {
                    if let responseMessage = chat.choices.first?.delta.content {
                        // Add the response message to the messages array.
                        self.messages.append(Chat.Message.assistant(content: responseMessage))
                        completion(.success(responseMessage))
                    }
                }
            } catch let error as APIErrorResponse {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func cancelCurrentRequest() {
        currentTask?.cancel()
    }
    
    func changeModel(to newModel: ModelID) {
        currentModel = newModel
    }
    
    func clearAllMessages() {
        messages.removeAll()
        // System message initialization as the beginning of the conversation.
        messages.append(Chat.Message.system(content: settings.systemPrompt))
    }
    
}

// Store API keys in secrets.plist
// Example: secrets.plist.example
func getConfigValue(for key: String) -> String {
    if let path = Bundle.main.path(forResource: "secrets", ofType: "plist"),
       let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
        return dict[key] as? String ?? ""
    }
    return ""
}









