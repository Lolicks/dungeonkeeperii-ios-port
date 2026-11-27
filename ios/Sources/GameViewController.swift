import UIKit
import MetalKit

/// Native iOS scene. Shows a Metal-rendered dungeon floor using a real
/// converted Dungeon Keeper II texture from the app bundle, plus a marker
/// cube. Touch pan/zoom gestures move the camera.
///
/// STATUS: rendering prototype, NOT the full Dungeon Keeper II game.
final class GameViewController: UIViewController {
    // MTKView.delegate is weak, so keep the renderer alive explicitly.
    private var renderer: Renderer?

    override func loadView() {
        view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let metalView = view as? MTKView, let device = metalView.device else {
            fatalError("Metal is not available on this device")
        }
        let renderer = Renderer(device: device)
        metalView.delegate = renderer
        self.renderer = renderer
        metalView.clearColor = MTLClearColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1)
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.preferredFramesPerSecond = 60
        metalView.isMultipleTouchEnabled = true

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        metalView.addGestureRecognizer(pan)
        metalView.addGestureRecognizer(pinch)

        let hud = UILabel(frame: CGRect(x: 12, y: 28, width: 420, height: 44))
        hud.numberOfLines = 2
        hud.textColor = .white
        hud.font = .systemFont(ofSize: 12, weight: .medium)
        hud.text = "DUNGEON KEEPER II — iOS PORT / RENDER PROTOTYPE\nOriginal DK2 texture + Metal scene · drag to pan, pinch to zoom"
        view.addSubview(hud)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let delta = gesture.translation(in: view)
        renderer?.pan.x += Float(delta.x) / 240
        renderer?.pan.y -= Float(delta.y) / 240
        gesture.setTranslation(.zero, in: view)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        renderer?.zoom = max(Float(0.35), min(Float(3.0), renderer?.zoom ?? 1) * Float(gesture.scale))
        gesture.scale = 1
    }

    override var prefersStatusBarHidden: Bool { true }
}

private struct Uniforms {
    var time: Float = 0
    var aspect: Float = 1
    var panX: Float = 0
    var panY: Float = 0
    var zoom: Float = 1
}

private final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer
    private let floorPipeline: MTLRenderPipelineState?
    private let floorVertexBuffer: MTLBuffer
    private let floorTexture: MTLTexture?
    private let samplerState: MTLSamplerState?
    private let startDate = Date()

    var pan: SIMD2<Float> = .zero
    var zoom: Float = 1

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

        // Cube vertices, position + RGBA + padding (float4/float4 attributes).
        let raw = Cube.vertices
        var padded: [Float] = []
        padded.reserveCapacity(36 * 8)
        for i in stride(from: 0, to: raw.count, by: 7) {
            padded += [raw[i], raw[i + 1], raw[i + 2], 0,
                       raw[i + 3], raw[i + 4], raw[i + 5], raw[i + 6]]
        }
        guard let buffer = device.makeBuffer(bytes: padded,
                                             length: padded.count * MemoryLayout<Float>.stride,
                                             options: []) else {
            fatalError("Cannot create vertex buffer")
        }
        vertexBuffer = buffer

        // Textured dungeon floor made from a real converted DK2 texture.
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0]?.format = .float4
        vertexDescriptor.attributes[0]?.offset = 0
        vertexDescriptor.attributes[0]?.bufferIndex = 0
        vertexDescriptor.attributes[1]?.format = .float2
        vertexDescriptor.attributes[1]?.offset = 16
        vertexDescriptor.attributes[1]?.bufferIndex = 0
        vertexDescriptor.layouts[0].stride = 24

        let floorDescriptor = MTLRenderPipelineDescriptor()
        floorDescriptor.vertexFunction = library.makeFunction(name: "textured_vertex")
        floorDescriptor.fragmentFunction = library.makeFunction(name: "textured_fragment")
        floorDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        floorDescriptor.vertexDescriptor = vertexDescriptor
        floorPipeline = try? device.makeRenderPipelineState(descriptor: floorDescriptor)

        // Two triangles: a floor plane tiled 4x4 with the original texture.
        let floor: [Float] = [
            -3, -3, 0,  0, 0,
             3, -3, 0,  4, 0,
             3,  3, 0,  4, 4,
            -3, -3, 0,  0, 0,
             3,  3, 0,  4, 4,
            -3,  3, 0,  0, 4,
        ]
        guard let floorBuffer = device.makeBuffer(
            bytes: floor, length: floor.count * MemoryLayout<Float>.stride, options: []) else {
            fatalError("Cannot create floor vertex buffer")
        }
        floorVertexBuffer = floorBuffer

        floorTexture = try? ResourceLoader(device: device).texture("3dFe_floor1.png")
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.04, green: 0.06, blue: 0.10, alpha: 1)
        var uniforms = Uniforms(
            time: Float(Date().timeIntervalSince(startDate)),
            aspect: Float(view.bounds.width / max(view.bounds.height, 1)),
            panX: pan.x, panY: pan.y, zoom: zoom)

        if let pipeline = floorPipeline, let texture = floorTexture, let sampler = samplerState {
            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBuffer(floorVertexBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setFragmentSamplerState(sampler, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
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
