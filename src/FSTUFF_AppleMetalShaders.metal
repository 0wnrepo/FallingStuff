//
//  FSTUFF_AppleMetalShaders.metal
//  FallingStuff
//
//  Created by David Ludwig on 4/30/16.
//  Copyright (c) 2018 David Ludwig. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "FSTUFF_AppleMetalStructs.h"

struct FSTUFF_Vertex
{
    float4 position [[position]];
    float4 color;
};

vertex FSTUFF_Vertex FSTUFF_VertexShader(constant float4 * position [[buffer(0)]],
                                         constant FSTUFF_GPUGlobals * gpuGlobals [[buffer(1)]],
                                         constant FSTUFF_ShapeGPUInfo * gpuShapes [[buffer(2)]],
                                         constant float * alpha [[buffer(3)]],
                                         uint vertexId [[vertex_id]],
                                         uint shapeId [[instance_id]])
{
    FSTUFF_Vertex vert;
    vert.position = (gpuGlobals->projection_matrix * gpuShapes[shapeId].model_matrix) * position[vertexId];
    vert.color = {
        gpuShapes[shapeId].color[0],
        gpuShapes[shapeId].color[1],
        gpuShapes[shapeId].color[2],
        gpuShapes[shapeId].color[3] * (*alpha),
    };
    return vert;
}

fragment float4 FSTUFF_FragmentShader(FSTUFF_Vertex vert [[stage_in]])
{
    return vert.color;
}


// Include header shared between this Metal shader code and C code executing Metal API commands
#import "AAPLShaderTypes.h"

// Vertex shader outputs and per-fragment inputs. Includes clip-space position and vertex outputs
//  interpolated by rasterizer and fed to each fragment generated by clip-space primitives.
typedef struct
{
    // The [[position]] attribute qualifier of this member indicates this value is the clip space
    //   position of the vertex wen this structure is returned from the vertex shader
    float4 clipSpacePosition [[position]];

    // Since this member does not have a special attribute qualifier, the rasterizer will
    //   interpolate its value with values of other vertices making up the triangle and
    //   pass that interpolated value to the fragment shader for each fragment in that triangle;
    float2 textureCoordinate;

} RasterizerData;

// Vertex Function
vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
             constant AAPLVertex *vertexArray [[ buffer(AAPLVertexInputIndexVertices) ]]
             )

{

    RasterizerData out;

    float4 pos2 = {
        vertexArray[vertexID].position.x,
        vertexArray[vertexID].position.y,
        0.0,
        1.0
    };

//    out.clipSpacePosition = (*projection_matrix) * vertexArray[vertexID].position;
//    out.clipSpacePosition = (*projection_matrix) * pos2;
    out.clipSpacePosition = pos2;

    // Pass our input textureCoordinate straight to our output RasterizerData. This value will be
    //   interpolated with the other textureCoordinate values in the vertices that make up the
    //   triangle.
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    
    return out;
}

//fragment float4 FSTUFF_FragmentShader(FSTUFF_Vertex vert [[stage_in]])
//{
//    return vert.color;
//}


// Fragment function
fragment float4
samplingShader(RasterizerData in [[stage_in]],
               texture2d<half> colorTexture [[ texture(AAPLTextureIndexBaseColor) ]],
               texture2d<half> overlayTexture [[ texture(AAPLTextureIndexOverlayColor) ]]
               )
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 mainSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    const half4 overlaySample = overlayTexture.sample(textureSampler, in.textureCoordinate);

    half4 destSample = {
        mainSample[0] ,      // R
        mainSample[1] ,      // G
        mainSample[2] ,      // B
        1,                  // A?
    };
    
    const half4 srcSample = overlaySample;
    const half srcAlpha = srcSample[3];
//    const half srcAlpha = (srcSample[3] > 0) ? 1 : 0;
//    const half srcAlpha = metal::min(srcSample[3] * half(1.5), half(1));

    destSample[0] = srcAlpha * srcSample[0] + (1 - srcAlpha) * destSample[0];
    destSample[1] = srcAlpha * srcSample[1] + (1 - srcAlpha) * destSample[1];
    destSample[2] = srcAlpha * srcSample[2] + (1 - srcAlpha) * destSample[2];

    // We return the color of the texture
    return float4(destSample);
}


struct Vertex {
    float4 position [[position]];
    float4 color;
};

vertex Vertex vertex_shader(constant Vertex *vertices [[buffer(0)]], uint vid [[vertex_id]]) {
    // extract corresponding vertex by given index
    return vertices[vid];
}

fragment float4 fragment_shader(Vertex vert [[stage_in]]) {
    return vert.color;
}

