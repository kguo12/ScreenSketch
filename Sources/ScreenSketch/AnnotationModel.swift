import AppKit
import SwiftUI

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pointer = "Pointer", pencil = "Pencil", eraser = "Eraser", select = "Select"
    var id: String { rawValue }
}

struct Stroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var width: CGFloat
    var opacity: CGFloat
    var displayID: CGDirectDisplayID

    init(points: [CGPoint], color: Color, width: CGFloat, opacity: CGFloat = 1, displayID: CGDirectDisplayID) {
        self.points = points
        self.color = color
        self.width = width
        self.opacity = opacity
        self.displayID = displayID
    }
}

final class AnnotationModel: ObservableObject {
    @Published var tool: AnnotationTool = .pencil
    @Published var color: Color = .red
    @Published var width: CGFloat = 5
    @Published var pencilTransparency: CGFloat = 0
    @Published var eraserSize: CGFloat = 28
    @Published var isOverlayVisible = true
    @Published var strokes: [Stroke] = []
    @Published private(set) var selectedStrokeIDs: Set<UUID> = []
    @Published private(set) var canPaste = false

    private var overlays: [CGDirectDisplayID: NSPanel] = [:]
    private var actionPanel: NSPanel?
    private weak var controlWindow: NSWindow?
    private var globalHotKey: GlobalHotKey?
    private var screenObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var clipboardStrokes: [Stroke] = []
    private var pasteLocation: CGPoint?
    private var pasteDisplayID: CGDirectDisplayID?
    private var selectedDisplayID: CGDirectDisplayID?
    private var isApplicationPresented = true
    private var isTerminating = false

    var hasSelection: Bool { !selectedStrokeIDs.isEmpty }
    var hasClipboard: Bool { !clipboardStrokes.isEmpty }

