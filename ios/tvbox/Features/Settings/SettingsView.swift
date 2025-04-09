import SwiftUI

struct SettingsView: View {
    @State private var apiHost: String = AppConfig.shared.apiHost
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API设置")) {
                    TextField("API主机地址", text: $apiHost)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // 其他设置选项...
            }
            .navigationTitle("设置")
            .onDisappear {
                AppConfig.shared.apiHost = apiHost
            }
        }
    }
}

#Preview {
    SettingsView()
} 