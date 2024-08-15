import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
struct LoginView: View {
    let didCompleteLoginProcess: () -> ()
    @State private var isLoginMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var shouldShowImagePicker = false
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Picker(selection: $isLoginMode, label: Text("Select Image")) {
                        Text("Login")
                            .tag(true)
                        Text("Sign Up")
                            .tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    if !isLoginMode {
                        Button {
                            shouldShowImagePicker.toggle()
                        } label: {
                            VStack {
                                if let image = self.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 128, height: 128)
                                        .cornerRadius(64)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 64))
                                        .padding()
                                        .foregroundColor(Color(.label))
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 64)
                                .stroke(Color.black, lineWidth: 3)
                            )
                        }
                    }
                    Group {
                        TextField("Enter your email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("Enter password", text: $password)
                    }
                    .padding(12)
                    .background(Color.white)
                    Button {
                        handleAction()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isLoginMode ? "Login" : "Sign Up")
                                .foregroundColor(Color.white)
                                .padding(.vertical, 10)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .background(Color.blue)
                    }
                    Text(self.loginStatusMessage)
                        .foregroundColor(Color.red)
                }
                .padding()
            }
            .navigationTitle(isLoginMode ? "Login" : "Sign Up")
            .background(Color(.init(white: 0, alpha: 0.05))
                .ignoresSafeArea()
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $image)
        }
    }
    @State var image: UIImage?
    private func handleAction() {
        if isLoginMode {
            loginUser()
        } else {
            createNewAccount()
        }
    }
    private func loginUser() {
        FirebaseManager.shared.auth.signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                //print("Failed to login user: ", error)
                self.loginStatusMessage = "Failed to login user"
                return
            }
            //print("Successfully logged in as user: \(result?.user.uid ?? "")")
            self.loginStatusMessage = "Successfully logged in as user"
            self.didCompleteLoginProcess()
        }
    }
    @State var loginStatusMessage = ""
    private func createNewAccount() {
        if self.image == nil {
            self.loginStatusMessage = "You must select an avatar image"
            return
        }
        FirebaseManager.shared.auth.createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                //print("Failed to create user: ", error)
                self.loginStatusMessage = "Failed to create user"
                return
            }
            //print("Successfully created user: \(result?.user.uid ?? "")")
            self.loginStatusMessage = "Successfully created user"
            self.persistImageToStorage()
        }
    }
    private func persistImageToStorage() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = self.image?.jpegData(compressionQuality: 0.5) else { return }
        ref.putData(imageData, metadata: nil) { metaData, error in
            if let error = error {
                self.loginStatusMessage = "Failed to push image to Storage"
                return
            }
            ref.downloadURL { url, error in
                if let error = error {
                    self.loginStatusMessage = "Failed to retrieve downloadURL"
                    return
                }
                self.loginStatusMessage = "Successfully stored image with url"
                //print(url?.absoluteString)
                guard let url = url else { return }
                self.storeUserInformation(imageProfileURL: url)
            }
        }
    }
    private func storeUserInformation(imageProfileURL: URL) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let userData = ["email": self.email, "uid": uid, "profileImageURL": imageProfileURL.absoluteString]
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).setData(userData) { error in
                if let error = error {
                    //print(error)
                    self.loginStatusMessage = "Error"
                    return
                }
                //print("Success")
                self.didCompleteLoginProcess()
            }
    }
}
#Preview {
    LoginView(didCompleteLoginProcess: {
        
    })
}
