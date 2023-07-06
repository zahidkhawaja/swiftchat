//
//  ContentView.swift
//  SwiftChat
//

import SwiftUI
import OpenAIKit
import Combine

class AppSettings: ObservableObject {
    // Default system prompt
    @AppStorage("systemPrompt") var systemPrompt: String = "You are a helpful AI assistant."
}

// Native color shades
struct AppColors {
    static let purple = Color(#colorLiteral(red: 0.525, green: 0.435, blue: 0.690, alpha: 1))
    static let gray = Color(#colorLiteral(red: 0.196, green: 0.212, blue: 0.224, alpha: 1))
}

struct ContentView: View {
    @StateObject var settings = AppSettings()
    @StateObject var viewModel = ChatViewModel(settings: AppSettings())
    @State var chatInput: String = ""
    @State private var selectedModel: OpenAIModel = .gpt3_5Turbo
    @State private var animate: Bool = false
    @State private var showingSettings = false
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init() {
        impactFeedback.prepare()
    }
    
    private func scrollToLatestMessage(in proxy: ScrollViewProxy) {
        if viewModel.isLoading {
            proxy.scrollTo("loadingIndicator", anchor: .bottom)
        } else {
            let lastMessageIndex = viewModel.messages.count - 1
            if lastMessageIndex >= 0 {
                proxy.scrollTo(lastMessageIndex, anchor: .bottom)
            }
        }
    }
    
    var body: some View {
        VStack {
            if viewModel.messages.isEmpty {
                HStack {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(OpenAIModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 10)
                    .onChange(of: selectedModel) { newModel in
                        impactFeedback.impactOccurred()
                        viewModel.changeModel(to: newModel.modelID)
                    }
                    Spacer()
                    
                    Menu {
                        Button(action: {
                            showingSettings = true
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .foregroundColor(.gray)
                                    .imageScale(.large)
                                Text("Settings")
                            }
                        }
                        .padding(.horizontal, 0)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.purple)
                            .padding([.top, .bottom], 7.5).padding([.leading, .trailing], 5)
                    }
                }
                .padding(.horizontal, 20)
                
                .sheet(isPresented: $showingSettings) {
                    SettingsView(settings: settings)
                }
                
                
                Spacer()
                HStack {
                    HStack(spacing: 0) {
                        AnimatedCharacterView(character: "✈️", delay: 0)
                        ForEach(Array("SwiftChat".enumerated()), id: \.offset) { index, character in
                            AnimatedCharacterView(character: String(character), delay: (Double(index) + 1) * 0.05)
                        }
                    }
                    
                    
                    
                }
                Spacer()
            } else {
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack {
                            ForEach(viewModel.messages.indices, id: \.self) { index in
                                Text(viewModel.messages[index].message)
                                    .padding()
                                    .background(viewModel.messages[index].isUser ? AppColors.purple : AppColors.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: viewModel.messages[index].isUser ? .trailing : .leading)
                                    .id(index)
                                    .textSelection(.enabled)
                                    .onChange(of: viewModel.messages[index].message) { _ in
                                        scrollToLatestMessage(in: scrollView)
                                    }
                            }
                            if viewModel.isLoading {
                                TypingIndicatorView()
                                    .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .leading)
                                    .id("loadingIndicator")
                            }
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            scrollToLatestMessage(in: scrollView)
                        }
                    }
                    .padding(.top)
                    .background(Color.black.ignoresSafeArea())
                }
            }
            
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(viewModel.messages.isEmpty ? AppColors.gray: Color.gray.opacity(0.9))
                    .onTapGesture {
                        if !viewModel.messages.isEmpty {
                            impactFeedback.impactOccurred()
                            viewModel.clearAllMessages()
                            chatInput = ""
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                
                ZStack(alignment: .trailing) {
                    CustomTextField(placeholder: "Message", text: $chatInput)
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppColors.gray, lineWidth: 1.5)
                        )
                    
                    Button(action: {
                        if !chatInput.isEmpty {
                            impactFeedback.impactOccurred()
                            viewModel.sendMessage(chatInput)
                            chatInput = ""
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill") // Replace the "Send" text with an arrow icon
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor((chatInput.isEmpty || viewModel.isLoading) ? AppColors.gray : AppColors.purple)
                    }
                    .disabled(chatInput.isEmpty || viewModel.isLoading)
                    .padding(.trailing, 10)
                }
            }
            .padding()
        }
        .background(Color.black)
        .colorScheme(.dark)
        .onChange(of: settings.systemPrompt) { _ in
            viewModel.clearAllMessages()
        }
    }
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Chat")) {
                    NavigationLink(destination: SystemPromptView(settings: settings)) {
                        HStack {
                            Text("System Prompt")
                                .foregroundColor(.white)
                            Spacer()
                            Text(settings.systemPrompt)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    
                    
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.gray)
                        .padding(7.5)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            )
        }
        .background(Color.black.ignoresSafeArea())
        .colorScheme(.dark)
    }
}

struct SystemPromptView: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        Form {
            TextField("System Prompt", text: $settings.systemPrompt, axis: .vertical)
                .lineLimit(5)
        }
        .navigationBarTitle("System Prompt", displayMode: .inline)
    }
}


struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(AppColors.gray)
            }
            TextField("", text: $text, axis: .vertical)
                .lineLimit(4)
                .foregroundColor(.white)
        }
        .padding(.trailing)
    }
}

enum OpenAIModel: String, Hashable, CaseIterable {
    case gpt3_5Turbo = "gpt3_5Turbo"
    case gpt4 = "gpt4"
    
    var displayName: String {
        switch self {
        case .gpt3_5Turbo:
            return "GPT-3.5"
        case .gpt4:
            return "GPT-4"
        }
    }
    
    var modelID: ModelID {
        switch self {
        case .gpt3_5Turbo:
            return Model.GPT3.gpt3_5Turbo
        case .gpt4:
            return Model.GPT4.gpt4
        }
    }
}

struct AnimatedCharacterView: View {
    let character: String
    let delay: Double
    
    @State private var animate = false
    
    var body: some View {
        Group {
            if character == "✈️" {
                Image(systemName: "paperplane.fill")
                    .font(.title)
                    .foregroundColor(.white)
            } else {
                Text(character)
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .bold()
            }
        }
        .opacity(animate ? 1 : 0)
        .animation(Animation.easeOut(duration: 0.15).delay(delay), value: animate)
        .onAppear {
            animate = true
        }
    }
}

struct TypingIndicatorView: View {
    @State private var scale: CGFloat = 0.2
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: scale)
                .onAppear() { self.scale = 1.0 }
            
            Circle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 10, height: 10)
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.2), value: scale)
                .onAppear() { self.scale = 1.0 }
            
            Circle()
                .fill(Color.gray.opacity(0.8))
                .frame(width: 10, height: 10)
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.4), value: scale)
                .onAppear() { self.scale = 1.0 }
        }
        .padding(10)
        .background(AppColors.gray)
        .cornerRadius(10)
    }
}


// Uncomment to get a live preview in Xcode
// Might cause lag on older Macs

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}






