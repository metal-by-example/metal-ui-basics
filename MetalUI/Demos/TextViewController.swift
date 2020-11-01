
import Cocoa

class TextViewController: ImageViewController {

    override class var title: String {
        get {
            return "Text"
        }
    }
    
    private var text: NSAttributedString!

    override func addSampleData() {
        do {
            let fileURL = Bundle.main.url(forResource: "script", withExtension: "rtf")!
            text = try NSAttributedString(url: fileURL,
                                          options: [.documentType: NSAttributedString.DocumentType.rtf],
                                          documentAttributes: nil)
        } catch {
            fatalError("Could not load text file")
        }
        
        let mutableText = NSMutableAttributedString(attributedString: text)
        
        text = mutableText
        
        let stringContext = NSStringDrawingContext()
        var stringRect = text.boundingRect(with: NSSize(width: 0, height: 0),
                                           options: [ .usesLineFragmentOrigin ],
                                           context: stringContext)
        
        stringRect = stringRect.integral
        let maxTextureDimension: CGFloat = 4096 // Minimum max texture size supported by all Metal devices
        stringRect = CGRect(origin: stringRect.origin,
                            size: CGSize(width: min(maxTextureDimension, stringRect.width),
                                         height: min(maxTextureDimension, stringRect.height)))
        
        let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let textureWidth = Int(stringRect.width * screenScale)
        let textureHeight = Int(stringRect.height * screenScale)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let bytesPerRow = textureWidth * 4
        let textureBytes = UnsafeMutableRawPointer.allocate(byteCount: bytesPerRow * textureHeight, alignment: 16)
        textureBytes.initializeMemory(as: UInt8.self, repeating: 0, count: bytesPerRow * textureHeight)
        let bitmapContext = CGContext(data: textureBytes,
                                      width: textureWidth,
                                      height: textureHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo)!
        bitmapContext.scaleBy(x: screenScale, y: screenScale)
        
        let graphicsContext = NSGraphicsContext(cgContext: bitmapContext, flipped: false)
        NSGraphicsContext.current = graphicsContext
        
        text.draw(with: stringRect, options: [ .usesLineFragmentOrigin ], context: stringContext)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                         width: textureWidth,
                                                                         height: textureHeight,
                                                                         mipmapped: false)
        textureDescriptor.usage = .shaderRead

        texture = device.makeTexture(descriptor: textureDescriptor)
        texture?.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                           size: MTLSize(width: textureWidth,
                                                         height: textureHeight,
                                                         depth: 1)),
                         mipmapLevel: 0,
                         withBytes: textureBytes,
                         bytesPerRow: bytesPerRow)
        
        rectangles.append(TexturedRectangle(bounds: CGRect(x: stringRect.origin.x + 50,
                                                           y: stringRect.origin.y + 50,
                                                           width: stringRect.size.width * screenScale,
                                                           height: stringRect.size.height * screenScale),
                                            textureBounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                            textureIndex: 0))
    }
}
