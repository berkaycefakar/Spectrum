import SwiftUI
import UIKit

enum Keyboard {
    /// Ends editing in whatever field has focus. Setting a `FocusState` to false alone did not
    /// always close the keyboard inside a sheet, so callers do both.
    @MainActor static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// For a vertical (multi-line) TextField: Return closes the keyboard instead of adding a
    /// new line. Reviews are short, and without this the keyboard had no obvious way out.
    func returnDismissesKeyboard(_ text: Binding<String>, focus: FocusState<Bool>.Binding) -> some View {
        submitLabel(.done)
            .onChange(of: text.wrappedValue) { _, new in
                guard new.contains("\n") else { return }
                text.wrappedValue = new.replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                focus.wrappedValue = false
                Keyboard.dismiss()
            }
    }
}
