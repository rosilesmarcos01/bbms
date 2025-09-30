import SwiftUI

// MARK: - Modern Theme Extensions
extension Color {
    static let modernBackground = Color(.systemBackground)
    static let modernCard = Color(.systemBackground)
    static let modernSecondary = Color(.systemGray6)
    static let modernText = Color(.label)
    static let modernSubtext = Color(.secondaryLabel)
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
                    .shadow(color: .black.opacity(0.05), radius: shadowRadius, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(.systemGray5), lineWidth: 0.5)
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
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
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