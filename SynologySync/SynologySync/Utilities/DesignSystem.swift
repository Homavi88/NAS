import SwiftUI

enum IOS27Theme {
    static let accent = Color("AccentBrand")
    static let auroraTop = Color(red: 0.18, green: 0.52, blue: 0.98)
    static let auroraMid = Color(red: 0.28, green: 0.78, blue: 0.92)
    static let auroraBottom = Color(red: 0.08, green: 0.22, blue: 0.48)
    static let ink = Color(red: 0.06, green: 0.10, blue: 0.18)
    static let glassStroke = LinearGradient(
        colors: [
            Color.white.opacity(0.72),
            Color.white.opacity(0.18),
            Color.white.opacity(0.42)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [auroraTop, auroraMid, auroraBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var meshBackground: some View {
        ZStack {
            // Deep luminous canvas — Liquid Glass needs colorful light to refract.
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.86, blue: 1.00),
                    Color(red: 0.86, green: 0.93, blue: 0.99),
                    Color(red: 0.68, green: 0.82, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [auroraTop.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 28)
                .offset(x: -130, y: -260)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [auroraMid.opacity(0.45), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 200
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 26)
                .offset(x: 150, y: 220)

            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 180, height: 180)
                .blur(radius: 40)
                .offset(x: 40, y: -40)
        }
        .ignoresSafeArea()
    }
}

/// Floating Liquid Glass surface used across Silica.
struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 28
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                liquidGlassBackground(cornerRadius: cornerRadius)
            }
    }
}

struct LiquidGlassIcon: View {
    let systemName: String
    var size: CGFloat = 18
    var tint: Color = IOS27Theme.auroraTop

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background {
                Circle()
                    .fill(.clear)
                    .glassEffect(.regular.tint(tint.opacity(0.35)).interactive(), in: Circle())
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
                Capsule(style: .continuous)
                    .fill(IOS27Theme.heroGradient)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: IOS27Theme.auroraTop.opacity(0.35), radius: 16, y: 8)
                    .opacity(configuration.isPressed ? 0.86 : 1)
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
                Capsule(style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: Capsule())
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct StatusChip: View {
    let title: String
    let systemImage: String
    var tint: Color = IOS27Theme.auroraTop

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .foregroundStyle(tint)
        .background {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(tint.opacity(0.28)), in: Capsule())
        }
    }
}

struct BrandMark: View {
    var size: CGFloat = 64
    @State private var shimmer = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: size, height: size)
                .glassEffect(
                    .regular.tint(IOS27Theme.auroraTop.opacity(0.45)).interactive(),
                    in: Circle()
                )

            Image(systemName: "internaldrive.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, IOS27Theme.auroraMid)
                .symbolEffect(.pulse, options: .repeating, value: shimmer)
        }
        .onAppear { shimmer = true }
    }
}

extension View {
    func ios27ScreenBackground() -> some View {
        background { IOS27Theme.meshBackground }
    }

    @ViewBuilder
    func liquidGlassBackground(cornerRadius: CGFloat = 28) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(IOS27Theme.glassStroke, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 24, y: 12)
    }
}
