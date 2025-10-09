import SwiftUI

struct ModernLogoView: View {
    let size: CGFloat
    let style: LogoStyle
    
    enum LogoStyle {
        case icon
        case full
        case compact
    }
    
    init(size: CGFloat = 50, style: LogoStyle = .icon) {
        self.size = size
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .icon:
            iconOnly
        case .full:
            fullLogo
        case .compact:
            compactLogo
        }
    }
    
    private var iconOnly: some View {
        Image("RubitestLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .colorMultiply(Color.primary)
            .shadow(color: Color("BBMSGold").opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var fullLogo: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                iconOnly
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("BBMS")
                        .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text("Building Management")
                        .font(.system(size: size * 0.2, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Rubitest branding
            HStack(spacing: 4) {
                Image("RubitestLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: size * 0.15)
                    .colorMultiply(Color.primary)
                
                Text("by Rubitest")
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .opacity(0.7)
        }
    }
    
    private var compactLogo: some View {
        HStack(spacing: 8) {
            Image("RubitestLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .colorMultiply(Color.primary)
            
            Text("BBMS")
                .font(.system(size: size * 0.6, weight: .bold, design: .rounded))
                .foregroundColor(Color("BBMSBlack"))
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        ModernLogoView(size: 60, style: .icon)
        ModernLogoView(size: 50, style: .full)
        ModernLogoView(size: 40, style: .compact)
    }
    .padding()
}