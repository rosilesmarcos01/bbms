import SwiftUI

struct LoadingTransitionView: View {
    @State private var isAnimating = false
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color("BBMSBlue").opacity(0.3),
                    Color("BBMSWhite").opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Logo with subtle animation
                ModernLogoView(size: 200)
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // Loading text
                VStack(spacing: 12) {
                    Text("Welcome to BBMS!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Getting things ready...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .opacity(opacity)
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                    .scaleEffect(1.2)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1.0
            }
            withAnimation {
                isAnimating = true
            }
        }
    }
}

#Preview {
    LoadingTransitionView()
}
