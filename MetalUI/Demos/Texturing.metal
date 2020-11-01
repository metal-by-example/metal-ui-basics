
#include <metal_stdlib>
using namespace metal;

enum class BindIndex {
    vertices = 0,
    instances = 8,
    constants = 9
};

struct Vertex {
    float2 position     [[attribute(0)]];
    float2 center       [[attribute(1)]];
    float2 halfExtent   [[attribute(2)]];
    float2 uvCenter     [[attribute(3)]];
    float2 uvHalfExtent [[attribute(4)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uvCoords;
};

vertex VertexOut vertex_textured_rect(Vertex in [[stage_in]],
                                      constant float4x4 &projectionMatrix [[buffer(BindIndex::constants)]])
{
    float4 position = float4(in.center + in.halfExtent * in.position, 0.0f, 1.0f);
    float2 uv = in.uvCenter + in.uvHalfExtent * in.position;

    VertexOut out;
    out.position = projectionMatrix * position;
    out.uvCoords = uv;
    return out;
}

fragment float4 fragment_textured_rect(VertexOut in [[stage_in]],
                                       texture2d<float, access::sample> tex2d [[texture(0)]])
{
    constexpr sampler linearSampler(coord::normalized,
                                    address::clamp_to_edge,
                                    filter::linear);
    return tex2d.sample(linearSampler, in.uvCoords);
}
