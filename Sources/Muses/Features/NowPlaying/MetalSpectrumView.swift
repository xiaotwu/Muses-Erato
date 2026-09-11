import SwiftUI
import Metal
import MetalKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Metal hardware-accelerated spectrum visualization.
#if canImport(UIKit)
public struct MetalSpectrumView: UIViewRepresentable {
    @Environment(PlaybackService.self) private var playback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        let renderer = SpectrumRenderer()
        mtkView.device = renderer.device
        mtkView.delegate = renderer
        mtkView.preferredFramesPerSecond = 30
        mtkView.framebufferOnly = true
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = reduceMotion || !playback.state.isPlaying
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear

        playback.installSpectrumHandler { frame in
            renderer.updateBands(frame.bands)
        }

        context.coordinator.renderer = renderer
        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        let shouldPause = reduceMotion || !playback.state.isPlaying
        guard uiView.isPaused != shouldPause else { return }
        uiView.isPaused = shouldPause
        if shouldPause { uiView.setNeedsDisplay() }
    }

    public static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        coordinator.renderer?.cleanup()
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        var renderer: SpectrumRenderer?
    }
}
#else
public struct MetalSpectrumView: NSViewRepresentable {
    @Environment(PlaybackService.self) private var playback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        let renderer = SpectrumRenderer()
        mtkView.device = renderer.device
        mtkView.delegate = renderer
        mtkView.preferredFramesPerSecond = 30
        mtkView.framebufferOnly = true
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = reduceMotion || !playback.state.isPlaying
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.wantsLayer = true
        mtkView.layer?.isOpaque = false

        playback.installSpectrumHandler { frame in
            renderer.updateBands(frame.bands)
        }

        context.coordinator.renderer = renderer
        return mtkView
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        let shouldPause = reduceMotion || !playback.state.isPlaying
        guard nsView.isPaused != shouldPause else { return }
        nsView.isPaused = shouldPause
        if shouldPause { nsView.setNeedsDisplay(nsView.bounds) }
    }

    public static func dismantleNSView(_ nsView: MTKView, coordinator: Coordinator) {
        coordinator.renderer?.cleanup()
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        var renderer: SpectrumRenderer?
    }
}
#endif

/// MTKView delegate: manages the Metal device, pipeline, uniform buffer, and per-frame rendering.
final class SpectrumRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let pipelineState: MTLRenderPipelineState?
    private var uniformBuffer: MTLBuffer?

    private let bufferLock = NSLock()
    private var rawBands: [Float] = Array(repeating: 0, count: 64)
    private var peaks: [Float] = Array(repeating: 0, count: 64)
    private var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    private let peakDecayPerSecond: Float = 1.0 / 0.2
    private let bandCount = 64

    private let uniformSize = (64 + 8) * MemoryLayout<Float>.size

    override init() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        pipelineState = Self.makePipelineState(device: device)
        uniformBuffer = device?.makeBuffer(length: uniformSize, options: [])
        super.init()
    }

    private static func makePipelineState(device: MTLDevice?) -> MTLRenderPipelineState? {
        guard let device else { return nil }
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct Uniforms {
            float bands[64];
            float width;
            float height;
            float barWidth;
            float gap;
            float midY;
            float pad1;
            float pad2;
        };

        struct VSOut {
            float4 position [[position]];
            float4 color;
        };

        vertex VSOut spectrum_vertex(uint vid [[vertex_id]], constant Uniforms& u [[buffer(0)]]) {
            uint quadIdx = vid / 6u;
            uint corner  = vid % 6u;
            bool isLower = quadIdx >= 64u;
            uint bar = quadIdx % 64u;

            float v = u.bands[bar];
            float barH = v * u.midY;

            float unit = u.width / 65.0;
            float barWidth = unit * 0.8;
            float gap = unit * 0.2;
            float x0 = unit + float(bar) * (barWidth + gap);

            float2 corners[6];
            corners[0] = float2(0.0, 0.0);
            corners[1] = float2(barWidth, 0.0);
            corners[2] = float2(0.0, barH);
            corners[3] = float2(barWidth, 0.0);
            corners[4] = float2(barWidth, barH);
            corners[5] = float2(0.0, barH);
            float2 c = corners[corner];

            float px = x0 + c.x;
            float py = isLower ? (u.midY + c.y) : (u.midY - c.y);

            float ndcX = (px / u.width) * 2.0 - 1.0;
            float ndcY = -((py / u.height) * 2.0 - 1.0);

            VSOut out;
            out.position = float4(ndcX, ndcY, 0.0, 1.0);

            if (isLower) {
                out.color = float4(1.0, 1.0, 1.0, 0.3);
            } else {
                float t = barH > 0.001 ? (c.y / barH) : 0.0;
                float v = 1.0 - t * 0.3;
                out.color = float4(v, v, v, 1.0);
            }
            return out;
        }

        fragment float4 spectrum_fragment(VSOut in [[stage_in]]) {
            return in.color;
        }
        """
        guard let library = try? device.makeLibrary(source: source, options: nil) else { return nil }
        let vertexFn = library.makeFunction(name: "spectrum_vertex")
        let fragmentFn = library.makeFunction(name: "spectrum_fragment")

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFn
        desc.fragmentFunction = fragmentFn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].rgbBlendOperation = .add
        desc.colorAttachments[0].alphaBlendOperation = .add
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: desc)
    }

    func updateBands(_ bands: [Float]) {
        guard bands.count == bandCount else { return }
        bufferLock.lock()
        rawBands = bands
        bufferLock.unlock()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let desc = view.currentRenderPassDescriptor,
              let buffer = uniformBuffer,
              let cmd = commandQueue?.makeCommandBuffer(),
              let encoder = cmd.makeRenderCommandEncoder(descriptor: desc),
              let pipeline = pipelineState
        else { return }

        let now = CACurrentMediaTime()
        let dt = Float(max(0, min(1.0 / 10.0, now - lastFrameTime)))
        let decay = peakDecayPerSecond * dt

        bufferLock.lock()
        let bands = rawBands
        bufferLock.unlock()

        for i in 0..<bandCount {
            peaks[i] = max(bands[i], peaks[i] - decay)
        }
        lastFrameTime = now

        let size = view.drawableSize
        let unit = Float(size.width) / 65.0
        var uniforms = [Float](repeating: 0, count: 64 + 8)
        for i in 0..<bandCount { uniforms[i] = peaks[i] }
        uniforms[64] = Float(size.width)
        uniforms[65] = Float(size.height)
        uniforms[66] = unit * 0.8
        uniforms[67] = unit * 0.2
        uniforms[68] = Float(size.height) / 2.0
        memcpy(buffer.contents(), uniforms, uniformSize)

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 768)
        encoder.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    func cleanup() {
        uniformBuffer = nil
    }
}
