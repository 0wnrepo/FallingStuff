//
//  FSTUFF_Apple.mm
//  FallingStuff
//
//  Created by David Ludwig on 6/4/16.
//  Copyright © 2018 David Ludwig. All rights reserved.
//

#include "FSTUFF.h"
#if FSTUFF_USE_METAL

#include "FSTUFF_AppleMetal.h"
#include "FSTUFF_Apple.h"
#include "imgui.h"
#include "AAPLShaderTypes.h"
#import <Foundation/Foundation.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import <GBDeviceInfo/GBDeviceInfo.h>
#elif TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif

#import "FSTUFF_AppleMetalStructs.h"

#if TARGET_OS_IOS
#import <GBDeviceInfo/GBDeviceInfo.h>
#endif


@interface FSTUFF_MetalView : MTKView
@property (weak) FSTUFF_MetalViewController * viewController;
@end

@implementation FSTUFF_MetalView

- (void)mouseDown:(NSEvent *)nsEvent
{
//    const NSPoint pos = [self.viewController mouseLocationFromEvent:nsEvent];
//    const FSTUFF_CursorInfo cur = self.viewController.renderer->GetCursorInfo();
//    FSTUFF_Log("mouse down: event={%f,%f}, get={%f,%f}\n", pos.x, pos.y, cur.xOS, cur.yOS);
    self.viewController.sim->UpdateCursorInfo(self.viewController.renderer->GetCursorInfo());
    [super mouseDown:nsEvent];
}

- (void)mouseUp:(NSEvent *)nsEvent
{
//    const NSPoint pos = [self.viewController mouseLocationFromEvent:nsEvent];
//    FSTUFF_Log("mouse up: {%f, %f}\n", pos.x, pos.y);
    self.viewController.sim->UpdateCursorInfo(self.viewController.renderer->GetCursorInfo());
    [super mouseUp:nsEvent];
}

- (void)mouseMoved:(NSEvent *)nsEvent
{
//    const NSPoint pos = [self.viewController mouseLocationFromEvent:nsEvent];
//    FSTUFF_Log("mouse moved: {%f, %f}\n", pos.x, pos.y);
    self.viewController.sim->UpdateCursorInfo(self.viewController.renderer->GetCursorInfo());
    [super mouseMoved:nsEvent];
}

- (void)mouseDragged:(NSEvent *)nsEvent
{
//    const NSPoint pos = [self.viewController mouseLocationFromEvent:nsEvent];
//    FSTUFF_Log("mouse dragged: {%f, %f}\n", pos.x, pos.y);
    self.viewController.sim->UpdateCursorInfo(self.viewController.renderer->GetCursorInfo());
    [super mouseDragged:nsEvent];
}

- (BOOL) acceptsFirstResponder {
    return YES;
}

@end


#pragma mark - Renderer

void FSTUFF_AppleMetalRenderer::BeginFrame()
{
}

void * FSTUFF_AppleMetalRenderer::NewVertexBuffer(void * src, size_t size)
{
    return (__bridge_retained void *)[this->device newBufferWithBytes:src length:size options:MTLResourceOptionCPUCacheModeDefault];
}

void FSTUFF_AppleMetalRenderer::DestroyVertexBuffer(void * _gpuVertexBuffer)
{
    id <MTLBuffer> gpuVertexBuffer = (__bridge_transfer id <MTLBuffer>)_gpuVertexBuffer;
    gpuVertexBuffer = nil;
}

FSTUFF_Texture FSTUFF_AppleMetalRenderer::NewTexture(const uint8_t * srcRGBA32, int width, int height) {
    MTLTextureDescriptor * desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                     width:width
                                                                                    height:height
                                                                                 mipmapped:NO];
    FSTUFF_Assert(this->device);
    id <MTLTexture> tex = [this->device newTextureWithDescriptor:desc];
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [tex replaceRegion:region mipmapLevel:0 withBytes:srcRGBA32 bytesPerRow:(width * 4)];
    return (__bridge_retained FSTUFF_Texture) tex;
}

void FSTUFF_AppleMetalRenderer::DestroyTexture(FSTUFF_Texture tex) {
    if (!tex) {
        return;
    }
    id <MTLTexture> texObj = (__bridge_transfer id <MTLTexture>) tex;
    texObj = nil;
}

void FSTUFF_AppleMetalRenderer::ViewChanged()
{
    FSTUFF_Assert(this->sim);
    const FSTUFF_ViewSize & viewSize = this->sim->viewSize;

    // If the view is zero-sized, don't try creating a texture for it, yet.  Metal
    // can crash, if an attempt to create a zero-sized texture is performed.
    // The view is apt to change size once again, anyways.
    if (viewSize.widthPixels == 0 || viewSize.heightPixels == 0) {
        FSTUFF_Log("%s, viewSize is empty!\n", __FUNCTION__);
        return;
    }

    FSTUFF_Assert(this->device);

    MTLTextureDescriptor * desc = nil;

    desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                              width:viewSize.widthPixels
                                                             height:viewSize.heightPixels
                                                          mipmapped:NO];
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    this->simTexture = [this->device newTextureWithDescriptor:desc];
    this->simTexture.label = @"FSTUFF Simulation Texture";
    // FSTUFF_Log(@"%s, renderer->simTexture = %@\n", __FUNCTION__, this->simTexture);

    desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                              width:viewSize.widthPixels
                                                             height:viewSize.heightPixels
                                                          mipmapped:NO];
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    this->imGuiTexture = [this->device newTextureWithDescriptor:desc];
    this->imGuiTexture.label = @"FSTUFF ImGui Texture";
}

