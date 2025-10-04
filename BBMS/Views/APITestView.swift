import SwiftUI

struct APITestView: View {
    @ObservedObject private var rubidexService = RubidexService.shared
    @State private var testResult = ""
    @State private var isTestingAPI = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.largeTitle)
                        .foregroundColor(Color("BBMSBlue"))
                    
                    Text("Rubidex API Test")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text("Test the API connection and response")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color("BBMSWhite"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Test Button
                Button(action: {
                    runAPITest()
                }) {
                    HStack {
                        if isTestingAPI {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                        }
                        
                        Text(isTestingAPI ? "Testing..." : "Run API Test")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isTestingAPI ? Color.gray : Color("BBMSBlue"))
                    .cornerRadius(12)
                }
                .disabled(isTestingAPI)
                
                // Test Results
                if !testResult.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Test Results")
                                    .font(.headline)
                                    .foregroundColor(Color("BBMSBlack"))
                                
                                Spacer()
                                
                                Button("Copy") {
                                    UIPasteboard.general.string = testResult
                                }
                                .font(.caption)
                                .foregroundColor(Color("BBMSBlue"))
                            }
                            
                            Divider()
                                .background(Color("BBMSGold"))
                            
                            Text(testResult)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Color("BBMSBlack"))
                                .textSelection(.enabled)
                        }
                        .padding()
                    }
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("BBMSGold").opacity(0.3), lineWidth: 1)
                    )
                }
                
                Spacer()
            }
            .padding()
            .background(.gray.opacity(0.05))
            .navigationTitle("API Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func runAPITest() {
        isTestingAPI = true
        testResult = ""
        
        Task {
            let result = await rubidexService.testAPIConnection()
            
            await MainActor.run {
                testResult = result
                isTestingAPI = false
            }
        }
    }
}

#Preview {
    APITestView()
}