    init() {
        globalHotKey = GlobalHotKey()
        globalHotKey?.onToggle = { [weak self] in self?.toggleApplicationVisibility() }
        globalHotKey?.onClear = { [weak self] in self?.clear() }
        globalHotKey?.onUndo = { [weak self] in self?.undo() }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isApplicationPresented, self.isOverlayVisible else { return }
                self.showOverlay()
            }
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.prepareForTermination()
        }
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
    }

    func registerControlWindow(_ window: NSWindow) {
        controlWindow = window
    }

    func toggleApplicationVisibility() {
        if isApplicationPresented, controlWindow?.isMiniaturized != true {
            hideApplication()
        } else {
            showApplication()
        }
    }

    func hideApplication() {
        isApplicationPresented = false
        controlWindow?.orderOut(nil)
        overlays.values.forEach { $0.orderOut(nil) }
        dismissActionPopup()
    }

    private func showApplication() {
        guard let controlWindow else { return }
        isApplicationPresented = true
        NSApp.activate(ignoringOtherApps: true)
        if controlWindow.isMiniaturized { controlWindow.deminiaturize(nil) }
        controlWindow.makeKeyAndOrderFront(nil)
        if isOverlayVisible { showOverlay() }
    }

    func toggleOverlay() {
        isOverlayVisible.toggle()
        if isOverlayVisible {
            showOverlay()
        } else {
            overlays.values.forEach { $0.orderOut(nil) }
            dismissActionPopup()
        }
    }

    func showOverlay() {
        guard !isTerminating, isApplicationPresented, isOverlayVisible else { return }
        let screensByID = Dictionary(
            uniqueKeysWithValues: NSScreen.screens.map { (Self.displayID(for: $0), $0) }
        )

        for staleID in Set(overlays.keys).subtracting(screensByID.keys) {
            overlays[staleID]?.close()
            overlays[staleID] = nil
        }

        for (displayID, screen) in screensByID {
            if let panel = overlays[displayID] {
                panel.setFrame(screen.frame, display: true)
                panel.ignoresMouseEvents = tool == .pointer
                panel.contentView?.needsDisplay = true
                panel.orderFrontRegardless()
                continue
            }

            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovable = false
            panel.isMovableByWindowBackground = false
            panel.acceptsMouseMovedEvents = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.ignoresMouseEvents = tool == .pointer
            panel.contentView = DrawingView(model: self, displayID: displayID)
            overlays[displayID] = panel
            panel.orderFrontRegardless()
        }
    }

    func updateOverlayInputMode() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.tool != .pointer, !self.isOverlayVisible {
                self.isOverlayVisible = true
                self.showOverlay()
            }
            self.overlays.values.forEach { $0.ignoresMouseEvents = self.tool == .pointer }
            if self.tool != .select { self.dismissActionPopup() }
        }
    }

    func selectStrokes(inside polygon: [CGPoint], on displayID: CGDirectDisplayID) {
        guard polygon.count >= 3 else { return }
        selectedStrokeIDs = Set(strokes.compactMap { stroke in
            guard stroke.displayID == displayID else { return nil }
            return stroke.points.contains(where: { Self.point($0, isInside: polygon) }) ? stroke.id : nil
        })
        selectedDisplayID = selectedStrokeIDs.isEmpty ? nil : displayID
        canPaste = false
        pasteLocation = nil
        pasteDisplayID = nil
        redrawOverlays()
        showSelectionActionPopup()
    }

    func copySelection() {
        clipboardStrokes = strokes.filter { selectedStrokeIDs.contains($0.id) }
        canPaste = false
        pasteLocation = nil
        pasteDisplayID = nil
        dismissActionPopup()
    }

    func cutSelection() {
        copySelection()
        strokes.removeAll { selectedStrokeIDs.contains($0.id) }
        selectedStrokeIDs.removeAll()
        selectedDisplayID = nil
        dismissActionPopup()
        redrawOverlays()
    }

    func deleteSelection() {
        strokes.removeAll { selectedStrokeIDs.contains($0.id) }
        selectedStrokeIDs.removeAll()
        selectedDisplayID = nil
        canPaste = false
        pasteLocation = nil
        pasteDisplayID = nil
        dismissActionPopup()
        redrawOverlays()
    }

    func armPaste(at location: CGPoint, on displayID: CGDirectDisplayID) {
        selectedStrokeIDs.removeAll()
        selectedDisplayID = nil
        pasteLocation = clipboardStrokes.isEmpty ? nil : location
        pasteDisplayID = clipboardStrokes.isEmpty ? nil : displayID
        canPaste = pasteLocation != nil
        redrawOverlays()
        if canPaste { showPasteActionPopup(at: location, on: displayID) }
    }

    func paste() {
        guard canPaste, let pasteLocation, let pasteDisplayID, !clipboardStrokes.isEmpty else { return }
        let allPoints = clipboardStrokes.flatMap(\.points)
        guard let minX = allPoints.map(\.x).min(),
              let maxX = allPoints.map(\.x).max(),
              let minY = allPoints.map(\.y).min(),
              let maxY = allPoints.map(\.y).max() else { return }

        let sourceCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let offset = CGPoint(x: pasteLocation.x - sourceCenter.x, y: pasteLocation.y - sourceCenter.y)
        let pasted = clipboardStrokes.map { stroke in
            Stroke(
                points: stroke.points.map { CGPoint(x: $0.x + offset.x, y: $0.y + offset.y) },
                color: stroke.color,
                width: stroke.width,
                opacity: stroke.opacity,
                displayID: pasteDisplayID
            )
        }
        strokes.append(contentsOf: pasted)
        selectedStrokeIDs = Set(pasted.map(\.id))
        selectedDisplayID = pasteDisplayID
        self.pasteLocation = nil
        self.pasteDisplayID = nil
        canPaste = false
        redrawOverlays()
        showSelectionActionPopup()
    }

    func selectionContains(_ point: CGPoint, on displayID: CGDirectDisplayID) -> Bool {
        guard selectedDisplayID == displayID, let bounds = selectedBounds() else { return false }
        return bounds.insetBy(dx: -12, dy: -12).contains(point)
    }

    func moveSelection(by delta: CGPoint) {
        guard delta != .zero else { return }
        for index in strokes.indices where selectedStrokeIDs.contains(strokes[index].id) {
            strokes[index].points = strokes[index].points.map {
                CGPoint(x: $0.x + delta.x, y: $0.y + delta.y)
            }
        }
        redrawOverlays()
    }

    func showSelectionActionPopup() {
        guard let displayID = selectedDisplayID, let bounds = selectedBounds() else {
            dismissActionPopup()
            return
        }
        showActionPopup(mode: .selection, at: CGPoint(x: bounds.midX, y: bounds.maxY + 10), on: displayID)
    }

    func dismissActionPopup() {
        actionPanel?.orderOut(nil)
        actionPanel?.close()
        actionPanel = nil
    }

    func erase(at location: CGPoint, on displayID: CGDirectDisplayID) {
        let radius = eraserSize / 2
        var surviving: [Stroke] = []

        for stroke in strokes {
            guard stroke.displayID == displayID else {
                surviving.append(stroke)
                continue
            }

            var run: [CGPoint] = []
            for point in stroke.points {
                if hypot(point.x - location.x, point.y - location.y) <= radius {
                    if run.count > 1 {
                        surviving.append(Stroke(points: run, color: stroke.color, width: stroke.width, opacity: stroke.opacity, displayID: displayID))
                    }
                    run.removeAll(keepingCapacity: true)
                } else {
                    run.append(point)
                }
            }
            if run.count > 1 {
                surviving.append(Stroke(points: run, color: stroke.color, width: stroke.width, opacity: stroke.opacity, displayID: displayID))
            }
        }

        strokes = surviving
        selectedStrokeIDs.removeAll()
        selectedDisplayID = nil
        dismissActionPopup()
        redrawOverlays()
    }

    func clear() {
        strokes.removeAll()
        selectedStrokeIDs.removeAll()
        selectedDisplayID = nil
        canPaste = false
        pasteLocation = nil
        pasteDisplayID = nil
        dismissActionPopup()
        redrawOverlays()
    }

    func undo() {
        _ = strokes.popLast()
        selectedStrokeIDs.removeAll()
        selectedDisplayID = nil
        dismissActionPopup()
        redrawOverlays()
    }

    private func selectedBounds() -> CGRect? {
        let points = strokes.filter { selectedStrokeIDs.contains($0.id) }.flatMap(\.points)
        guard let minX = points.map(\.x).min(),
              let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(),
              let maxY = points.map(\.y).max() else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func showPasteActionPopup(at location: CGPoint, on displayID: CGDirectDisplayID) {
        showActionPopup(mode: .paste, at: CGPoint(x: location.x, y: location.y + 10), on: displayID)
    }

    private func showActionPopup(mode: ActionPopupMode, at localPoint: CGPoint, on displayID: CGDirectDisplayID) {
        guard isOverlayVisible, let overlay = overlays[displayID] else { return }
        dismissActionPopup()

        let size = mode == .selection ? CGSize(width: 232, height: 44) : CGSize(width: 82, height: 44)
        let rootView = SelectionActionPopup(
            mode: mode,
            onCopy: { [weak self] in self?.copySelection() },
            onCut: { [weak self] in self?.cutSelection() },
            onDelete: { [weak self] in self?.deleteSelection() },
            onPaste: { [weak self] in self?.paste() }
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: size)

        let screenFrame = overlay.screen?.visibleFrame ?? overlay.frame
        var origin = CGPoint(x: overlay.frame.minX + localPoint.x - size.width / 2, y: overlay.frame.minY + localPoint.y)
        origin.x = min(max(origin.x, screenFrame.minX + 6), screenFrame.maxX - size.width - 6)
        origin.y = min(max(origin.y, screenFrame.minY + 6), screenFrame.maxY - size.height - 6)

        let panel = NSPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView
        actionPanel = panel
        panel.orderFrontRegardless()
    }

    private func redrawOverlays() {
        overlays.values.forEach { $0.contentView?.needsDisplay = true }
    }

    private func prepareForTermination() {
        isTerminating = true
        isApplicationPresented = false
        actionPanel?.orderOut(nil)
        overlays.values.forEach { $0.orderOut(nil) }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }

    private static func point(_ point: CGPoint, isInside polygon: [CGPoint]) -> Bool {
        var inside = false
        var previous = polygon.count - 1
        for current in polygon.indices {
            let a = polygon[current]
            let b = polygon[previous]
            let crosses = (a.y > point.y) != (b.y > point.y)
            if crosses {
                let crossingX = (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
                if point.x < crossingX { inside.toggle() }
            }
            previous = current
        }
        return inside
    }
}
