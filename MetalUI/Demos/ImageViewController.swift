
import Cocoa
import MetalKit

struct TexturedRectangle {
    var bounds = CGRect.zero
    var textureBounds = CGRect.zero
    var textureIndex: Int
}

class ImageViewController: DetailViewController {

    override class var title: String {
        get {
            return "Images"
        }
    }
    
    let instanceCapacity = 64
    var rectangles: [TexturedRectangle] = []

    private var renderPipelineState: MTLRenderPipelineState!
    internal var texture: MTLTexture!

    private var vertexDescriptor = MTLVertexDescriptor()
    private var vertexBuffer: MTLBuffer!
    private var instanceBuffer: MTLBuffer!
    
    override func makePipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not create default Metal library; is there a .metal file in the target?")
        }
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_textured_rect")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_textured_rect")
        
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
        vertexDescriptor.attributes[3].format = .float2 // uv center
        vertexDescriptor.attributes[3].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[3].offset = 16
        vertexDescriptor.attributes[4].format = .float2 // uv half-extent
        vertexDescriptor.attributes[4].bufferIndex = BindIndex.instances
        vertexDescriptor.attributes[4].offset = 24
        vertexDescriptor.layouts[BindIndex.instances].stride = 32
        vertexDescriptor.layouts[BindIndex.instances].stepFunction = .perInstance
        
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Failed to create render pipeline state: \(error). Terminating...")
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
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let options: [MTKTextureLoader.Option : Any] = [
            .textureUsage : MTLTextureUsage.shaderRead.rawValue,
            .SRGB : false
        ]
        do {
            texture = try textureLoader.newTexture(name: "sunsets",
                                                   scaleFactor: 2.0,
                                                   bundle: Bundle.main,
                                                   options: options)
        } catch {
            fatalError("Could not load texture from main bundle")
        }
        
        let tileWidth: CGFloat = 280
        let tileHeight: CGFloat = 280
        let tileStride: CGFloat = tileWidth + 30
        let uStride: CGFloat = 1 / 3.0 // Three images per column
        let vStride: CGFloat = 1 / 3.0 // Three images per row
        for r in 0..<3 {
            for c in 0..<3 {
                rectangles.append(TexturedRectangle(bounds: CGRect(x: CGFloat(c) * tileStride + 50.0,
                                                                   y: CGFloat(r) * tileStride + 50.0,
                                                                   width: tileWidth,
                                                                   height: tileHeight),
                                                    textureBounds: CGRect(x: uStride * CGFloat(c),
                                                                          y: vStride * CGFloat(r),
                                                                          width: uStride,
                                                                          height: vStride),
                                                    textureIndex: 0))
            }
        }
        
    }
    
    func copyDataToBuffers() {
        let instanceData = instanceBuffer.contents()
        let instanceStride = vertexDescriptor.layouts[BindIndex.instances].stride

        for (index, rect) in rectangles.enumerated() {
            let center = float2(Float(rect.bounds.midX), Float(rect.bounds.midY))
            let halfExtent = float2(Float(rect.bounds.width * 0.5), Float(rect.bounds.height * 0.5))
            
            let uvCenter = float2(Float(rect.textureBounds.midX), Float(rect.textureBounds.midY))
            let uvHalfExtent = float2(Float(rect.textureBounds.width * 0.5), Float(rect.textureBounds.height * 0.5))

            let instanceOffset = instanceStride * index
            write(data: center,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[1].offset)
            write(data: halfExtent,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[2].offset)
            write(data: uvCenter,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[3].offset)
            write(data: uvHalfExtent,
                  to: instanceData,
                  at: instanceOffset + vertexDescriptor.attributes[4].offset)
        }
    }

    override func draw(in renderCommandEncoder: MTLRenderCommandEncoder) {
        if rectangles.isEmpty { return }

        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        
        copyDataToBuffers()
        
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
        
        renderCommandEncoder.setFragmentTexture(texture, index: 0)

        renderCommandEncoder.drawPrimitives(type: .triangleStrip,
                                            vertexStart: 0,
                                            vertexCount: 4,
                                            instanceCount: rectangles.count)
    }
}
