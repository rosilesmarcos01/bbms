import SwiftUI

struct RubidexDocumentsView: View {
    @ObservedObject private var rubidexService = RubidexService.shared
    @State private var showingAllDocuments = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "cube.box")
                            .foregroundColor(Color("BBMSGold"))
                            .font(.title2)
                        
                        Text("Rubidex Blockchain Data")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("BBMSBlack"))
                        
                        Spacer()
                        
                        Button(action: {
                            rubidexService.refreshData()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Color("BBMSBlue"))
                                .font(.title3)
                        }
                        .disabled(rubidexService.isLoading)
                        
                        // Add API test button for debugging
                        Button(action: {
                            Task {
                                let result = await rubidexService.testAPIConnection()
                                print("API Test Result: \(result)")
                            }
                        }) {
                            Image(systemName: "network")
                                .foregroundColor(Color("BBMSGold"))
                                .font(.title3)
                        }
                        .disabled(rubidexService.isLoading)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.seal")
                            .foregroundColor(Color("BBMSGreen"))
                            .font(.caption)
                        
                        Text("Blockchain Verified")
                            .font(.caption)
                            .foregroundColor(Color("BBMSGreen"))
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color("BBMSWhite"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                if rubidexService.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                        Text("Loading blockchain data...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = rubidexService.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.title)
                        Text("Error loading data")
                            .font(.headline)
                            .foregroundColor(Color("BBMSBlack"))
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            rubidexService.refreshData()
                        }
                        .padding()
                        .background(Color("BBMSBlue"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Latest Document Card
                            if let latestDocument = rubidexService.latestDocument {
                                VStack(spacing: 16) {
                                    HStack {
                                        Text("Latest Document")
                                            .font(.headline)
                                            .foregroundColor(Color("BBMSBlack"))
                                        
                                        Spacer()
                                        
                                        Text("LATEST")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color("BBMSGreen"))
                                            .cornerRadius(4)
                                    }
                                    
                                    Divider()
                                        .background(Color("BBMSGold"))
                                    
                                    DocumentDetailView(document: latestDocument)
                                }
                                .padding()
                                .background(Color("BBMSWhite"))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            
                            // View Previous Documents Button
                            if rubidexService.documents.count > 1 {
                                Button(action: {
                                    showingAllDocuments = true
                                }) {
                                    HStack {
                                        Text("View Previous Documents")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("(\(rubidexService.documents.count - 1))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .foregroundColor(Color("BBMSBlue"))
                                    .padding()
                                    .background(Color("BBMSBlue").opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .background(.gray.opacity(0.05))
            .navigationTitle("Blockchain Data")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if rubidexService.documents.isEmpty {
                    rubidexService.refreshData()
                }
            }
            .sheet(isPresented: $showingAllDocuments) {
                AllDocumentsView(documents: rubidexService.documents)
            }
        }
    }
}

struct DocumentDetailView: View {
    let document: RubidexDocument
    
    var body: some View {
        VStack(spacing: 12) {
            // Main data value
            VStack(spacing: 4) {
                Text("Data Value")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(document.fields.data)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color("BBMSBlack"))
            }
            .padding()
            .background(Color("BBMSGold").opacity(0.1))
            .cornerRadius(12)
            
            // Document details
            VStack(spacing: 8) {
                DocumentRow(label: "Document ID", value: String(document.id.prefix(16)) + "...")
                DocumentRow(label: "Core ID", value: document.fields.coreid ?? "N/A")
                DocumentRow(label: "Name", value: document.fields.name ?? "N/A")
                DocumentRow(label: "Published", value: document.fields.formattedPublishedDate)
                DocumentRow(label: "TTL", value: document.fields.ttl != nil ? "\(document.fields.ttl!)s" : "N/A")
                DocumentRow(label: "Clearance", value: "\(document.clearance ?? 0)")
                DocumentRow(label: "Created", value: document.formattedCreationDate)
                DocumentRow(label: "Updated", value: document.formattedUpdateDate)
            }
        }
    }
}

struct DocumentRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color("BBMSBlue"))
                .frame(minWidth: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(Color("BBMSBlack"))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct AllDocumentsView: View {
    let documents: [RubidexDocument]
    @Environment(\.dismiss) private var dismiss
    
    var sortedDocuments: [RubidexDocument] {
        documents.sorted { first, second in
            first.creationDate > second.creationDate
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(sortedDocuments.enumerated()), id: \.element.id) { index, document in
                        VStack(spacing: 16) {
                            HStack {
                                Text("Document #\(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color("BBMSBlack"))
                                
                                Spacer()
                                
                                if index == 0 {
                                    Text("LATEST")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color("BBMSGreen"))
                                        .cornerRadius(4)
                                }
                            }
                            
                            Divider()
                                .background(Color("BBMSGold"))
                            
                            DocumentDetailView(document: document)
                        }
                        .padding()
                        .background(Color("BBMSWhite"))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                }
                .padding()
            }
            .background(.gray.opacity(0.05))
            .navigationTitle("All Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("BBMSBlue"))
                }
            }
        }
    }
}

#Preview {
    RubidexDocumentsView()
}