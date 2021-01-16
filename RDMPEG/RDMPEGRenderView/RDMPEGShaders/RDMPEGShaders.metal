//
//  RDMPEGShaders.metal
//  RDMPEG
//
//  Created by Serhii Alpieiev on 03.12.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "RDMPEGShaderTypes.h"

using namespace metal;


typedef struct {
    float4 position [[position]];
    float2 textureCoordinate;
} RasterizerData;


vertex RasterizerData vertexShader(uint vertexID [[ vertex_id ]],
                                   constant RDMPEGVertex *vertexArray [[ buffer(RDMPEGVertexInputIndexVertices) ]],
                                   constant vector_uint2 *viewportSizePointer  [[ buffer(RDMPEGVertexInputIndexViewportSize) ]])
{
    // Index into the array of positions to get the current vertex.
    // Positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from the origin)
    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;

    float2 viewportSize = float2(*viewportSizePointer);

    // To convert from positions in pixel space to positions in clip-space,
    // divide the pixel coordinates by half the size of the viewport.
    RasterizerData rasterizerData;
    rasterizerData.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    rasterizerData.position.xy = pixelSpacePosition / (viewportSize / 2.0);

    // Pass the input textureCoordinate straight to the output RasterizerData. This value will be
    // interpolated with the other textureCoordinate values in the vertices that make up the triangle.
    rasterizerData.textureCoordinate = vertexArray[vertexID].textureCoordinate;

    return rasterizerData;
}

fragment float4 samplingShaderBGRA(RasterizerData rasterizerData [[stage_in]],
                                   texture2d<half> colorTexture [[ texture(RDMPEGTextureIndexBGRABaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    const half4 colorSample = colorTexture.sample(textureSampler, rasterizerData.textureCoordinate);
    
    return float4(colorSample);
}

fragment float4 samplingShaderYUV(RasterizerData rasterizerData [[stage_in]],
                                  texture2d<half> yTexture [[ texture(RDMPEGTextureIndexY) ]],
                                  texture2d<half> uTexture [[ texture(RDMPEGTextureIndexU) ]],
                                  texture2d<half> vTexture [[ texture(RDMPEGTextureIndexV) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    const half4 ySample = yTexture.sample(textureSampler, rasterizerData.textureCoordinate);
    const half4 uSample = uTexture.sample(textureSampler, rasterizerData.textureCoordinate);
    const half4 vSample = vTexture.sample(textureSampler, rasterizerData.textureCoordinate);
    
    float3x3 colorMatrix = float3x3(float3(1.0, 1.0, 1.0),
                                    float3(0.0, -0.344, 1.770),
                                    float3(1.403, -0.714, 0.0));
    
    float3 yuv = float3(ySample[0], uSample[0], vSample[0]);
    
    float3 colorOffset = float3(0.0, -0.5, -0.5);
    float3 rgb = colorMatrix * (yuv + colorOffset);
    
    return float4(rgb, 1.0);
}
