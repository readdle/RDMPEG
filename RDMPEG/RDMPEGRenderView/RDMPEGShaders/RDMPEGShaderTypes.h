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

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum RDMPEGVertexInputIndex {
    RDMPEGVertexInputIndexVertices,
    RDMPEGVertexInputIndexViewportSize,
} RDMPEGVertexInputIndex;

// Texture index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API texture set calls

typedef enum RDMPEGTextureIndexRGB {
    RDMPEGTextureIndexRGBBaseColor,
} RDMPEGTextureIndexRGB;

typedef enum RDMPEGTextureIndexYUV {
    RDMPEGTextureIndexY,
    RDMPEGTextureIndexU,
    RDMPEGTextureIndexV,
} RDMPEGTextureIndexYUV;

//  This structure defines the layout of each vertex in the array of vertices set as an input to the
//    Metal vertex shader.  Since this header is shared between the .metal shader and C code,
//    you can be sure that the layout of the vertex array in the code matches the layout that
//    the vertex shader expects

typedef struct {
    // Positions in pixel space. A value of 100 indicates 100 pixels from the origin/center.
    vector_float2 position;

    // 2D texture coordinate
    vector_float2 textureCoordinate;
} RDMPEGVertex;

#endif /* RDMPEGShaderTypes_h */
