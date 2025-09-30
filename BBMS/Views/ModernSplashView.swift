import SwiftUI

struct ModernSplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOffset: CGFloat = 50
    @State private var textOpacity: Double = 0
    @State private var backgroundGradientOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Dynamic Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color("BBMSGold").opacity(0.1),
                    Color(.systemBackground),
                    Color("BBMSGold").opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(backgroundGradientOpacity)
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Animated Logo
                ZStack {
                    // Outer ring animation
                    Circle()
                        .stroke(Color("BBMSGold").opacity(0.3), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(logoScale * 1.2)
                        .opacity(logoOpacity * 0.5)
                    
                    // Main logo
                    ModernLogoView(size: 80, style: .icon)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }
                
                // App Title with Animation
                VStack(spacing: 8) {
                    Text("B²MS")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Color("BBMSBlack"))
                        .offset(y: textOffset)
                        .opacity(textOpacity)
                    
                    Text("Building Management System")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .offset(y: textOffset)
                        .opacity(textOpacity * 0.8)
                    
                    Text("Secure • Efficient • Connected")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color("BBMSBlack"))
                        .offset(y: textOffset)
                        .opacity(textOpacity * 0.6)
                }
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSBlack")))
                    .scaleEffect(1.2)
                    .opacity(textOpacity)
                    .padding(.top, 20)
                
                Spacer()
                
                // Rubitest branding at bottom
                VStack(spacing: 4) {
                    Text("Powered by")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(textOpacity * 0.8)
                    
                    Image("RubitestLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 24)
                        .colorMultiply(.black)
                        .opacity(textOpacity * 0.7)
                    

                }
                .padding(.bottom, 20)
            }
            .onAppear {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.6, blendDuration: 0)) {
                    logoScale = 1.0
                    logoOpacity = 1.0
                    backgroundGradientOpacity = 1.0
                }
                
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    textOffset = 0
                    textOpacity = 1.0
                }
            }
        }
    }
}

#Preview {
    ModernSplashView()
}
