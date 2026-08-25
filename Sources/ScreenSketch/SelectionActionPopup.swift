import SwiftUI

enum ActionPopupMode: Equatable {
    case selection
    case paste
}

struct SelectionActionPopup: View {
    let mode: ActionPopupMode
    let onCopy: () -> Void
    let onCut: () -> Void
    let onDelete: () -> Void
    let onPaste: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if mode == .selection {
                Button("Copy", action: onCopy)
                Button("Cut", action: onCut)
                Button("Delete", action: onDelete)
            } else {
                Button("Paste", action: onPaste)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
