//
//  RDMPEGShaderTypes.h
//  RDMPEG
//
//  Created by Serhii Alpieiev on 06.01.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#ifndef RDMPEGShaderTypes_h
#define RDMPEGShaderTypes_h


#include <simd/simd.h>

typedef enum RDMPEGVertexInputIndex {
    RDMPEGVertexInputIndexVertices,
    RDMPEGVertexInputIndexViewportSize,
} RDMPEGVertexInputIndex;


typedef enum RDMPEGTextureIndexBGRA {
    RDMPEGTextureIndexBGRABaseColor,
} RDMPEGTextureIndexBGRA;


typedef enum RDMPEGTextureIndexYUV {
    RDMPEGTextureIndexY,
    RDMPEGTextureIndexU,
    RDMPEGTextureIndexV,
} RDMPEGTextureIndexYUV;


typedef struct {
    vector_float2 position;
    vector_float2 textureCoordinate;
} RDMPEGVertex;

#endif /* RDMPEGShaderTypes_h */
