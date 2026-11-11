import SwiftUI

enum IOS27Theme {
    static let accent = Color("AccentBrand")
    static let auroraTop = Color(red: 0.10, green: 0.42, blue: 0.78)
    static let auroraBottom = Color(red: 0.05, green: 0.18, blue: 0.34)
    static let mist = Color(red: 0.78, green: 0.88, blue: 0.96)
    static let ink = Color(red: 0.07, green: 0.12, blue: 0.18)
    static let softStroke = Color.white.opacity(0.28)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                auroraTop.opacity(0.95),
                Color(red: 0.16, green: 0.55, blue: 0.72),
                auroraBottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var meshBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.96, blue: 0.99),
                    Color(red: 0.86, green: 0.92, blue: 0.98),
                    Color(red: 0.78, green: 0.88, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(auroraTop.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -120, y: -220)

            Circle()
                .fill(Color(red: 0.20, green: 0.62, blue: 0.70).opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 140, y: 180)
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(IOS27Theme.softStroke, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
            }
    }
}

struct PrimaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(IOS27Theme.heroGradient)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct SecondaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(IOS27Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(IOS27Theme.softStroke, lineWidth: 1)
                    }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct StatusChip: View {
    let title: String
    let systemImage: String
    var tint: Color = IOS27Theme.auroraTop

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(tint)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            }
    }
}

extension View {
    func ios27ScreenBackground() -> some View {
        background { IOS27Theme.meshBackground }
    }
}
