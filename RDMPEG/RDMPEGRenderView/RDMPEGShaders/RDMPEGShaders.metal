//
//  RDMPEGShaders.metal
//  RDMPEG
//
//  Created by Serhii Alpieiev on 03.12.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "RDMPEGShaderTypes.h"


typedef struct
{
    // The [[position]] attribute qualifier of this member indicates this value is
    // the clip space position of the vertex when this structure is returned from
    // the vertex shader
    float4 position [[position]];

    // Since this member does not have a special attribute qualifier, the rasterizer
    // will interpolate its value with values of other vertices making up the triangle
    // and pass that interpolated value to the fragment shader for each fragment in
    // that triangle.
    float2 textureCoordinate;

} RasterizerData;

vertex RasterizerData vertexShader(uint vertexID [[ vertex_id ]],
                                   constant RDMPEGVertex *vertexArray [[ buffer(RDMPEGVertexInputIndexVertices) ]],
                                   constant vector_uint2 *viewportSizePointer  [[ buffer(RDMPEGVertexInputIndexViewportSize) ]])
{
    RasterizerData out;
    
    // Index into the array of positions to get the current vertex.
    //   Positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
    //   the origin)
    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;

    // Get the viewport size and cast to float.
    float2 viewportSize = float2(*viewportSizePointer);

    // To convert from positions in pixel space to positions in clip-space,
    //  divide the pixel coordinates by half the size of the viewport.
    // Z is set to 0.0 and w to 1.0 because this is 2D sample.
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);

    // Pass the input textureCoordinate straight to the output RasterizerData. This value will be
    //   interpolated with the other textureCoordinate values in the vertices that make up the
    //   triangle.
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;

    return out;
}

fragment float4 samplingShaderRGB(RasterizerData in [[stage_in]],
                               texture2d<half> colorTexture [[ texture(RDMPEGTextureIndexRGBBaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);

    // return the color of the texture
    return float4(colorSample);
}

fragment float4 samplingShaderYUV(RasterizerData in [[stage_in]],
                                  texture2d<half> yTexture [[ texture(RDMPEGTextureIndexY) ]],
                                  texture2d<half> uTexture [[ texture(RDMPEGTextureIndexU) ]],
                                  texture2d<half> vTexture [[ texture(RDMPEGTextureIndexV) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 ySample = yTexture.sample(textureSampler, in.textureCoordinate);
    const half4 uSample = uTexture.sample(textureSampler, in.textureCoordinate);
    const half4 vSample = vTexture.sample(textureSampler, in.textureCoordinate);
    
    float3 colorOffset = float3(0, -0.5, -0.5);
    float3x3 colorMatrix = float3x3(float3(1, 1, 1),
                                    float3(0, -0.344, 1.770),
                                    float3(1.403, -0.714, 0));
    
    float3 yuv = float3(ySample[0], uSample[0], vSample[0]);
    
    float3 rgb = colorMatrix * (yuv + colorOffset);
    
    // return the color of the texture
    return float4(rgb, 1.0);
}
