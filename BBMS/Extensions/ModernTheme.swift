import SwiftUI

// MARK: - Modern Theme Extensions
extension Color {
    // Adaptive background colors that respect dark mode
    static let modernBackground = Color(.systemBackground)
    static let modernCard = Color(.secondarySystemBackground)
    static let modernSecondary = Color(.tertiarySystemBackground)
    static let modernText = Color(.label)
    static let modernSubtext = Color(.secondaryLabel)
    
    // Additional vibrant colors
    static let modernPrimary = Color("BBMSGold")
    static let modernAccent = Color("BBMSBlue")
    static let modernSuccess = Color("BBMSGreen")
    static let modernWarning = Color.orange
    static let modernError = Color("BBMSRed")
    
    // Enhanced contrast colors that adapt to dark mode
    static let modernDarkCard = Color(.tertiarySystemBackground)
    static let modernLightCard = Color(.secondarySystemBackground)
    
    // Gradient colors for more vibrancy
    static let modernGradientStart = Color("BBMSGold")
    static let modernGradientEnd = Color("BBMSGold").opacity(0.6)
    static let modernBlueGradientStart = Color("BBMSBlue")
    static let modernBlueGradientEnd = Color("BBMSBlue").opacity(0.6)
    
    // Adaptive colors for better dark mode support
    static var adaptiveWhite: Color {
        Color("BBMSWhite")
    }
    
    static var adaptiveBlack: Color {
        Color("BBMSBlack")
    }
    
    // Enhanced separator color
    static let modernSeparator = Color(.separator)
}

// MARK: - Modern Card Modifier
struct ModernCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 10) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.modernCard)
                    .shadow(color: Color(.label).opacity(0.1), radius: shadowRadius, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color("BBMSGold").opacity(0.2), lineWidth: 1.0)
            )
    }
}

// MARK: - Glassmorphism Effect
struct GlassmorphismStyle: ViewModifier {
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color("BBMSGold").opacity(0.1))
                    .background(.regularMaterial)
                    .shadow(color: Color(.label).opacity(0.1), radius: 20, x: 0, y: 10)
            )
    }
}

// MARK: - Vibrant Gradient Style
struct VibrantGradientStyle: ViewModifier {
    let cornerRadius: CGFloat
    let colors: [Color]
    
    init(cornerRadius: CGFloat = 16, colors: [Color] = [.modernGradientStart, .modernGradientEnd]) {
        self.cornerRadius = cornerRadius
        self.colors = colors
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: colors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: colors.first?.opacity(0.3) ?? .clear, radius: 15, x: 0, y: 8)
            )
    }
}

// MARK: - Modern Button Style
struct ModernButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    
    init(
        backgroundColor: Color = Color("BBMSGold"),
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = 12
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Vibrant Button Style
struct VibrantButtonStyle: ButtonStyle {
    let gradient: [Color]
    let foregroundColor: Color
    let cornerRadius: CGFloat
    
    init(
        gradient: [Color] = [Color("BBMSGold"), Color("BBMSGold").opacity(0.8)],
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = 12
    ) {
        self.gradient = gradient
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
                    .shadow(color: gradient.first?.opacity(0.4) ?? .clear, radius: 8, x: 0, y: 4)
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func modernCard(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 10) -> some View {
        modifier(ModernCardStyle(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    
    func glassmorphism(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassmorphismStyle(cornerRadius: cornerRadius))
    }
    
    func modernButton(
        backgroundColor: Color = Color("BBMSGold"),
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = 12
    ) -> some View {
        buttonStyle(ModernButtonStyle(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            cornerRadius: cornerRadius
        ))
    }
    
    func vibrantGradient(
        cornerRadius: CGFloat = 16,
        colors: [Color] = [.modernGradientStart, .modernGradientEnd]
    ) -> some View {
        modifier(VibrantGradientStyle(cornerRadius: cornerRadius, colors: colors))
    }
    
    func vibrantButton(
        gradient: [Color] = [Color("BBMSGold"), Color("BBMSGold").opacity(0.8)],
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = 12
    ) -> some View {
        buttonStyle(VibrantButtonStyle(
            gradient: gradient,
            foregroundColor: foregroundColor,
            cornerRadius: cornerRadius
        ))
    }
}

// MARK: - Typography
extension Font {
    static let modernTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let modernHeadline = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let modernSubheadline = Font.system(size: 18, weight: .medium, design: .rounded)
    static let modernBody = Font.system(size: 16, weight: .regular, design: .default)
    static let modernCaption = Font.system(size: 14, weight: .medium, design: .default)
}

// MARK: - Animation Presets
extension Animation {
    static let modernSpring = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let modernEase = Animation.easeInOut(duration: 0.3)
}