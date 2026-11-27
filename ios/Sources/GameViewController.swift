import UIKit
import MetalKit

/// First real 3D scene on iOS: a rotating, colored cube rendered with Metal.
///
/// This is a genuine rendering milestone, NOT the finished Dungeon Keeper II
/// game. Game logic/resource porting is tracked in the control center.
final class GameViewController: UIViewController {

    override func loadView() {
        view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let metalView = view as? MTKView, let device = metalView.device else {
            fatalError("Metal is not available on this device")
        }
        metalView.delegate = Renderer(device: device)
        metalView.clearColor = MTLClearColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1)
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.preferredFramesPerSecond = 60
    }

    override var prefersStatusBarHidden: Bool { true }
}

private struct Uniforms {
    var time: Float = 0
    var aspect: Float = 1
}

private final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer
    private let startDate = Date()

    init(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { fatalError("No command queue") }
        commandQueue = queue

        guard let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "vertex_main"),
              let fragment = library.makeFunction(name: "fragment_main") else {
            fatalError("Missing Metal shader functions")
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            fatalError("Cannot create render pipeline")
        }
        pipelineState = pipeline

        // 36 vertices (12 triangles), position + RGBA color. Add a 4th
        // position component so Metal's float4 attributes align correctly.
        let raw = Cube.vertices
        var padded: [Float] = []
        padded.reserveCapacity(36 * 8)
        for i in stride(from: 0, to: raw.count, by: 7) {
            padded += [raw[i], raw[i + 1], raw[i + 2], 0,
                       raw[i + 3], raw[i + 4], raw[i + 5], raw[i + 6]]
        }
        let c = padded
        guard let buffer = device.makeBuffer(bytes: c, length: c.count * MemoryLayout<Float>.stride, options: []) else {
            fatalError("Cannot create vertex buffer")
        }
        vertexBuffer = buffer
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.04, green: 0.06, blue: 0.10, alpha: 1)
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        var uniforms = Uniforms(
            time: Float(Date().timeIntervalSince(startDate)),
            aspect: Float(view.bounds.width / max(view.bounds.height, 1)))
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 36)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

private enum Cube {
    // Each vertex: x, y, z, r, g, b, a
    static let vertices: [Float] = [
        -1, -1,  1,   0.9, 0.3, 0.2, 1,   1, -1,  1,   0.9, 0.3, 0.2, 1,   1,  1,  1,   0.9, 0.3, 0.2, 1,
        -1, -1,  1,   0.9, 0.3, 0.2, 1,   1,  1,  1,   0.9, 0.3, 0.2, 1,  -1,  1,  1,   0.9, 0.3, 0.2, 1,
         1, -1,  1,   0.2, 0.7, 0.9, 1,   1, -1, -1,   0.2, 0.7, 0.9, 1,   1,  1, -1,   0.2, 0.7, 0.9, 1,
         1, -1,  1,   0.2, 0.7, 0.9, 1,   1,  1, -1,   0.2, 0.7, 0.9, 1,   1,  1,  1,   0.2, 0.7, 0.9, 1,
         1, -1, -1,   0.9, 0.8, 0.2, 1,  -1, -1, -1,   0.9, 0.8, 0.2, 1,  -1,  1, -1,   0.9, 0.8, 0.2, 1,
         1, -1, -1,   0.9, 0.8, 0.2, 1,  -1,  1, -1,   0.9, 0.8, 0.2, 1,   1,  1, -1,   0.9, 0.8, 0.2, 1,
        -1, -1, -1,   0.3, 0.9, 0.5, 1,  -1, -1,  1,   0.3, 0.9, 0.5, 1,  -1,  1,  1,   0.3, 0.9, 0.5, 1,
        -1, -1, -1,   0.3, 0.9, 0.5, 1,  -1,  1,  1,   0.3, 0.9, 0.5, 1,  -1,  1, -1,   0.3, 0.9, 0.5, 1,
         1, -1,  1,   0.8, 0.4, 0.9, 1,   1, -1, -1,   0.8, 0.4, 0.9, 1,   1,  1, -1,   0.8, 0.4, 0.9, 1,
         1, -1,  1,   0.8, 0.4, 0.9, 1,   1,  1, -1,   0.8, 0.4, 0.9, 1,   1,  1,  1,   0.8, 0.4, 0.9, 1,
        -1,  1,  1,   0.9, 0.6, 0.3, 1,   1,  1,  1,   0.9, 0.6, 0.3, 1,   1,  1, -1,   0.9, 0.6, 0.3, 1,
        -1,  1,  1,   0.9, 0.6, 0.3, 1,   1,  1, -1,   0.9, 0.6, 0.3, 1,  -1,  1, -1,   0.9, 0.6, 0.3, 1,
        -1, -1,  1,   0.4, 0.5, 0.9, 1,   1, -1,  1,   0.4, 0.5, 0.9, 1,   1, -1, -1,   0.4, 0.5, 0.9, 1,
        -1, -1,  1,   0.4, 0.5, 0.9, 1,   1, -1, -1,   0.4, 0.5, 0.9, 1,  -1, -1, -1,   0.4, 0.5, 0.9, 1,
    ]
}
