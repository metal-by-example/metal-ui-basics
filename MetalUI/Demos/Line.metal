
#include <metal_stdlib>
using namespace metal;

enum class BindIndex {
    vertices = 0,
    instances = 8,
    constants = 9
};

struct Vertex {
    float2 lineStartPoint [[attribute(0)]];
    float2 lineEndPoint   [[attribute(1)]];
    float4 color          [[attribute(2)]];
    float lineWidth       [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 startPoint [[flat]];
    float2 endPoint   [[flat]];
    float lineWidth   [[flat]];
};

vertex VertexOut vertex_line(Vertex in [[stage_in]],
                             constant float4x4 &projectionMatrix [[buffer(BindIndex::constants)]],
                             uint vid [[vertex_id]])
{
    float2 direction = normalize(in.lineEndPoint - in.lineStartPoint);
    float2 normal = float2(-direction.y, direction.x);
    
    float2 position;
    float dist = 0.0f;
    switch (vid) {
        case 0: position = in.lineStartPoint; dist =  1.0f; break;
        case 1: position = in.lineStartPoint; dist = -1.0f; break;
        case 2: position = in.lineEndPoint;   dist =  1.0f; break;
        case 3: position = in.lineEndPoint;   dist = -1.0f; break;
    }
    position += dist * in.lineWidth * normal;
    
    VertexOut out;
    out.position = projectionMatrix * float4(position, 0.0f, 1.0f);
    out.color = in.color;
    out.startPoint = in.lineStartPoint;
    out.endPoint = in.lineEndPoint;
    out.lineWidth = in.lineWidth;
    return out;
}

// https://www.iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
static float sdOrientedBox(float2 p, float2 a, float2 b, float th) {
    float l = length(b - a);
    float2 d = (b - a) / l;
    float2 q = (p - (a + b) * 0.5f);
    q = float2x2(d.x, -d.y, d.y, d.x) * q;
    q = abs(q) - float2(l, th) * 0.5f;
    return length(max(q, 0.0f)) + min(max(q.x, q.y), 0.0f);
}

fragment float4 fragment_line(VertexOut in [[stage_in]],
                              texture2d<float, access::sample> tex2d [[texture(0)]])
{
    float dist = sdOrientedBox(in.position.xy, in.startPoint, in.endPoint, in.lineWidth);
    float rolloff = 1.0f - smoothstep(-0.5f, 0.5f, dist);
    return in.color * rolloff;
}
