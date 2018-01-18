
#ifndef FSTUFF_Apple_h
#define FSTUFF_Apple_h

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#include <simd/simd.h>
#include "FSTUFF.h"
#include "FSTUFF_AppleMetalStructs.h"

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
typedef UIViewController AppleViewController;
#else
#import <Cocoa/Cocoa.h>
typedef NSViewController AppleViewController;
#endif

@interface FSTUFF_AppleMetalViewController : AppleViewController<MTKViewDelegate>
@property (readonly) FSTUFF_Simulation * sim;
@end

void    FSTUFF_Apple_GetViewSizeMM(void * nativeView, float * outWidthMM, float * outHeightMM);
void    FSTUFF_Apple_CopyMatrix(matrix_float4x4 & dest, const gbMat4 & src);
void    FSTUFF_Apple_CopyMatrix(gbMat4 & dest, const matrix_float4x4 & src);
void    FSTUFF_Apple_CopyVector(vector_float4 & dest, const gbVec4 & src);
void    FSTUFF_Apple_CopyVector(gbMat4 & dest, const vector_float4 & src);
void    FSTUFF_Log(NSString * fmt, ...) __attribute__((format(NSString, 1, 2)));

// The max number of command buffers in flight
static const NSUInteger FSTUFF_MaxInflightBuffers = 3;

// Max API memory buffer size.
static const size_t FSTUFF_MaxBytesPerFrame = 1024 * 1024; //64; //sizeof(vector_float4) * 3; //*1024;

struct FSTUFF_AppleMetalRenderer : public FSTUFF_Renderer
{
    // controller
    dispatch_semaphore_t _inflight_semaphore;

    // renderer
    id <MTLDevice> device = nil;
    id <MTLRenderCommandEncoder> renderCommandEncoder = nil;
    MTKView * nativeView = nil;
    FSTUFF_GPUData * appData = NULL;
    id <MTLCommandQueue> commandQueue;
    id <MTLLibrary> defaultLibrary;
    id <MTLRenderPipelineState> pipelineState;
    id <MTLRenderPipelineState> overlayPipelineState;
    uint8_t constantDataBufferIndex;
    id <MTLBuffer> gpuConstants[FSTUFF_MaxInflightBuffers];

    void    DestroyVertexBuffer(void * _gpuVertexBuffer) override;
    void *  NewVertexBuffer(void * src, size_t size) override;
    void    GetViewSizeMM(float *outWidthMM, float *outHeightMM) override;
    void    RenderShapes(FSTUFF_Shape * shape, size_t offset, size_t count, float alpha) override;
    void    SetProjectionMatrix(const gbMat4 & matrix) override;
    void    SetShapeProperties(FSTUFF_ShapeType shape, size_t i, const gbMat4 & matrix, const gbVec4 & color) override;
};


#endif
#endif

