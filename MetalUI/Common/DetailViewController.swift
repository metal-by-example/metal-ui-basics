
import AppKit
import MetalKit

class DetailViewController : NSViewController, MTKViewDelegate {
    class var title: String {
        get {
            return "Untitled"
        }
    }
    
    var device = MTLCreateSystemDefaultDevice()!
    var commandQueue: MTLCommandQueue!

    var mtkView: MTKView!

    override func loadView() {
        
        device = MTLCreateSystemDefaultDevice()!
        
        commandQueue = device.makeCommandQueue()

        mtkView = MTKView(frame: CGRect.zero, device: device)
        mtkView.delegate = self

        view = mtkView
        
        commonInit()
    }
    
    private func commonInit() {
        commandQueue = device.makeCommandQueue()

        mtkView.delegate = self
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        mtkView.clearColor = MTLClearColor.darkBackground

        makePipeline()
        makeResources()
        addSampleData()
    }

    func makePipeline() { /* override point */ }
    
    func makeResources() { /* override point */ }
    
    func addSampleData() { /* override point */ }

    func draw(in renderCommandEncoder: MTLRenderCommandEncoder) { /* override point */ }

    // MARK: MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        guard let passDescriptor = mtkView.currentRenderPassDescriptor else { return }
        
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            return
        }

        draw(in: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()

        if let drawable = mtkView.currentDrawable {
            commandBuffer.present(drawable)
        }

        commandBuffer.commit()
    }
}
