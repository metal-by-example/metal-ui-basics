
#include <metal_stdlib>
using namespace metal;

enum class BindIndex {
    vertices  = 0,
    instances = 8,
    constants = 9
};

struct Vertex {
    float2 position     [[attribute(0)]];
    float2 center       [[attribute(1)]];
    float2 halfExtent   [[attribute(2)]];
    float4 color        [[attribute(3)]];
    float  cornerRadius [[attribute(4)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 rectCenter;
    float2 rectHalfExtent;
    float cornerRadius [[flat]];
};

vertex VertexOut vertex_colored_rect(Vertex in [[stage_in]],
                                     constant float4x4 &projectionMatrix [[buffer(BindIndex::constants)]])
{
    float4 position = float4(in.center + in.halfExtent * in.position, 0.0f, 1.0f);

    VertexOut out;
    out.position = projectionMatrix * position;
    out.color = in.color;
    out.rectCenter = in.center;
    out.rectHalfExtent = in.halfExtent;
    out.cornerRadius = in.cornerRadius;
    return out;
}

// https://www.iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
static float sdRoundedBox(float2 p, float2 b, float r) {
    r = min(r, min(b.x, b.y));
    float2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0f) + length(max(q, 0.0f)) - r;
}

fragment float4 fragment_colored_rect(VertexOut in [[stage_in]]) {
    float dist = sdRoundedBox(in.position.xy - in.rectCenter,
                              in.rectHalfExtent,
                              in.cornerRadius);
    float rolloff = 1.0f - smoothstep(-0.5f, 0.5f, dist);
    return in.color * rolloff;
}
