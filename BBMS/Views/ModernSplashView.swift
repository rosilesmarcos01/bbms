import SwiftUI

struct CubeWireframeView: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let cubeSize: CGFloat = size * 0.6
            
            ZStack {
                // Front face
                Path { path in
                    let frontRect = CGRect(
                        x: center.x - cubeSize/2,
                        y: center.y - cubeSize/2,
                        width: cubeSize,
                        height: cubeSize
                    )
                    path.addRect(frontRect)
                }
                .stroke(Color("BBMSGold").opacity(0.8), lineWidth: 2)
                
                // Back face (offset for 3D effect)
                Path { path in
                    let offset: CGFloat = cubeSize * 0.2
                    let backRect = CGRect(
                        x: center.x - cubeSize/2 + offset,
                        y: center.y - cubeSize/2 - offset,
                        width: cubeSize,
                        height: cubeSize
                    )
                    path.addRect(backRect)
                }
                .stroke(Color("BBMSGold").opacity(0.4), lineWidth: 1.5)
                
                // Connecting lines for 3D effect
                Path { path in
                    let offset: CGFloat = cubeSize * 0.2
                    
                    // Top-left to top-left
                    path.move(to: CGPoint(x: center.x - cubeSize/2, y: center.y - cubeSize/2))
                    path.addLine(to: CGPoint(x: center.x - cubeSize/2 + offset, y: center.y - cubeSize/2 - offset))
                    
                    // Top-right to top-right
                    path.move(to: CGPoint(x: center.x + cubeSize/2, y: center.y - cubeSize/2))
                    path.addLine(to: CGPoint(x: center.x + cubeSize/2 + offset, y: center.y - cubeSize/2 - offset))
                    
                    // Bottom-left to bottom-left
                    path.move(to: CGPoint(x: center.x - cubeSize/2, y: center.y + cubeSize/2))
                    path.addLine(to: CGPoint(x: center.x - cubeSize/2 + offset, y: center.y + cubeSize/2 - offset))
                    
                    // Bottom-right to bottom-right
                    path.move(to: CGPoint(x: center.x + cubeSize/2, y: center.y + cubeSize/2))
                    path.addLine(to: CGPoint(x: center.x + cubeSize/2 + offset, y: center.y + cubeSize/2 - offset))
                }
                .stroke(Color("BBMSGold").opacity(0.6), lineWidth: 1.5)
            }
            .rotationEffect(.degrees(rotationAngle))
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
        }
    }
}

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
                    // Outer cube animation (blockchain reference)
                    CubeWireframeView()
                        .frame(width: 140, height: 140)
                        .scaleEffect(logoScale * 1.2)
                        .opacity(logoOpacity * 0.5)
                    
                    // Main logo
                    Image("BMSLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.primary)
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
                        .foregroundColor(.primary)
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
