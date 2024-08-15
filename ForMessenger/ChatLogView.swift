import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    var chatUser: ChatUser?
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        fetchMessages()
    }
    var firestoreListener: ListenerRegistration?
    func fetchMessages() {
        guard let fromID = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toID = chatUser?.uid else { return }
        firestoreListener?.remove()
        chatMessages.removeAll()
        firestoreListener = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(fromID)
            .collection(toID)
            .order(by: FirebaseConstants.timestamp)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages"
                    //print(error)
                    return
                }
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        do {
                            if let cm = try? change.document.data(as: ChatMessage.self) {
                                self.chatMessages.append(cm)
                                //print("Appending chatMessage in ChatLogView: \(Date())")
                            }
                        } catch {
                            //print("Failed to decode message: \(error)")
                        }
                    }
                })
                DispatchQueue.main.async {
                    self.count += 1
                }
            }
    }
    func handleSend() {
        //print(chatText)
        guard let fromID = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toID = chatUser?.uid else { return }
        let document = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(fromID)
            .collection(toID)
            .document()
        let msg = ChatMessage(id: nil, fromID: fromID, toID: toID, text: chatText, timestamp: Date())
        try? document.setData(from: msg) { error in
            if let error = error {
                //print(error)
                self.errorMessage = "Failed to save message into Firestore"
                return
            }
            //print("Successfully saved current user sending message")
            self.persistRecentMessage()
            self.chatText = ""
            self.count += 1
        }
        let recipientMessageDocument = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(toID)
            .collection(fromID)
            .document()
        try? recipientMessageDocument.setData(from: msg) { error in
            if let error = error {
                //print(error)
                self.errorMessage = "Failed to save message into Firestore"
                return
            }
            //print("Recipient saved message as well")
        }
    }
    private func persistRecentMessage() {
        guard let chatUser = chatUser else { return }
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toID = self.chatUser?.uid else { return }
        let document = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recentMessages)
            .document(uid)
            .collection(FirebaseConstants.messages)
            .document(toID)
        let data = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromID: uid,
            FirebaseConstants.toID: toID,
            FirebaseConstants.profileImageURL: chatUser.profileImageURL,
            FirebaseConstants.email: chatUser.email
        ] as [String : Any]
        document.setData(data) { error in
            if let error = error {
                self.errorMessage = "Failed to save recent message"
                //print("Failed to save recent message: \(error)")
                return
            }
        }
    }
    @Published var count = 0
}
struct ChatLogView: View {
    @ObservedObject var vm: ChatLogViewModel
    var body: some View {
        ZStack {
            messagesView
            Text(vm.errorMessage)
        }
        .navigationTitle(vm.chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            vm.firestoreListener?.remove()
        }
    }
    static let emptyScrollToString = "Empty"
    private var messagesView: some View {
        VStack {
            if #available(iOS 15.0, *) {
                ScrollView {
                    ScrollViewReader { scrollViewProxy in
                        VStack {
                            ForEach(vm.chatMessages) { message in
                                MessageView(message: message)
                            }
                            HStack {
                                Spacer()
                            }
                            .id(Self.emptyScrollToString)
                        }
                        .onReceive(vm.$count) { _ in
                            withAnimation(.easeOut(duration: 0.5)) {
                                scrollViewProxy.scrollTo(Self.emptyScrollToString, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(.init(white: 0.95, alpha: 1)))
                .safeAreaInset(edge: .bottom) {
                    chatBottomBar
                        .background(Color(.systemBackground).ignoresSafeArea())
                }
            } else {
                
            }
        }
    }
    private var chatBottomBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 24))
                .foregroundColor(Color(.darkGray))
            ZStack {
                DescriptionPlaceholder()
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(4)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
struct MessageView: View {
    let message: ChatMessage
    var body: some View {
        VStack {
            if message.fromID == FirebaseManager.shared.auth.currentUser?.uid {
                HStack {
                    Spacer()
                    HStack {
                        Text(message.text)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            } else {
                HStack {
                    HStack {
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top,8)
    }
}
private struct DescriptionPlaceholder: View {
    var body: some View {
        HStack {
            Text("Enter your message")
                .foregroundColor(Color(.gray))
                .font(.system(size: 17))
                .padding(.leading, 5)
                .padding(.top, -4)
        Spacer()
        }
    }
}
struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatLogView(vm: ChatLogViewModel(chatUser: nil))
        }
    }
}
