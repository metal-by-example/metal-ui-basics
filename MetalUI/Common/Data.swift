
import Foundation

// Copies a value into the specified buffer at the specified offset. The value must
// be of trivial type, and the computed destination address must conform to the
// alignment requirements of the type.
func write<T: Any>(data: T, to buffer: UnsafeMutableRawPointer, at byteOffset: Int) {
    let ptr = buffer.advanced(by: byteOffset).assumingMemoryBound(to: T.self)
    ptr.initialize(to: data)
}

struct BindIndex {
    static let vertices = 0
    static let instances = 8
    static let constants = 9
}
