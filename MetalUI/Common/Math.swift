
import Foundation
import simd
import Cocoa

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

class ColorGenerator {
    var hue: CGFloat = 0.0
    var step: CGFloat = 0.11
    
    func next() -> NSColor {
        let color = NSColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        hue = fmod(hue + step, 1.0)
        return color
    }
}

extension MTLClearColor {
    static var lightBackground: MTLClearColor {
        return MTLClearColor(red: 0.682, green: 0.710, blue: 0.741, alpha: 1.0)
    }
    static var darkBackground: MTLClearColor {
        return MTLClearColor(red: 0.192, green: 0.212, blue: 0.239, alpha: 1.0)
    }
}

extension float4x4 {

    static var identity: float4x4 {
        return matrix_identity_float4x4
    }

    // Create an orthographic (parallel) projection matrix that maps from an arbitrary
    // viewport to Metal clip space. Assumes originating space is right-handed.
    static func orthographicProjection(left: Float, top: Float,
                                       right: Float, bottom: Float,
                                       near: Float, far: Float) -> float4x4
    {
        let xs = 2 / (right - left)
        let ys = 2 / (top - bottom)
        let zs = -1 / (far - near)
        let tx = (left + right) / (left - right)
        let ty = (top + bottom) / (bottom - top)
        let tz = -near / (far - near)
        return float4x4([
            float4(xs,  0,  0, 0),
            float4( 0, ys,  0, 0),
            float4( 0,  0, zs, 0),
            float4(tx, ty, tz, 1)
        ])
    }
}