void FSTUFF_AppleMetalRenderer::RenderShapes(FSTUFF_Shape * shape, size_t offset, size_t count, float alpha)
{
    // Metal can raise a program-crashing assertion, if zero amount of shapes attempts to get
    // rendered.
    if (count == 0) {
        return;
    }

    id <MTLDevice> gpuDevice = this->device;
    id <MTLRenderCommandEncoder> renderCommandEncoder = this->simRenderCommandEncoder;
    id <MTLBuffer> gpuData = (__bridge id <MTLBuffer>) this->appData;

    MTLPrimitiveType gpuPrimitiveType;
    switch (shape->primitiveType) {
        case FSTUFF_PrimitiveLineStrip:
            gpuPrimitiveType = MTLPrimitiveTypeLineStrip;
            break;
        case FSTUFF_PrimitiveTriangles:
            gpuPrimitiveType = MTLPrimitiveTypeTriangle;
            break;
        case FSTUFF_PrimitiveTriangleFan:
            gpuPrimitiveType = MTLPrimitiveTypeTriangleStrip;
            break;
        default:
            FSTUFF_Log(@"Unknown or unmapped FSTUFF_PrimitiveType in shape: %u\n", shape->primitiveType);
            return;
    }

    NSUInteger shapesOffsetInGpuData;
    switch (shape->type) {
        case FSTUFF_ShapeCircle:
            shapesOffsetInGpuData = offsetof(FSTUFF_GPUData, circles);
            break;
        case FSTUFF_ShapeBox:
            shapesOffsetInGpuData = offsetof(FSTUFF_GPUData, boxes);
            break;
        case FSTUFF_ShapeSegment:
            shapesOffsetInGpuData = offsetof(FSTUFF_GPUData, segments);
            break;
        default:
            FSTUFF_Log(@"Unknown or unmapped FSTUFF_ShapeType in shape: %u\n", shape->type);
            return;
    }

    [renderCommandEncoder pushDebugGroup:[[NSString alloc] initWithUTF8String:shape->debugName]];
    [renderCommandEncoder setVertexBuffer:(__bridge id <MTLBuffer>)shape->gpuVertexBuffer offset:0 atIndex:0];   // 'position[<vertex id>]'
    [renderCommandEncoder setVertexBuffer:gpuData offset:offsetof(FSTUFF_GPUData, globals) atIndex:1];           // 'gpuGlobals'
    [renderCommandEncoder setVertexBuffer:gpuData offset:shapesOffsetInGpuData atIndex:2];                       // 'gpuShapes[<instance id>]'
    [renderCommandEncoder setVertexBytes:&alpha length:sizeof(alpha) atIndex:3];                                 // 'alpha'

#if TARGET_OS_IOS
    const MTLFeatureSet featureSetForBaseInstance = MTLFeatureSet_iOS_GPUFamily3_v1;
#else
    const MTLFeatureSet featureSetForBaseInstance = MTLFeatureSet_OSX_GPUFamily1_v1;
#endif
    if (offset == 0) {
        [renderCommandEncoder drawPrimitives:gpuPrimitiveType
                        vertexStart:0
                        vertexCount:shape->numVertices
                      instanceCount:count];
    } else if ([gpuDevice supportsFeatureSet:featureSetForBaseInstance]) {
        [renderCommandEncoder drawPrimitives:gpuPrimitiveType
                                 vertexStart:0
                                 vertexCount:shape->numVertices
                               instanceCount:count
                                baseInstance:offset];
    }
    [renderCommandEncoder popDebugGroup];

}

