import SwiftUI

struct ParticlesBackgroundView: View {
    @State private var blocks: [Block] = []
    let blockCount = 30
    
    struct Block: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var speed: Double
        var color: Color
        var rotation: Double
        var isConnected: Bool
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                ZStack {
                    // Draw connection lines between nearby blocks
                    ForEach(blocks.indices, id: \.self) { index in
                        let block = blocks[index]
                        let time = timeline.date.timeIntervalSince1970
                        let animatedY = block.y - CGFloat(time * block.speed * 25).truncatingRemainder(dividingBy: geometry.size.height + 100)
                        
                        if block.isConnected {
                            ForEach(blocks.indices, id: \.self) { otherIndex in
                                if index != otherIndex {
                                    let otherBlock = blocks[otherIndex]
                                    let otherAnimatedY = otherBlock.y - CGFloat(time * otherBlock.speed * 25).truncatingRemainder(dividingBy: geometry.size.height + 100)
                                    let distance = sqrt(pow(block.x - otherBlock.x, 2) + pow(animatedY - otherAnimatedY, 2))
                                    
                                    if distance < 80 {
                                        Path { path in
                                            path.move(to: CGPoint(x: block.x, y: animatedY))
                                            path.addLine(to: CGPoint(x: otherBlock.x, y: otherAnimatedY))
                                        }
                                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Draw the blocks
                    ForEach(blocks.indices, id: \.self) { index in
                        let block = blocks[index]
                        let time = timeline.date.timeIntervalSince1970
                        let animatedY = block.y - CGFloat(time * block.speed * 25).truncatingRemainder(dividingBy: geometry.size.height + 100)
                        
                        ZStack {
                            // Outer border for blockchain effect
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(block.color.opacity(block.opacity * 0.8), lineWidth: 1.5)
                                .frame(width: block.size + 2, height: block.size + 2)
                            
                            // Inner filled block
                            RoundedRectangle(cornerRadius: 2)
                                .fill(block.color.opacity(block.opacity * 0.6))
                                .frame(width: block.size, height: block.size)
                            
                            // Hash-like pattern inside
                            VStack(spacing: 1) {
                                ForEach(0..<3) { _ in
                                    HStack(spacing: 1) {
                                        ForEach(0..<3) { _ in
                                            Rectangle()
                                                .fill(block.color.opacity(block.opacity * 0.3))
                                                .frame(width: 1, height: 1)
                                        }
                                    }
                                }
                            }
                        }
                        .rotationEffect(.degrees(block.rotation + time * 60))
                        .position(x: block.x, y: animatedY)
                    }
                }
                .onAppear {
                    initializeBlocks(in: geometry.size)
                }
            }
        }
    }
    
    private func initializeBlocks(in size: CGSize) {
        blocks = (0..<blockCount).map { _ in
            Block(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...(size.height + 100)),
                size: CGFloat.random(in: 8...12),
                opacity: Double.random(in: 0.4...0.9),
                speed: Double.random(in: 0.8...2.5),
                color: [Color.primary, Color.secondary, Color.gray].randomElement() ?? Color.primary,
                rotation: Double.random(in: 0...360),
                isConnected: Bool.random()
            )
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
            // Particles Background
            ParticlesBackgroundView()
                .ignoresSafeArea()
            
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
