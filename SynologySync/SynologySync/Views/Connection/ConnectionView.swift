import SwiftUI
import UIKit

struct ConnectionView: View {
    @Environment(AppModel.self) private var appModel
    @State private var credentials = NASCredentials.empty
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var appear = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    modePicker
                    fields
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                    Button {
                        Task { await connect() }
                    } label: {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        } else {
                            Label("Подключиться", systemImage: "link.circle.fill")
                        }
                    }
                    .buttonStyle(PrimaryGlassButtonStyle())
                    .disabled(isConnecting || !canConnect)
                    .opacity(canConnect ? 1 : 0.55)

                    tips
                }
                .padding(20)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 18)
            }
            .ios27ScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if let saved = appModel.credentialsStore.load() {
                    credentials = saved
                    credentials.password = saved.password
                }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    appear = true
                }
            }
        }
    }

    private var canConnect: Bool {
        !credentials.username.isEmpty &&
        !credentials.password.isEmpty &&
        (credentials.connectionMode == .quickConnect
            ? !credentials.quickConnectID.isEmpty
            : !credentials.host.isEmpty)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrandMark(size: 72)

            Text("Silica")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(IOS27Theme.ink)

            Text("Synology NAS на iPhone — файлы и умная синхронизация Фото.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                StatusChip(title: "iOS 27.2", systemImage: "iphone")
                StatusChip(title: "Liquid Glass", systemImage: "rectangle.stack.fill")
                StatusChip(title: "File Station", systemImage: "externaldrive.fill.badge.wifi")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background {
            liquidGlassBackground(cornerRadius: 32)
        }
    }

    private var modePicker: some View {
        Picker("Режим", selection: $credentials.connectionMode) {
            ForEach(NASCredentials.ConnectionMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(6)
        .background {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    private var fields: some View {
        GlassPanel(cornerRadius: 30) {
            VStack(spacing: 14) {
                switch credentials.connectionMode {
                case .quickConnect:
                    labeledField(
                        "QuickConnect ID",
                        systemImage: "globe.desk.fill",
                        text: $credentials.quickConnectID,
                        prompt: "your-qc-id"
                    )
                case .local, .customURL:
                    labeledField(
                        "Адрес / IP",
                        systemImage: "network",
                        text: $credentials.host,
                        prompt: "192.168.1.50"
                    )
                    HStack(spacing: 12) {
                        labeledField(
                            "Порт",
                            systemImage: "number",
                            text: Binding(
                                get: { String(credentials.port) },
                                set: { credentials.port = Int($0) ?? credentials.port }
                            ),
                            prompt: "5001",
                            keyboard: .numberPad
                        )
                        Toggle(isOn: $credentials.useHTTPS) {
                            Label("HTTPS", systemImage: "lock.shield.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                        .tint(IOS27Theme.auroraTop)
                        .padding(.top, 18)
                    }
                }

                labeledField(
                    "Логин DSM",
                    systemImage: "person.crop.circle.fill",
                    text: $credentials.username,
                    prompt: "admin"
                )

                VStack(alignment: .leading, spacing: 6) {
                    Label("Пароль", systemImage: "key.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    SecureField("Пароль", text: $credentials.password)
                        .textContentType(.password)
                        .padding(12)
                        .background(fieldBackground)
                }
            }
        }
    }

    private var tips: some View {
        GlassPanel {
            HStack(alignment: .top, spacing: 12) {
                LiquidGlassIcon(systemName: "lightbulb.fill", tint: .orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Подсказка")
                        .font(.subheadline.weight(.semibold))
                    Text("Локально обычно порты 5000 (HTTP) или 5001 (HTTPS). Через интернет удобнее QuickConnect.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labeledField(
        _ title: String,
        systemImage: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            }
    }

    private func connect() async {
        errorMessage = nil
        isConnecting = true
        defer { isConnecting = false }

        do {
            try await appModel.connect(with: credentials)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
