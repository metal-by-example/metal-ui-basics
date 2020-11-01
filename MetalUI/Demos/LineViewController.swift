
import Cocoa
import MetalKit

struct CurveSegment {
    var startPoint = CGPoint.zero
    var endPoint = CGPoint.zero
    var color: NSColor
    var lineWidth: Float = 10
}

class LineViewController: DetailViewController {

    override class var title: String {
        get {
            return "Lines"
        }
    }

    let instanceCapacity = 16 * 1024
    var rectangles: [CurveSegment] = []
    
    private var lastMouseLocation = CGPoint.zero
    
    private var colorGenerator = ColorGenerator()

    private var renderPipelineState: MTLRenderPipelineState!

    private var vertexDescriptor = MTLVertexDescriptor()
    private var instanceBuffer: MTLBuffer!

    override func makePipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not create default Metal library; is there a .metal file in the target?")
        }
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_line")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_line")
        
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        vertexDescriptor.attributes[0].format = .float2 // line start
        vertexDescriptor.attributes[0].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[1].format = .float2 // line end
        vertexDescriptor.attributes[1].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[1].offset = 8
        vertexDescriptor.attributes[2].format = .float4 // color
        vertexDescriptor.attributes[2].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[2].offset = 16
        vertexDescriptor.attributes[3].format = .float // line width
        vertexDescriptor.attributes[3].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[3].offset = 32
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
        let instanceStride = vertexDescriptor.layouts[BindIndex.instances].stride
        instanceBuffer = device.makeBuffer(length: instanceStride * instanceCapacity, options: [.storageModeShared])
    }
    
    override func mouseDown(with event: NSEvent) {
        if rectangles.count >= instanceCapacity { return }

        var mouseLocation = view.convertToBacking(view.convert(event.locationInWindow, from: nil))
        mouseLocation.y = mtkView.drawableSize.height - mouseLocation.y
        lastMouseLocation = mouseLocation

        let segment = CurveSegment(startPoint: lastMouseLocation,
                                   endPoint: lastMouseLocation,
                                   color: colorGenerator.next(),
                                   lineWidth: 15.0)
        rectangles.append(segment)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if rectangles.isEmpty { return }
        
        let index = rectangles.count - 1

        var mouseLocation = view.convertToBacking(view.convert(event.locationInWindow, from: nil))
        mouseLocation.y = mtkView.drawableSize.height - mouseLocation.y
        
        var segment = rectangles[index]
        segment.endPoint = mouseLocation
        rectangles[index] = segment

        lastMouseLocation = mouseLocation
        
        mtkView.needsDisplay = true
    }

    private func copyDataToBuffers() {
        let instanceData = instanceBuffer.contents()
        let instanceStride = vertexDescriptor.layouts[BindIndex.instances].stride

        for (index, rect) in rectangles.enumerated() {
            let startPoint = float2(Float(rect.startPoint.x), Float(rect.startPoint.y))
            let endPoint = float2(Float(rect.endPoint.x), Float(rect.endPoint.y))
            
            var r: CGFloat = 1.0, g: CGFloat = 1.0, b: CGFloat = 1.0, a: CGFloat = 1.0
            rect.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let color = float4(Float(r), Float(g), Float(b), Float(a))

            let instanceOffset = instanceStride * index
            write(data: startPoint,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[0].offset)
            write(data: endPoint,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[1].offset)
            write(data: color,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[2].offset)
            write(data: rect.lineWidth,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[3].offset)
        }
    }

    override func draw(in renderCommandEncoder: MTLRenderCommandEncoder) {
        if rectangles.isEmpty { return }

        copyDataToBuffers()

        renderCommandEncoder.setRenderPipelineState(renderPipelineState)

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
