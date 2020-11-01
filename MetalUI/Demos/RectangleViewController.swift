
import Cocoa
import MetalKit

struct Rectangle {
    var bounds = CGRect.zero
    var color: NSColor
    var cornerRadius: Float = 0
}

class RectangleViewController: DetailViewController {

    override class var title: String {
        get {
            return "Rectangles"
        }
    }
    
    let instanceCapacity = 64
    var rectangles: [Rectangle] = []
    
    private var renderPipelineState: MTLRenderPipelineState!

    private var vertexDescriptor = MTLVertexDescriptor()
    private var vertexBuffer: MTLBuffer!
    private var instanceBuffer: MTLBuffer!

    private var colorGenerator = ColorGenerator()

    override func makePipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not create default Metal library; is there a .metal file in the target?")
        }
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_colored_rect")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_colored_rect")
        
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        vertexDescriptor.attributes[0].format = .float2 // position
        vertexDescriptor.attributes[0].bufferIndex = BindIndex.vertices
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.layouts[BindIndex.vertices].stride = 8
        vertexDescriptor.layouts[BindIndex.vertices].stepFunction = .perVertex

        vertexDescriptor.attributes[1].format = .float2 // center
        vertexDescriptor.attributes[1].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[2].format = .float2 // half-extent
        vertexDescriptor.attributes[2].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[2].offset = 8
        vertexDescriptor.attributes[3].format = .float4 // color
        vertexDescriptor.attributes[3].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[3].offset = 16
        vertexDescriptor.attributes[4].format = .float4 // corner radius
        vertexDescriptor.attributes[4].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[4].offset = 32
        vertexDescriptor.layouts[BindIndex.instances].stride = 48
        vertexDescriptor.layouts[BindIndex.instances].stepFunction = .perInstance
        
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Unable to create render pipeline state: \(error). Terminating...")
        }
    }
    
    override func makeResources() {
        let vertexStride = vertexDescriptor.layouts[BindIndex.vertices].stride
        vertexBuffer = device.makeBuffer(length: vertexStride * 4,
                                         options: [.storageModeShared])

        let instanceStride = vertexDescriptor.layouts[BindIndex.instances].stride
        instanceBuffer = device.makeBuffer(length: instanceStride * instanceCapacity,
                                           options: [.storageModeShared])
        
        let vertexData = vertexBuffer.contents()
        // upper left
        write(data: float2(-1.0, -1.0), to: vertexData, at: vertexStride * 0)
        // lower left
        write(data: float2(-1.0, 1.0), to: vertexData, at: vertexStride * 1)
        // upper right
        write(data: float2(1.0, -1.0), to: vertexData, at: vertexStride * 2)
        // lower right
        write(data: float2(1.0, 1.0), to: vertexData, at: vertexStride * 3)
    }

    override func addSampleData() {
        for _ in 0..<10 {
            rectangles.append(Rectangle(bounds: CGRect(x: CGFloat.random(in: 0...600),
                                                       y: CGFloat.random(in: 0...800),
                                                       width: CGFloat.random(in: 100...400),
                                                       height: CGFloat.random(in: 100...400)),
                                        color: colorGenerator.next(),
                                        cornerRadius: Float.random(in: 10...50)))
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        var rect = Rectangle(color: colorGenerator.next())
        var mouseLocation = view.convertToBacking(view.convert(event.locationInWindow, from: nil))
        mouseLocation.y = mtkView.drawableSize.height - mouseLocation.y
        rect.bounds.origin = mouseLocation
        rect.cornerRadius = Float.random(in: 10...50)
        rectangles.append(rect)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if rectangles.count == 0 { return }
        
        let rectIndex = rectangles.count - 1
        var mouseLocation = view.convertToBacking(view.convert(event.locationInWindow, from: nil))
        mouseLocation.y = mtkView.drawableSize.height - mouseLocation.y
        var rect = rectangles[rectIndex]
        rect.bounds.size = CGSize(width: mouseLocation.x - rect.bounds.origin.x,
                                  height: mouseLocation.y - rect.bounds.origin.y)
        rectangles[rectIndex] = rect
        
        mtkView.needsDisplay = true
    }
    
    private func copyDataToBuffers() {
        let instanceData = instanceBuffer.contents()
        let instanceStride = vertexDescriptor.layouts[BindIndex.instances].stride

        for (index, rect) in rectangles.enumerated() {
            let center = float2(Float(rect.bounds.midX), Float(rect.bounds.midY))
            let halfExtent = float2(Float(rect.bounds.width * 0.5), Float(rect.bounds.height * 0.5))

            var r: CGFloat = 1.0, g: CGFloat = 1.0, b: CGFloat = 1.0, a: CGFloat = 1.0
            rect.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let color = float4(Float(r), Float(g), Float(b), Float(a))

            let instanceOffset = instanceStride * index
            write(data: center,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[1].offset)
            write(data: halfExtent,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[2].offset)
            write(data: color,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[3].offset)
            write(data: rect.cornerRadius,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[4].offset)
        }
    }

    override func draw(in renderCommandEncoder: MTLRenderCommandEncoder) {
        if rectangles.count == 0 { return }

        copyDataToBuffers()

        renderCommandEncoder.setRenderPipelineState(renderPipelineState)

        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: BindIndex.vertices)

        renderCommandEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: BindIndex.instances)
        
        var projectionMatrix = float4x4.orthographicProjection(left: 0.0,
                                                               top: 0.0,
                                                               right: Float(mtkView.drawableSize.width),
                                                               bottom: Float(mtkView.drawableSize.height),
                                                               near: -1.0,
                                                               far: 1.0)
        renderCommandEncoder.setVertexBytes(&projectionMatrix,
                                            length: MemoryLayout.size(ofValue: projectionMatrix),
                                            index: BindIndex.constants)

        renderCommandEncoder.drawPrimitives(type: .triangleStrip,
                                            vertexStart: 0,
                                            vertexCount: 4,
                                            instanceCount: rectangles.count)
    }
}