void FSTUFF_AppleMetalRenderer::RenderImGuiDrawData(
    ImDrawData * drawData,
    id<MTLCommandBuffer> commandBuffer,
    id<MTLRenderCommandEncoder> commandEncoder,
    id<MTLBuffer> __strong & vertexBuffer,
    id<MTLBuffer> __strong & indexBuffer
) {
    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    ImGuiIO &io = ImGui::GetIO();
    int fb_width = (int)(drawData->DisplaySize.x * io.DisplayFramebufferScale.x);
    int fb_height = (int)(drawData->DisplaySize.y * io.DisplayFramebufferScale.y);
    if (fb_width <= 0 || fb_height <= 0 || drawData->CmdListsCount == 0)
        return;
    drawData->ScaleClipRects(io.DisplayFramebufferScale);
    
    [commandEncoder setCullMode:MTLCullModeNone];
    [commandEncoder setDepthStencilState:this->imGuiDepthStencilState];
    
    // Setup viewport, orthographic projection matrix
    // Our visible imgui space lies from draw_data->DisplayPos (top left) to
    // draw_data->DisplayPos+data_data->DisplaySize (bottom right). DisplayMin is typically (0,0) for single viewport apps.
    MTLViewport viewport = 
    {   
        .originX = 0.0,
        .originY = 0.0,
        .width = double(fb_width),
        .height = double(fb_height),
        .znear = 0.0,
        .zfar = 1.0 
    };
    [commandEncoder setViewport:viewport];
    float L = drawData->DisplayPos.x;
    float R = drawData->DisplayPos.x + drawData->DisplaySize.x;
    float T = drawData->DisplayPos.y;
    float B = drawData->DisplayPos.y + drawData->DisplaySize.y;
    float N = viewport.znear;
    float F = viewport.zfar;
    const float ortho_projection[4][4] =
    {
        { 2.0f/(R-L),   0.0f,           0.0f,   0.0f },
        { 0.0f,         2.0f/(T-B),     0.0f,   0.0f },
        { 0.0f,         0.0f,        1/(F-N),   0.0f },
        { (R+L)/(L-R),  (T+B)/(B-T), N/(F-N),   1.0f },
    };
    
    [commandEncoder setVertexBytes:&ortho_projection length:sizeof(ortho_projection) atIndex:1];
    
    size_t vertexBufferLength = 0;
    size_t indexBufferLength = 0;
    for (int n = 0; n < drawData->CmdListsCount; n++) 
    {
        const ImDrawList* cmd_list = drawData->CmdLists[n];
        vertexBufferLength += cmd_list->VtxBuffer.Size * sizeof(ImDrawVert);
        indexBufferLength += cmd_list->IdxBuffer.Size * sizeof(ImDrawIdx);
    }
    
    if (vertexBuffer == nil || [vertexBuffer length] < vertexBufferLength) {
        vertexBuffer = [commandBuffer.device newBufferWithLength:vertexBufferLength options:MTLResourceStorageModeShared];
    }

    if (indexBuffer == nil || [indexBuffer length] < indexBufferLength) {
        indexBuffer = [commandBuffer.device newBufferWithLength:indexBufferLength options:MTLResourceStorageModeShared];
    }
    
    [commandEncoder setRenderPipelineState:this->imGuiRenderPipelineState];
    [commandEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
    
    size_t vertexBufferOffset = 0;
    size_t indexBufferOffset = 0;
    ImVec2 pos = drawData->DisplayPos;
    for (int n = 0; n < drawData->CmdListsCount; n++)
    {
        const ImDrawList* cmd_list = drawData->CmdLists[n];
        ImDrawIdx idx_buffer_offset = 0;
        
        memcpy((char *)vertexBuffer.contents + vertexBufferOffset, cmd_list->VtxBuffer.Data, cmd_list->VtxBuffer.Size * sizeof(ImDrawVert));
        memcpy((char *)indexBuffer.contents + indexBufferOffset, cmd_list->IdxBuffer.Data, cmd_list->IdxBuffer.Size * sizeof(ImDrawIdx));
        
        [commandEncoder setVertexBufferOffset:vertexBufferOffset atIndex:0];
        
        for (int cmd_i = 0; cmd_i < cmd_list->CmdBuffer.Size; cmd_i++)
        {
            const ImDrawCmd* pcmd = &cmd_list->CmdBuffer[cmd_i];
            if (pcmd->UserCallback)
            {
                // User callback (registered via ImDrawList::AddCallback)
                pcmd->UserCallback(cmd_list, pcmd);
            }
            else
            {
                ImVec4 clip_rect = ImVec4(pcmd->ClipRect.x - pos.x, pcmd->ClipRect.y - pos.y, pcmd->ClipRect.z - pos.x, pcmd->ClipRect.w - pos.y);
                if (clip_rect.x < fb_width && clip_rect.y < fb_height && clip_rect.z >= 0.0f && clip_rect.w >= 0.0f)
                {
                    // Apply scissor/clipping rectangle
                    MTLScissorRect scissorRect = { .x = NSUInteger(clip_rect.x),
                        .y = NSUInteger(clip_rect.y),
                        .width = NSUInteger(clip_rect.z - clip_rect.x),
                        .height = NSUInteger(clip_rect.w - clip_rect.y) };
                    [commandEncoder setScissorRect:scissorRect];
                    
                    // Bind texture, Draw
                    if (pcmd->TextureId != NULL)
                        [commandEncoder setFragmentTexture:(__bridge id<MTLTexture>)(pcmd->TextureId) atIndex:0];
                    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                               indexCount:pcmd->ElemCount
                                                indexType:sizeof(ImDrawIdx) == 2 ? MTLIndexTypeUInt16 : MTLIndexTypeUInt32
                                              indexBuffer:indexBuffer
                                        indexBufferOffset:indexBufferOffset + idx_buffer_offset];
                }
            }
            idx_buffer_offset += pcmd->ElemCount * sizeof(ImDrawIdx);
        }
        
        vertexBufferOffset += cmd_list->VtxBuffer.Size * sizeof(ImDrawVert);
        indexBufferOffset += cmd_list->IdxBuffer.Size * sizeof(ImDrawIdx);
    }
}

void FSTUFF_AppleMetalRenderer::SetProjectionMatrix(const gbMat4 & matrix)
{
    FSTUFF_Apple_CopyMatrix(this->appData->globals.projection_matrix, matrix);
}

void FSTUFF_AppleMetalRenderer::SetShapeProperties(FSTUFF_ShapeType shape, size_t i, const gbMat4 & matrix, const gbVec4 & color)
{
    switch (shape) {
        case FSTUFF_ShapeCircle: {
            FSTUFF_Apple_CopyMatrix(this->appData->circles[i].model_matrix, matrix);
            FSTUFF_Apple_CopyVector(this->appData->circles[i].color, color);
        } break;
        case FSTUFF_ShapeBox: {
            FSTUFF_Apple_CopyMatrix(this->appData->boxes[i].model_matrix, matrix);
            FSTUFF_Apple_CopyVector(this->appData->boxes[i].color, color);
        } break;
        case FSTUFF_ShapeSegment: {
            FSTUFF_Apple_CopyMatrix(this->appData->segments[i].model_matrix, matrix);
            FSTUFF_Apple_CopyVector(this->appData->segments[i].color, color);
        } break;
        case FSTUFF_ShapeDebug: {
            FSTUFF_Apple_CopyMatrix(this->appData->debugShapes[i].model_matrix, matrix);
            FSTUFF_Apple_CopyVector(this->appData->debugShapes[i].color, color);
        } break;
    }
}

