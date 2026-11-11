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
                VStack(alignment: .leading, spacing: 22) {
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
                            Text("Подключиться")
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
            .navigationTitle("Silica")
            .navigationBarTitleDisplayMode(.large)
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
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Silica")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(IOS27Theme.ink)
                Text("Ваш Synology NAS на iPhone: файлы, загрузки и умная синхронизация Фото.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    StatusChip(title: "iOS 27.2", systemImage: "iphone")
                    StatusChip(title: "Liquid Glass", systemImage: "cube.transparent")
                    StatusChip(title: "File Station", systemImage: "externaldrive")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var modePicker: some View {
        Picker("Режим", selection: $credentials.connectionMode) {
            ForEach(NASCredentials.ConnectionMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var fields: some View {
        GlassPanel {
            VStack(spacing: 14) {
                switch credentials.connectionMode {
                case .quickConnect:
                    labeledField("QuickConnect ID", text: $credentials.quickConnectID, prompt: "your-qc-id")
                case .local, .customURL:
                    labeledField("Адрес / IP", text: $credentials.host, prompt: "192.168.1.50")
                    HStack(spacing: 12) {
                        labeledField("Порт", text: Binding(
                            get: { String(credentials.port) },
                            set: { credentials.port = Int($0) ?? credentials.port }
                        ), prompt: "5001", keyboard: .numberPad)
                        Toggle("HTTPS", isOn: $credentials.useHTTPS)
                            .tint(IOS27Theme.auroraTop)
                    }
                }

                labeledField("Логин DSM", text: $credentials.username, prompt: "admin")
                SecureField("Пароль", text: $credentials.password)
                    .textContentType(.password)
                    .padding(12)
                    .background(fieldBackground)
            }
        }
    }

    private var tips: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Label("Подсказка", systemImage: "lightbulb.fill")
                    .font(.subheadline.weight(.semibold))
                Text("Для локальной сети обычно порты 5000 (HTTP) или 5001 (HTTPS). Через интернет удобнее QuickConnect.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.04))
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
