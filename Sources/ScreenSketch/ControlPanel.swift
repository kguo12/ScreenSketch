import AppKit
import SwiftUI

struct ControlPanel: View {
    @ObservedObject var model: AnnotationModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Tool", selection: $model.tool) { ForEach(AnnotationTool.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented)
                .onChange(of: model.tool) { _ in model.updateOverlayInputMode() }
            if model.tool == .eraser {
                HStack {
                    Text("Eraser")
                    Slider(value: $model.eraserSize, in: 8...100)
                    Text("\(Int(model.eraserSize)) px")
                }
            } else if model.tool == .pencil {
                HStack {
                    ColorPicker("Color", selection: $model.color)
                    Slider(value: $model.width, in: 1...30)
                    Text("\(Int(model.width)) px")
                }
                HStack {
                    Text("Transparency")
                    Slider(value: $model.pencilTransparency, in: 0...0.9)
                    Text("\(Int(model.pencilTransparency * 100))%")
                        .frame(width: 42, alignment: .trailing)
                }
            }
            HStack { Button(model.isOverlayVisible ? "Hide Drawings" : "Show Drawings") { model.toggleOverlay() }; Button("Undo") { model.undo() }; Button("Clear") { model.clear() } }
            Text(helpText).font(.caption).foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                Text("⇧⌘D  Open / Close ScreenSketch")
                Text("⇧⌘F  Clear all drawings")
                Text("⇧⌘Space  Undo last drawing")
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 430)
        .background(ControlWindowLevelSetter(model: model).frame(width: 0, height: 0))
        .onAppear { model.showOverlay() }
    }

    private var helpText: String {
        switch model.tool {
        case .pointer: return "Use your mouse as normal."
        case .pencil: return "Drag and draw on any connected display."
        case .eraser: return "Drag over drawing to erase it."
        case .select: return "Draw a loop to select, then drag the highlighted region to move it."
        }
    }
}

private struct ControlWindowLevelSetter: NSViewRepresentable {
    let model: AnnotationModel

    func makeNSView(context: Context) -> ControlWindowLevelView {
        ControlWindowLevelView(model: model)
    }

    func updateNSView(_ nsView: ControlWindowLevelView, context: Context) {}
}

private final class ControlWindowLevelView: NSView {
    private weak var model: AnnotationModel?

    init(model: AnnotationModel) {
        self.model = model
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            window.level = .statusBar
            var behavior = window.collectionBehavior
            behavior.insert(.canJoinAllSpaces)
            behavior.insert(.fullScreenAuxiliary)
            window.collectionBehavior = behavior
            self?.model?.registerControlWindow(window)
            if let closeButton = window.standardWindowButton(.closeButton) {
                closeButton.target = self
                closeButton.action = #selector(ControlWindowLevelView.hideFromCloseButton)
            }
        }
    }

    @objc private func hideFromCloseButton() {
        model?.hideApplication()
    }
}
