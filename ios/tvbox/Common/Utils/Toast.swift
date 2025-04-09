import SwiftUI

struct Toast: ViewModifier {
    let message: String
    @Binding var isShowing: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    HStack {
                        Text(message)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                    }
                    .padding(.top, 44)
                    Spacer()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShowing)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func toast(message: String, isShowing: Binding<Bool>) -> some View {
        self.modifier(Toast(message: message, isShowing: isShowing))
    }
} 