//- (NSPoint)mouseLocationFromEvent:(NSEvent *)nsEvent
//{
//    const NSPoint posInWindow = [nsEvent locationInWindow];
//    const NSPoint posInView = [renderer->nativeView convertPoint:posInWindow fromView:nil];
//
//    // Cocoa views seem to like making Y=0 be at the bottom of the view, rather than at the top.
//    // ImGui wants coordinates with Y=0 being at the top, so, convert to that!
//    const CGFloat viewHeight = renderer->nativeView.bounds.size.height;
//    const NSPoint posWithYFlip = {posInView.x, viewHeight - posInView.y};
//    return posWithYFlip;
//}

FSTUFF_CursorInfo FSTUFF_AppleMetalRenderer::GetCursorInfo()
{
#if TARGET_OS_IOS
    FSTUFF_LOG_IMPLEMENT_ME(", get cursor info on iOS");
    return FSTUFF_CursorInfo();
#else
    const NSUInteger pressedMouseButtons = [NSEvent pressedMouseButtons];
    const CGPoint mouseLocation = [NSEvent mouseLocation];
    const CGPoint windowPos = this->nativeView.window.frame.origin;
    const CGPoint posInWindow = {
        mouseLocation.x - windowPos.x,
        mouseLocation.y - windowPos.y
    };
    const CGPoint posInView = [this->nativeView convertPoint:posInWindow fromView:nil];
    
    // Cocoa views seem to like making Y=0 be at the bottom of the view, rather than at the top.
    // ImGui wants coordinates with Y=0 being at the top, so, convert to that!
    const CGFloat viewHeight = this->nativeView.bounds.size.height;
    const NSPoint posWithYFlip = {posInView.x, viewHeight - posInView.y};
    
    FSTUFF_CursorInfo out;
    out.xOS = posWithYFlip.x;
    out.yOS = posWithYFlip.y;
//    FSTUFF_Log("** GetPos: pos={%.0f,%.0f}, btns=%lu\n", posWithYFlip.x, posWithYFlip.y, (unsigned long)pressedMouseButtons);
//    FSTUFF_Log("pressedMouseButtons: %lu\n", (unsigned long)pressedMouseButtons);
    out.pressed = (pressedMouseButtons != 0);
//    out.contained = NSPointInRect(this->nativeView.window.)
    return out;
#endif
}

@interface FSTUFF_MetalViewController()
@property (nonatomic, strong) MTKView *theView;
@end

@implementation FSTUFF_MetalViewController
{
    // renderer
    FSTUFF_AppleMetalRenderer * renderer;

    // game
    FSTUFF_Simulation * sim;
    
#if ! TARGET_OS_IOS
    // Cursor tracking area
    NSTrackingArea * area;
#endif
}

- (FSTUFF_Simulation *) sim
{
    @synchronized(self) {
        FSTUFF_Assert(sim != nullptr);  // sim is probably created in, mabybe before, viewDidLoad
        return sim;
    }
}

- (FSTUFF_AppleMetalRenderer *) renderer
{
    @synchronized(self) {
        return renderer;
    }
}

- (void)dealloc
{
return;
    FSTUFF_Log(@"%s, sim:%p\n", __PRETTY_FUNCTION__, sim);
    if (sim) {
        delete sim;
        sim = NULL;
    }
    
    FSTUFF_Log(@"%s, renderer:%p\n", __PRETTY_FUNCTION__, renderer);
    if (renderer) {
        delete renderer;
        renderer = NULL;
    }
}

- (void)loadView
{
    MTKView * _metalView = nil;
    if (self.initialViewFrame.size.width > 0 && self.initialViewFrame.size.height > 0) {
        _metalView = [[FSTUFF_MetalView alloc] initWithFrame:self.initialViewFrame];
    } else {
        _metalView = [[FSTUFF_MetalView alloc] init];
    }

    self.view = _metalView;
    FSTUFF_Log(@"%s, label:%@, view:<%@>, view.size:{%.0f,%.0f}, drawableSize:{%.0f,%.0f}\n", __PRETTY_FUNCTION__, self.label, _metalView, _metalView.frame.size.width, _metalView.frame.size.height, _metalView.drawableSize.width, _metalView.drawableSize.height);

}

- (void)updateTrackingArea
{
#if ! TARGET_OS_IOS
    if (area) {
        [self.view removeTrackingArea:area];
        area = nil;
    }

    area = [[NSTrackingArea alloc] initWithRect:[self.view bounds]
                                        options:(NSTrackingActiveAlways | NSTrackingInVisibleRect |
                         NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved)
                                          owner:self
                                       userInfo:nil];
    [self.view addTrackingArea:area];
#endif
}

- (void)viewWillAppear
{
    MTKView * _metalView = (MTKView *)self.view;
    self.view = _metalView;
    FSTUFF_Log(@"%s, view:<%@>, view.size:{%.0f,%.0f}, drawableSize:{%.0f,%.0f}\n", __PRETTY_FUNCTION__, _metalView, _metalView.frame.size.width, _metalView.frame.size.height, _metalView.drawableSize.width, _metalView.drawableSize.height);
    [super viewWillAppear];
    
//    // Setup a texture to draw the simulation to
//    if (sim->DidInit()) {
//        renderer->ViewChanged();
//    }
}

