
#include <metal_stdlib>
using namespace metal;

enum class BindIndex {
    vertices  = 0,
    instances = 8,
    constants = 9
};

enum GradientStyle {
    linear,
    radial,
    angular
};

struct Vertex {
    float2 position    [[attribute(0)]];
    float2 uvCoords    [[attribute(1)]];
    float2 center      [[attribute(2)]];
    float2 halfExtent  [[attribute(3)]];
    float4 startColor  [[attribute(4)]];
    float4 endColor    [[attribute(5)]];
    uint gradientStyle [[attribute(6)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uvCoords;
    float4 startColor [[flat]];
    float4 endColor [[flat]];
    uint gradientStyle [[flat]];
};

vertex VertexOut vertex_gradient_rect(Vertex in [[stage_in]],
                                     constant float4x4 &projectionMatrix [[buffer(BindIndex::constants)]])
{
    float4 position = float4(in.center + in.halfExtent * in.position, 0.0f, 1.0f);

    VertexOut out;
    out.position = projectionMatrix * position;
    out.uvCoords = in.uvCoords;
    out.startColor = in.startColor;
    out.endColor = in.endColor;
    out.gradientStyle = in.gradientStyle;
    return out;
}

static float atan2m(float y, float x) {
   float at2 = atan2(y, x);
   return (at2 < 0.0) ? (at2 + (2.0 * M_PI_F)) : at2;
}

fragment float4 fragment_gradient_linear(VertexOut in [[stage_in]])
{
    return mix(in.startColor, in.endColor, in.uvCoords.x);
}

fragment float4 fragment_gradient_rect(VertexOut in [[stage_in]])
{
    switch (in.gradientStyle) {
        case linear:
            return mix(in.startColor, in.endColor, in.uvCoords.x);
        case radial: {
            float dist = length(in.uvCoords - 0.5f);
            return mix(in.startColor, in.endColor, saturate(dist));
        }
        case angular: {
            float angle = atan2m((in.uvCoords.y - 0.5f), in.uvCoords.x - 0.5f);
            return mix(in.startColor, in.endColor, angle / (2 * M_PI_F));
        }
    }
    return float4(0.0f);
}
