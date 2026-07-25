import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("群組與菇") {
                    GroupListView()
                }
                NavigationLink("第 0 階段驗證") {
                    VerificationView()
                }
            }
            .navigationTitle("打菇茜")
        }
    }
}