- (void)viewDidLoad
{
    FSTUFF_MetalView * _metalView = (FSTUFF_MetalView *)self.view;
    FSTUFF_Log(@"%s, view:<%@>, view.size:{%.0f,%.0f}, drawableSize:{%.0f,%.0f}\n", __PRETTY_FUNCTION__, _metalView, _metalView.frame.size.width, _metalView.frame.size.height, _metalView.drawableSize.width, _metalView.drawableSize.height);
    [super viewDidLoad];
    
    if ( ! self.label) {
        self.label = @"Unlabelled";
    }
    
    sim = new FSTUFF_Simulation();
    renderer = new FSTUFF_AppleMetalRenderer();
    renderer->sim = sim;
    renderer->constantDataBufferIndex = 0;
    renderer->_inflight_semaphore = dispatch_semaphore_create(3);

    // Set the view to use the default, Metal device
    renderer->device = MTLCreateSystemDefaultDevice();

    // Create a new, Metal command queue
    renderer->commandQueue = [renderer->device newCommandQueue];

    // Load all the shader files with a metal file extension in the project
    //
    // Get the path to the bundle, in a manner that works with macOS's ScreenSaverEngine.app.
    // This app stores screensavers as separate bundles.  We need to find the bundle for the
    // screensaver that we are using.
    NSBundle * bundle = [NSBundle bundleForClass:[self class]];
    NSString * path = [bundle pathForResource:@"default" ofType:@"metallib"];
    NSError * err = nil;
    renderer->defaultLibrary = [renderer->device newLibraryWithFile:path error:&err];
    if ( ! renderer->defaultLibrary) {
        FSTUFF_Log(@"Failed to create Metal library, error:%@\n", err);
    }

    if (renderer->device) {
        // Setup view
        renderer->nativeView = (MTKView *)self.view;
        renderer->nativeView.delegate = self;
        renderer->nativeView.device = renderer->device;
        self.sim->renderer = renderer;

//        // Setup a texture to draw the simulation to
//        renderer->ViewChanged();

        // Describe stuff common to all pipeline states
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = nil;

        pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"FSTUFF_SimulationPipeline";
        pipelineStateDescriptor.sampleCount = renderer->nativeView.sampleCount;
        pipelineStateDescriptor.fragmentFunction = [renderer->defaultLibrary newFunctionWithName:@"FSTUFF_FragmentShader"];
        pipelineStateDescriptor.vertexFunction = [renderer->defaultLibrary newFunctionWithName:@"FSTUFF_VertexShader"];
//        pipelineStateDescriptor.colorAttachments[0].pixelFormat = _renderer->nativeView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        renderer->simulationPipelineState = [renderer->device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&err];
        if ( ! renderer->simulationPipelineState) {
            FSTUFF_Log(@"Failed to create pipeline state, error:%@\n", err);
        }


//        pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
//        pipelineStateDescriptor.label = @"FSTUFF_MainPipeline";
//        pipelineStateDescriptor.sampleCount = _renderer->nativeView.sampleCount;
//        pipelineStateDescriptor.fragmentFunction = [_renderer->defaultLibrary newFunctionWithName:@"samplingShader"];
////        pipelineStateDescriptor.fragmentFunction = [_renderer->defaultLibrary newFunctionWithName:@"FSTUFF_FragmentShader"];
//        pipelineStateDescriptor.vertexFunction = [_renderer->defaultLibrary newFunctionWithName:@"vertexShader"];
//        pipelineStateDescriptor.colorAttachments[0].pixelFormat = _renderer->nativeView.colorPixelFormat;
//        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
//        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
//        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
//        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
//        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
//        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
//        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

        pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"FSTUFF_MainPipeline";
        pipelineStateDescriptor.vertexFunction = [renderer->defaultLibrary newFunctionWithName:@"vertexShader"];;
        pipelineStateDescriptor.fragmentFunction = [renderer->defaultLibrary newFunctionWithName:@"samplingShader"];
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = renderer->nativeView.colorPixelFormat;
        renderer->mainPipelineState = [renderer->device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&err];
        if ( ! renderer->mainPipelineState) {
            FSTUFF_Log(@"Failed to create main pipeline state, error:%@\n", err);
        }

        // Setup ImGui backend stuff
        {
            NSError *error = nil;
    
            NSString *shaderSource = @""
            "#include <metal_stdlib>\n"
            "using namespace metal;\n"
            "\n"
            "struct Uniforms {\n"
            "    float4x4 projectionMatrix;\n"
            "};\n"
            "\n"
            "struct VertexIn {\n"
            "    float2 position  [[attribute(0)]];\n"
            "    float2 texCoords [[attribute(1)]];\n"
            "    uchar4 color     [[attribute(2)]];\n"
            "};\n"
            "\n"
            "struct VertexOut {\n"
            "    float4 position [[position]];\n"
            "    float2 texCoords;\n"
            "    float4 color;\n"
            "};\n"
            "\n"
            "vertex VertexOut vertex_main(VertexIn in                 [[stage_in]],\n"
            "                             constant Uniforms &uniforms [[buffer(1)]]) {\n"
            "    VertexOut out;\n"
            "    out.position = uniforms.projectionMatrix * float4(in.position, 0, 1);\n"
            "    out.texCoords = in.texCoords;\n"
            "    out.color = float4(in.color) / float4(255.0);\n"
            "    return out;\n"
            "}\n"
            "\n"
            "fragment half4 fragment_main(VertexOut in [[stage_in]],\n"
            "                             texture2d<half, access::sample> texture [[texture(0)]]) {\n"
            "    constexpr sampler linearSampler(coord::normalized, min_filter::linear, mag_filter::linear, mip_filter::linear);\n"
            "    half4 texColor = texture.sample(linearSampler, in.texCoords);\n"
            "    return half4(in.color) * texColor;\n"
            "}\n";
            
            id<MTLLibrary> library = [renderer->device newLibraryWithSource:shaderSource options:nil error:&error];
            if (library == nil) {
                FSTUFF_FatalError(@"Error: failed to create Metal library: %@", error);
            }
            
            id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
            id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
            
            if (vertexFunction == nil || fragmentFunction == nil) {
                FSTUFF_FatalError(@"Error: failed to find Metal shader functions in library: %@", error);
            }
            
            MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor vertexDescriptor];
            vertexDescriptor.attributes[0].offset = IM_OFFSETOF(ImDrawVert, pos);
            vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2; // position
            vertexDescriptor.attributes[0].bufferIndex = 0;
            vertexDescriptor.attributes[1].offset = IM_OFFSETOF(ImDrawVert, uv);
            vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2; // texCoords
            vertexDescriptor.attributes[1].bufferIndex = 0;
            vertexDescriptor.attributes[2].offset = IM_OFFSETOF(ImDrawVert, col);
            vertexDescriptor.attributes[2].format = MTLVertexFormatUChar4; // color
            vertexDescriptor.attributes[2].bufferIndex = 0;
            vertexDescriptor.layouts[0].stepRate = 1;
            vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
            vertexDescriptor.layouts[0].stride = sizeof(ImDrawVert);
            
            MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
            pipelineDescriptor.vertexFunction = vertexFunction;
            pipelineDescriptor.fragmentFunction = fragmentFunction;
            pipelineDescriptor.vertexDescriptor = vertexDescriptor;
            pipelineDescriptor.sampleCount = renderer->nativeView.sampleCount;
            pipelineDescriptor.colorAttachments[0].pixelFormat = renderer->nativeView.colorPixelFormat;
            pipelineDescriptor.colorAttachments[0].blendingEnabled = YES;
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
            pipelineDescriptor.depthAttachmentPixelFormat = renderer->nativeView.depthStencilPixelFormat;
            pipelineDescriptor.stencilAttachmentPixelFormat = renderer->nativeView.depthStencilPixelFormat;
            renderer->imGuiRenderPipelineState = [renderer->device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
            if (error != nil)  {
                FSTUFF_FatalError(@"Error: failed to create Metal pipeline state for ImGui: %@", error);
            }
        }


        // Create a single, unchanging vertex buffer, for use in blending layers
        // (such as for the simulation, and any overlays).
        static const AAPLVertex quadVertices[] =
        {
            { {  1,   1 },  { 1.f, 0.f } },
            { { -1,   1 },  { 0.f, 0.f } },
            { { -1,  -1 },  { 0.f, 1.f } },

            { {  1,   1 },  { 1.f, 0.f } },
            { { -1,  -1 },  { 0.f, 1.f } },
            { {  1,  -1 },  { 1.f, 1.f } },
        };

        // Create our vertex buffer, and initialize it with our quadVertices array
        renderer->rectVBO = [renderer->device newBufferWithBytes:quadVertices
                                         length:sizeof(quadVertices)
                                        options:MTLResourceStorageModeShared];

        // Calculate the number of vertices by dividing the byte length by the size of each vertex
        renderer->rectVBOCount = sizeof(quadVertices) / sizeof(AAPLVertex);


        // allocate a number of buffers in memory that matches the sempahore count so that
        // we always have one self contained memory buffer for each buffered frame.
        // In this case triple buffering is the optimal way to go so we cycle through 3 memory buffers
        for (int i = 0; i < FSTUFF_MaxInflightBuffers; i++) {
            renderer->gpuConstants[i] = [renderer->device newBufferWithLength:FSTUFF_MaxBytesPerFrame options:0];
            renderer->gpuConstants[i].label = [NSString stringWithFormat:@"FSTUFF_ConstantBuffer%i", i];

            // ImGui buffers are created dynamically.  Zero-initialize them for now.
            renderer->imGuiVertexBuffers[i] = nil;
            renderer->imGuiIndexBuffers[i] = nil;
        }

        // Setup ImGui stuff
        MTLDepthStencilDescriptor * depthStencilDescriptor = [[MTLDepthStencilDescriptor alloc] init];
        depthStencilDescriptor.depthWriteEnabled = NO;
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionAlways;
        renderer->imGuiDepthStencilState = [renderer->device newDepthStencilStateWithDescriptor:depthStencilDescriptor];
        
        // Update view-size derived variables inside of 'sim'
        const FSTUFF_ViewSize viewSize = FSTUFF_Apple_GetViewSize((__bridge void *)_metalView);
        self.sim->ViewChanged(viewSize);    // this should set sim->viewSize (among other things)

    } else { // Fallback to a blank NSView, an application could also fallback to OpenGL here.
        FSTUFF_Log(@"Metal is not supported on this device\n");
#if ! TARGET_OS_IOS
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
#endif
    }

    _metalView.viewController = self;
    [self updateTrackingArea];
    self.sim->UpdateCursorInfo(renderer->GetCursorInfo());
    
    //MTKView * _metalView = (MTKView *) self.view;
    FSTUFF_Log(@"%s, DONE, view:<%@>, view.size:{%.0f,%.0f}, drawableSize:{%.0f,%.0f}\n", __PRETTY_FUNCTION__, _metalView, _metalView.frame.size.width, _metalView.frame.size.height, _metalView.drawableSize.width, _metalView.drawableSize.height);

}

