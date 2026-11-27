#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct TexturedVertexIn {
    float4 position [[attribute(0)]];
    float2 uv       [[attribute(1)]];
};

struct TexturedVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float time;
    float aspect;
    float panX;
    float panY;
    float zoom;
};

static float4x4 projectionMatrix(float aspect) {
    return float4x4(
        float4(1.0f / aspect, 0, 0, 0),
        float4(0, 1, 0, 0),
        float4(0, 0, 1, 0),
        float4(0, 0, 0, 3));
}

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(1)]]) {
    float c = cos(uniforms.time * 0.7f);
    float s = sin(uniforms.time * 0.7f);
    float4x4 rotY = float4x4(
        float4( c, 0, -s, 0),
        float4( 0, 1,  0, 0),
        float4( s, 0,  c, 0),
        float4( 0, 0,  0, 1));
    float4x4 rotX = float4x4(
        float4(1, 0, 0, 0),
        float4(0, c, s, 0),
        float4(0,-s, c, 0),
        float4(0, 0, 0, 1));

    VertexOut out;
    float4 p = rotX * rotY * float4(in.position.xyz * 0.55f, 1.0f);
    out.position = projectionMatrix(uniforms.aspect) * p;
    out.color = in.color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}

vertex TexturedVertexOut textured_vertex(TexturedVertexIn in [[stage_in]],
                                         constant Uniforms& uniforms [[buffer(1)]]) {
    TexturedVertexOut out;
    float2 moved = in.position.xy * uniforms.zoom + float2(uniforms.panX, uniforms.panY);
    out.position = projectionMatrix(uniforms.aspect) * float4(moved, in.position.z, 1.0f);
    out.uv = in.uv;
    return out;
}

fragment float4 textured_fragment(TexturedVertexOut in [[stage_in]],
                                  texture2d<float> texture [[texture(0)]],
                                  sampler samp [[sampler(0)]]) {
    return texture.sample(samp, in.uv);
}
