
import Cocoa
import MetalKit

struct GradientRectangle {
    enum Style: UInt {
        case linear
        case radial
        case angular
    }
    var bounds = CGRect.zero
    var startColor: float4
    var endColor: float4
    var style = Style.linear
}

class GradientViewController: DetailViewController {

    override class var title: String {
        get {
            return "Gradients"
        }
    }

    let instanceCapacity = 64
    var rectangles: [GradientRectangle] = []

    private var renderPipelineState: MTLRenderPipelineState!

    private var vertexDescriptor = MTLVertexDescriptor()
    private var vertexBuffer: MTLBuffer!
    private var instanceBuffer: MTLBuffer!    

    override func makePipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not create default Metal library; is there a .metal file in the target?")
        }
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_gradient_rect")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_gradient_rect")
        
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        vertexDescriptor.attributes[0].format = .float2 // position
        vertexDescriptor.attributes[0].bufferIndex = BindIndex.vertices
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[1].format = .float2 // uv coords
        vertexDescriptor.attributes[1].bufferIndex = BindIndex.vertices
        vertexDescriptor.attributes[1].offset = 8
        vertexDescriptor.layouts[BindIndex.vertices].stride = 16
        vertexDescriptor.layouts[BindIndex.vertices].stepFunction = .perVertex

        vertexDescriptor.attributes[2].format = .float2 // center
        vertexDescriptor.attributes[2].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[2].offset = 0
        vertexDescriptor.attributes[3].format = .float2 // half-extent
        vertexDescriptor.attributes[3].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[3].offset = 8
        vertexDescriptor.attributes[4].format = .float4 // start color
        vertexDescriptor.attributes[4].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[4].offset = 16
        vertexDescriptor.attributes[5].format = .float4 // end color
        vertexDescriptor.attributes[5].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[5].offset = 32
        vertexDescriptor.attributes[6].format = .uint // gradient style
        vertexDescriptor.attributes[6].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[6].offset = 48
        vertexDescriptor.layouts[BindIndex.instances].stride = 64
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
        vertexBuffer = device.makeBuffer(length: vertexStride * 4, options: [.storageModeShared])

        let instanceStride = vertexDescriptor.layouts[BindIndex.instances].stride
        instanceBuffer = device.makeBuffer(length: instanceStride * instanceCapacity, options: [.storageModeShared])
        
        let vertexData = vertexBuffer.contents()
        write(data: float2(-1.0, -1.0), to: vertexData, at: vertexStride * 0 + vertexDescriptor.attributes[0].offset)
        write(data: float2(-1.0,  1.0), to: vertexData, at: vertexStride * 1 + vertexDescriptor.attributes[0].offset)
        write(data: float2( 1.0, -1.0), to: vertexData, at: vertexStride * 2 + vertexDescriptor.attributes[0].offset)
        write(data: float2( 1.0,  1.0), to: vertexData, at: vertexStride * 3 + vertexDescriptor.attributes[0].offset)
        write(data: float2(0.0, 0.0), to: vertexData, at: vertexStride * 0 + vertexDescriptor.attributes[1].offset)
        write(data: float2(0.0, 1.0), to: vertexData, at: vertexStride * 1 + vertexDescriptor.attributes[1].offset)
        write(data: float2(1.0, 0.0), to: vertexData, at: vertexStride * 2 + vertexDescriptor.attributes[1].offset)
        write(data: float2(1.0, 1.0), to: vertexData, at: vertexStride * 3 + vertexDescriptor.attributes[1].offset)
    }
    
    override func addSampleData() {
        let x = 50
        let y = 50
        let dy = 250
        let width = 900
        let height = 200
        rectangles.append(GradientRectangle(bounds: CGRect(x: x, y: y, width: width, height: height),
                                            startColor: float4(51 / 255.0, 13 / 255.0, 105 / 255.0, 255 / 255.0),
                                            endColor: float4(48 / 255.0, 201 / 255.0, 205 / 255.0, 255 / 255.0),
                                            style: .linear))

        rectangles.append(GradientRectangle(bounds: CGRect(x: x, y: y + dy, width: width, height: height),
                                            startColor: float4(18 / 255.0, 214 / 255.0, 223 / 255.0, 255 / 255.0),
                                            endColor: float4(247 / 255.0, 15 / 255.0, 255 / 255.0, 255 / 255.0),
                                            style: .radial))

        rectangles.append(GradientRectangle(bounds: CGRect(x: x, y: y + 2 * dy, width: width, height: height),
                                            startColor: float4(215 / 255.0, 10 / 255.0, 132 / 255.0, 255 / 255.0),
                                            endColor: float4(81 / 255.0, 18 / 255.0, 127 / 255.0, 255 / 255.0),
                                            style: .angular))

        rectangles.append(GradientRectangle(bounds: CGRect(x: x, y: y + 3 * dy, width: width, height: height),
                                            startColor: float4(250 / 255.0, 204 / 255.0, 34 / 255.0, 255 / 255.0),
                                            endColor: float4(248 / 255.0, 54 / 255.0, 0 / 255.0, 255 / 255.0),
                                            style: .linear))
    }
    
    private func copyDataToBuffers() {

        let instanceStride = vertexDescriptor.layouts[BindIndex.instances].stride

        for (index, rect) in rectangles.enumerated() {
            let center = float2(Float(rect.bounds.midX), Float(rect.bounds.midY))
            let halfExtent = float2(Float(rect.bounds.width * 0.5), Float(rect.bounds.height * 0.5))

            let instanceData = instanceBuffer.contents()
            let instanceOffset = instanceStride * index
            write(data: center,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[2].offset)
            write(data: halfExtent,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[3].offset)
            write(data: rect.startColor,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[4].offset)
            write(data: rect.endColor,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[5].offset)
            write(data: rect.style.rawValue,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[6].offset)
        }
    }

    override func draw(in renderCommandEncoder: MTLRenderCommandEncoder) {
        if rectangles.isEmpty { return }

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
