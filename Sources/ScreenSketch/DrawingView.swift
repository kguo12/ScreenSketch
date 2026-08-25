import AppKit
import SwiftUI

final class DrawingView: NSView {
    weak var model: AnnotationModel?
    private let displayID: CGDirectDisplayID
    private var current: Stroke?
    private var lassoPoints: [CGPoint] = []
    private var lassoDidDrag = false
    private var selectionDragStart: CGPoint?
    private var lastSelectionDragPoint: CGPoint?
    private var isMovingSelection = false
    init(model: AnnotationModel, displayID: CGDirectDisplayID) {
        self.model = model
        self.displayID = displayID
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let finishedStrokes = model?.strokes.filter { $0.displayID == displayID } ?? []
        let selectedIDs = model?.selectedStrokeIDs ?? []
        for stroke in finishedStrokes {
            if selectedIDs.contains(stroke.id) { drawSelectionHighlight(for: stroke, in: ctx) }
            draw(stroke, in: ctx)
        }
        if let current { draw(current, in: ctx) }
        drawLasso(in: ctx)
    }
    private func draw(_ stroke: Stroke, in ctx: CGContext) {
        guard stroke.points.count > 1 else { return }
        ctx.setStrokeColor(NSColor(stroke.color).withAlphaComponent(stroke.opacity).cgColor); ctx.setLineWidth(stroke.width); ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.beginPath(); ctx.move(to: stroke.points[0]); for p in stroke.points.dropFirst() { ctx.addLine(to: p) }; ctx.strokePath()
    }

    private func drawSelectionHighlight(for stroke: Stroke, in ctx: CGContext) {
        guard stroke.points.count > 1 else { return }
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.65).cgColor)
        ctx.setLineWidth(stroke.width + 8)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.move(to: stroke.points[0])
        for point in stroke.points.dropFirst() { ctx.addLine(to: point) }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawLasso(in ctx: CGContext) {
        guard lassoPoints.count > 1 else { return }
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.systemBlue.cgColor)
        ctx.setLineWidth(2)
        ctx.setLineDash(phase: 0, lengths: [7, 5])
        ctx.beginPath()
        ctx.move(to: lassoPoints[0])
        for point in lassoPoints.dropFirst() { ctx.addLine(to: point) }
        if lassoDidDrag { ctx.closePath() }
        ctx.strokePath()
        ctx.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        guard let model else { return }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        switch model.tool {
        case .pencil:
            current = Stroke(points: [point], color: model.color, width: model.width, opacity: 1 - model.pencilTransparency, displayID: displayID)
        case .eraser:
            model.erase(at: point, on: displayID)
        case .select:
            model.dismissActionPopup()
            if model.selectionContains(point, on: displayID) {
                selectionDragStart = point
                lastSelectionDragPoint = point
                isMovingSelection = false
                lassoDidDrag = false
                lassoPoints.removeAll()
            } else {
                selectionDragStart = nil
                lastSelectionDragPoint = nil
                lassoPoints = [point]
                lassoDidDrag = false
            }
        case .pointer:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let model else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch model.tool {
        case .pencil:
            guard var stroke = current else { return }
            stroke.points.append(point)
            current = stroke
        case .eraser:
            model.erase(at: point, on: displayID)
        case .select:
            if let start = selectionDragStart {
                if !isMovingSelection, hypot(point.x - start.x, point.y - start.y) > 4 {
                    isMovingSelection = true
                }
                if isMovingSelection, let previous = lastSelectionDragPoint {
                    model.moveSelection(by: CGPoint(x: point.x - previous.x, y: point.y - previous.y))
                    lastSelectionDragPoint = point
                }
            } else {
                if let start = lassoPoints.first, hypot(point.x - start.x, point.y - start.y) > 4 {
                    lassoDidDrag = true
                }
                lassoPoints.append(point)
            }
        case .pointer:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let model else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch model.tool {
        case .pencil:
            if let stroke = current, stroke.points.count > 1 { model.strokes.append(stroke) }
            current = nil
        case .eraser:
            model.erase(at: point, on: displayID)
        case .select:
            if selectionDragStart != nil {
                if isMovingSelection {
                    model.showSelectionActionPopup()
                } else if model.hasClipboard {
                    model.armPaste(at: point, on: displayID)
                } else {
                    model.showSelectionActionPopup()
                }
                selectionDragStart = nil
                lastSelectionDragPoint = nil
                isMovingSelection = false
            } else if lassoDidDrag {
                lassoPoints.append(point)
                model.selectStrokes(inside: lassoPoints, on: displayID)
            } else {
                model.armPaste(at: point, on: displayID)
            }
            lassoPoints.removeAll()
            lassoDidDrag = false
        case .pointer:
            break
        }
        needsDisplay = true
    }
}