#if ! TARGET_OS_IOS

static FSTUFF_Event FSTUFF_NewKeyEventForNSEvent(NSEvent * nsEvent) {
    FSTUFF_EventType fstuffEventType;
    switch ([nsEvent type]) {
        case NSEventTypeKeyDown:
            fstuffEventType = FSTUFF_EventKeyDown;
            break;
        case NSEventTypeKeyUp:
            fstuffEventType = FSTUFF_EventKeyUp;
            break;
        default:
            return FSTUFF_Event();
    }
    
    char32_t utf32Char = 0;
    switch ([nsEvent keyCode]) {
        case 125:    // Down arrow
            utf32Char = U'↓';
            break;
        case 123:    // Left arrow
            utf32Char = U'←';
            break;
        case 124:    // Right arrow
            utf32Char = U'→';
            break;
        case 126:    // Up arrow
            utf32Char = U'↑';
            break;
        default:
            break;
    }

    if (utf32Char != 0) {
        return FSTUFF_Event::NewKeyEvent(fstuffEventType, utf32Char);
    } else {
        return FSTUFF_Event::NewKeyEvent(fstuffEventType, [nsEvent.characters cStringUsingEncoding:NSUTF8StringEncoding]);
    }
}

- (void)keyDown:(NSEvent *)nsEvent
{
    FSTUFF_Event fstuffEvent = FSTUFF_NewKeyEventForNSEvent(nsEvent);
    
    if (std::toupper([nsEvent.characters cStringUsingEncoding:NSUTF8StringEncoding][0]) == 'C') {
        NSWindow * window = FSTUFF_CreateConfigureSheet();
#if 0
        [window makeKeyAndOrderFront:window];
#else
        [self.renderer->nativeView.window beginSheet:window completionHandler:^(NSModalResponse returnCode)
        {
            FSTUFF_Log(@"sheet completion handler reached, returnCode=%ld\n", (long)returnCode);
        }];
        fstuffEvent.handled = true;
#endif
    }
    
    self.sim->EventReceived(&fstuffEvent);
    if ( ! fstuffEvent.handled) {
        [super keyDown:nsEvent];
    }
}

