import SwiftUI

@main
struct ScreenSketchApp: App {
    @StateObject private var model = AnnotationModel()

    var body: some Scene {
        WindowGroup("ScreenSketch") { ControlPanel(model: model) }
            .windowResizability(.contentSize)
    }
}
