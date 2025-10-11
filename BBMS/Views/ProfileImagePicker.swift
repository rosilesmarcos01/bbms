import SwiftUI
import PhotosUI

struct ProfileImagePicker: View {
    @StateObject private var userService = UserService.shared
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Current Profile Picture
                VStack(spacing: 16) {
                    Text("Current Profile Picture")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    ZStack {
                        Circle()
                            .fill(Color("BBMSGold").opacity(0.2))
                            .frame(width: 150, height: 150)
                        
                        if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                        } else if let imageName = userService.currentUser.profileImageName {
                            // Load image from Documents directory
                            if let imageData = loadImageFromDocuments(imageName: imageName),
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                            } else {
                                // Fallback to default icon if file not found
                                Image(systemName: "person.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(Color("BBMSGold"))
                            }
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color("BBMSGold"))
                        }
                    }
                }
                
                // Photo Selection Options
                VStack(spacing: 16) {
                    // Photo Library Picker
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                            Text("Choose from Photo Library")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("BBMSGold"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Remove Photo Button
                    if userService.currentUser.profileImageName != nil || selectedImageData != nil {
                        Button(action: removePhoto) {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                Text("Remove Photo")
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Profile Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color("BBMSGold"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePhoto()
                    }
                    .foregroundColor(Color("BBMSGold"))
                    .fontWeight(.semibold)
                    .disabled(selectedImageData == nil)
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
    }
    
    private func loadImageFromDocuments(imageName: String) -> Data? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(imageName)
        
        do {
            let imageData = try Data(contentsOf: fileURL)
            return imageData
        } catch {
            print("❌ Error loading profile image: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func savePhoto() {
        guard let imageData = selectedImageData else {
            isPresented = false
            return
        }
        
        // Save image data to Documents directory
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Failed to get documents directory")
            isPresented = false
            return
        }
        
        // Generate a unique filename
        let imageName = "profile_\(UUID().uuidString).jpg"
        let fileURL = documentsDirectory.appendingPathComponent(imageName)
        
        do {
            // Save the image data to disk
            try imageData.write(to: fileURL)
            print("✅ Profile image saved to: \(fileURL.path)")
            
            // Update the user service with the filename
            userService.updateProfileImage(imageName)
            
            isPresented = false
        } catch {
            print("❌ Error saving profile image: \(error.localizedDescription)")
            isPresented = false
        }
    }
    
    private func removePhoto() {
        // Remove the file from disk if it exists
        if let imageName = userService.currentUser.profileImageName {
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent(imageName)
                try? fileManager.removeItem(at: fileURL)
                print("🗑️ Removed profile image: \(imageName)")
            }
        }
        
        selectedImageData = nil
        userService.updateProfileImage(nil)
    }
}

// MARK: - Supporting Views
struct DefaultAvatarView: View {
    let size: CGFloat
    let user: User
    
    var body: some View {
        ZStack {
            Circle()
                .fill(user.role.color.opacity(0.2))
                .frame(width: size, height: size)
            
            Text(getInitials(from: user.name))
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(user.role.color)
        }
    }
    
    private func getInitials(from name: String) -> String {
        let words = name.split(separator: " ")
        let initials = words.prefix(2).compactMap { $0.first }
        return String(initials).uppercased()
    }
}

#Preview {
    ProfileImagePicker(isPresented: .constant(true))
}