- (void)keyUp:(NSEvent *)nsEvent
{
    FSTUFF_Event fstuffEvent = FSTUFF_NewKeyEventForNSEvent(nsEvent);
    self.sim->EventReceived(&fstuffEvent);
    if ( ! fstuffEvent.handled) {
        [super keyUp:nsEvent];
    }
}

- (NSPoint)mouseLocationFromEvent:(NSEvent *)nsEvent
{
    const NSPoint posInWindow = [nsEvent locationInWindow];
    const NSPoint posInView = [renderer->nativeView convertPoint:posInWindow fromView:nil];
    
    // Cocoa views seem to like making Y=0 be at the bottom of the view, rather than at the top.
    // ImGui wants coordinates with Y=0 being at the top, so, convert to that!
    const CGFloat viewHeight = renderer->nativeView.bounds.size.height;
    const NSPoint posWithYFlip = {posInView.x, viewHeight - posInView.y};
    return posWithYFlip;
}

- (void)mouseDown:(NSEvent *)nsEvent
{
//    const NSPoint pos = [self mouseLocationFromEvent:nsEvent];
//    const FSTUFF_CursorInfo cur = renderer->GetCursorInfo();
//    FSTUFF_Log("mouse down: event={%f,%f}, get={%f,%f}\n", pos.x, pos.y, cur.xOS, cur.yOS);
    sim->UpdateCursorInfo(renderer->GetCursorInfo());
    [super mouseDown:nsEvent];
}

- (void)mouseUp:(NSEvent *)nsEvent
{
//    const NSPoint pos = [self mouseLocationFromEvent:nsEvent];
//    FSTUFF_Log("mouse up: {%f, %f}\n", pos.x, pos.y);
    sim->UpdateCursorInfo(renderer->GetCursorInfo());
    [super mouseUp:nsEvent];
}

- (void)mouseMoved:(NSEvent *)nsEvent
{
//    const NSPoint pos = [self mouseLocationFromEvent:nsEvent];
//    FSTUFF_Log("mouse moved: {%f, %f}\n", pos.x, pos.y);
    sim->UpdateCursorInfo(renderer->GetCursorInfo());
    [super mouseMoved:nsEvent];
}

- (void)mouseDragged:(NSEvent *)nsEvent
{
//    const NSPoint pos = [self mouseLocationFromEvent:nsEvent];
//    FSTUFF_Log("mouse dragged: {%f, %f}\n", pos.x, pos.y);
    sim->UpdateCursorInfo(renderer->GetCursorInfo());
    [super mouseDragged:nsEvent];
}

- (void)mouseEntered:(NSEvent *)nsEvent
{
//    FSTUFF_Event event = FSTUFF_Event::NewCursorContainedEvent(true);
//    self.sim->EventReceived(&event);
//    if ( ! event.handled) {
//        [super mouseEntered:nsEvent];
//    }

//    sim->UpdateCursorInfo(renderer->GetCursorInfo());
//    [super mouseEntered:nsEvent];
}

- (void)mouseExited:(NSEvent *)nsEvent
{
//    FSTUFF_Event event = FSTUFF_Event::NewCursorContainedEvent(false);
//    self.sim->EventReceived(&event);
//    if ( ! event.handled) {
//        [super mouseExited:nsEvent];
//    }

//    sim->UpdateCursorInfo(renderer->GetCursorInfo());
//    [super mouseExited:nsEvent];
}


#endif

//#ifndef _MTLFeatureSet_iOS_GPUFamily3_v1

// Called whenever view changes orientation or layout is changed
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    @autoreleasepool {
        if (sim->DidInit()) {
            renderer->nativeView = (MTKView *) self.view;
            FSTUFF_Assert(renderer);
            FSTUFF_Assert(renderer->nativeView);
            const FSTUFF_ViewSize viewSize = FSTUFF_Apple_GetViewSize((__bridge void *)(renderer->nativeView));
            self.sim->ViewChanged(viewSize);
            [self updateTrackingArea];
        }
    }
}

// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view
{
    @autoreleasepool {
        dispatch_semaphore_wait(renderer->_inflight_semaphore, DISPATCH_TIME_FOREVER);

        // Update FSTUFF state
        renderer->appData = (FSTUFF_GPUData *) [renderer->gpuConstants[renderer->constantDataBufferIndex] contents];
        self.sim->Update();

        // Create a new command buffer for each renderpass to the current drawable
        id <MTLCommandBuffer> commandBuffer = [renderer->commandQueue commandBuffer];
        commandBuffer.label = @"FSTUFF_CommandBuffer";

        // Call the view's completion handler which is required by the view since it will signal its semaphore and set up the next buffer
        __block dispatch_semaphore_t block_sema = renderer->_inflight_semaphore;
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            dispatch_semaphore_signal(block_sema);
        }];
        
        // Obtain a renderPassDescriptor generated from the view's drawable textures
        MTLRenderPassDescriptor* mainRenderPass = renderer->nativeView.currentRenderPassDescriptor;

        if (mainRenderPass) { // If we have a valid drawable, begin the commands to render into it

            FSTUFF_Assert(renderer->simTexture);

            // Create a render pass for the simulation
            MTLRenderPassDescriptor *simRenderPass = [MTLRenderPassDescriptor renderPassDescriptor];
        //    renderPassDescriptor.colorAttachments[0].texture = [(id<CAMetalDrawable>)mtlCurrentDrawable texture];
            simRenderPass.colorAttachments[0].texture = renderer->simTexture;
            simRenderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
            simRenderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
            simRenderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

            // Create render command encoders so we can render into something
            id <MTLRenderCommandEncoder> simRenderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:simRenderPass];
            renderer->simRenderCommandEncoder = simRenderCommandEncoder;
            simRenderCommandEncoder.label = @"FSTUFF_SimRenderEncoder";
            [simRenderCommandEncoder setRenderPipelineState:renderer->simulationPipelineState];

            // Draw shapes
            renderer->appData = (__bridge FSTUFF_GPUData *)renderer->gpuConstants[renderer->constantDataBufferIndex];
            self.sim->Render();
            
            // We're done encoding simulation-related commands
            [simRenderCommandEncoder endEncoding];
            renderer->simRenderCommandEncoder = nil;

            // Create a render pass for ImGui
            MTLRenderPassDescriptor * imGuiRenderPass = [MTLRenderPassDescriptor renderPassDescriptor];
            FSTUFF_Assert(renderer->imGuiTexture != nil);
            imGuiRenderPass.colorAttachments[0].texture = renderer->imGuiTexture;
            imGuiRenderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
            imGuiRenderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
            imGuiRenderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);

            // Create render command encoders so we can render into something
            id <MTLRenderCommandEncoder> imGuiRenderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:imGuiRenderPass];
            renderer->imGuiRenderCommandEncoder = imGuiRenderCommandEncoder;
            imGuiRenderCommandEncoder.label = @"FSTUFF_ImGuiRenderEncoder";

            // Draw ImGui data
            ImDrawData * imGuiDrawData = ImGui::GetDrawData();
            renderer->RenderImGuiDrawData(
                imGuiDrawData,
                commandBuffer,
                imGuiRenderCommandEncoder,
                renderer->imGuiVertexBuffers[renderer->constantDataBufferIndex],
                renderer->imGuiIndexBuffers[renderer->constantDataBufferIndex]
            );

            // We're done encoding ImGui-related commands
            [imGuiRenderCommandEncoder endEncoding];
            renderer->imGuiRenderCommandEncoder = nil;

            // Create another render command encoder so we can combine the layers
            id <MTLRenderCommandEncoder> mainRenderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:mainRenderPass];
            renderer->mainRenderCommandEncoder = mainRenderCommandEncoder;
            mainRenderCommandEncoder.label = @"FSTUFF_MainRenderEncoder";
            [mainRenderCommandEncoder setRenderPipelineState:renderer->mainPipelineState];
            [mainRenderCommandEncoder setVertexBuffer:renderer->rectVBO
                                               offset:0
                                              atIndex:AAPLVertexInputIndexVertices];
            [mainRenderCommandEncoder setFragmentTexture:renderer->simTexture
                                                 atIndex:AAPLTextureIndexBaseColor];
            [mainRenderCommandEncoder setFragmentTexture:renderer->imGuiTexture
                                                 atIndex:AAPLTextureIndexOverlayColor];
            [mainRenderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                                         vertexStart:0
                                         vertexCount:renderer->rectVBOCount];
            [mainRenderCommandEncoder endEncoding];
            renderer->mainRenderCommandEncoder = nil;

            // Schedule a present once the framebuffer is complete using the current drawable
            [commandBuffer presentDrawable:renderer->nativeView.currentDrawable];
        }

        // The render assumes it can now increment the buffer index and that the previous index won't be touched until we cycle back around to the same index
        renderer->constantDataBufferIndex = (renderer->constantDataBufferIndex + 1) % FSTUFF_MaxInflightBuffers;

        // Finalize rendering here & push the command buffer to the GPU
        [commandBuffer commit];
        
        // Close configuration sheets, as necessary
        if (sim->doEndConfiguration) {
//            FSTUFF_Log(@"%s, doEndConfiguration was true in sim:%p, self:%p, self.view.window:%@\n", __PRETTY_FUNCTION__, sim, self, self.view.window);
            [self.view.window.sheetParent endSheet:self.view.window];
        }
    }
}

@end

#endif  // FSTUFF_USE_METAL
