
#ifndef FSTUFF_AppleMetal_h
#define FSTUFF_AppleMetal_h

#include "FSTUFF.h"
#if FSTUFF_USE_METAL

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#include <simd/simd.h>
#include "FSTUFF_Apple.h"
#include "FSTUFF_AppleMetalStructs.h"

// The max number of command buffers in flight
static const NSUInteger FSTUFF_MaxInflightBuffers = 3;

// Max API memory buffer size.
static const size_t FSTUFF_MaxBytesPerFrame = 1024 * 1024; //64; //sizeof(vector_float4) * 3; //*1024;

struct FSTUFF_AppleMetalRenderer : public FSTUFF_Renderer<FSTUFF_AppleMetalRenderer>
{
    // controller
    dispatch_semaphore_t _inflight_semaphore;

    // renderer
    id <MTLDevice> device = nil;
    id <MTLRenderCommandEncoder> simRenderCommandEncoder = nil;
    id <MTLRenderCommandEncoder> mainRenderCommandEncoder = nil;
    MTKView * nativeView = nil;
    FSTUFF_GPUData * appData = NULL;
    id <MTLCommandQueue> commandQueue;
    id <MTLLibrary> defaultLibrary;
    id <MTLRenderPipelineState> simulationPipelineState;
    id <MTLRenderPipelineState> mainPipelineState;
    id <MTLTexture> simTexture; // texture with simulation data
    //id <MTLRenderPipelineState> overlayPipelineState;
    uint8_t constantDataBufferIndex;
    id <MTLBuffer> gpuConstants[FSTUFF_MaxInflightBuffers];
    
    id<MTLBuffer> rectVBO = nil;  // VBO for a single, full-screen (in normalized coords), rectangle
    NSUInteger rectVBOCount = 0;  // number of vertices in rectVBO

    void    DestroyVertexBuffer(void * _gpuVertexBuffer) FSTUFF_OVERRIDE;
    void *  NewVertexBuffer(void * src, size_t size) FSTUFF_OVERRIDE;
    void    ViewChanged() FSTUFF_OVERRIDE;
    void    RenderShapes(FSTUFF_Shape * shape, size_t offset, size_t count, float alpha) FSTUFF_OVERRIDE;
    void    SetProjectionMatrix(const gbMat4 & matrix) FSTUFF_OVERRIDE;
    void    SetShapeProperties(FSTUFF_ShapeType shape, size_t i, const gbMat4 & matrix, const gbVec4 & color) FSTUFF_OVERRIDE;
    FSTUFF_CursorInfo GetCursorInfo() FSTUFF_OVERRIDE;
};


@interface FSTUFF_MetalViewController : AppleViewController<MTKViewDelegate>
@property (readonly) FSTUFF_Simulation<FSTUFF_AppleMetalRenderer> * sim;
@property (readonly) FSTUFF_AppleMetalRenderer * renderer;
@property (assign) NSRect initialViewFrame;
@property (strong) NSString * label;
- (NSPoint)mouseLocationFromEvent:(NSEvent *)nsEvent;
@end


#endif  // FSTUFF_USE_METAL
#endif  // FSTUFF_AppleMetal_h

