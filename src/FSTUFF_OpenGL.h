//
//  FSTUFF_OpenGL.h
//  FallingStuff
//
//  Created by David Ludwig on 11/16/18.
//  Copyright © 2018 David Ludwig. All rights reserved.
//

#ifndef FSTUFF_OpenGL_h
#define FSTUFF_OpenGL_h

#include "FSTUFF.h"
#include "FSTUFF_Constants.h"
#include "gb_math.h"
#include <unordered_set>

#if __APPLE__
    #if TARGET_OS_IOS
        #include <OpenGLES/ES3/glext.h>
    #else
        #include <OpenGL/gl3.h>
        #include <OpenGL/gl3ext.h>
    #endif
#else
    // The below are from https://www.khronos.org/registry/OpenGL/index_es.php#headers3
    #include <GLES3/gl3.h>
    #include <GLES2/gl2ext.h>
    #include <GLES3/gl3platform.h>
#endif

#if _MSC_VER
	#define FSTUFF_stdcall __stdcall
#else
	#define FSTUFF_stdcall
#endif

void FSTUFF_GLCheck_Inner(FSTUFF_CodeLocation location);
#define FSTUFF_GLCheck() FSTUFF_GLCheck_Inner(FSTUFF_CODELOC)

enum class FSTUFF_GLVersion {
    GLCorev3,
    GLESv2,
    GLESv3,
};

struct FSTUFF_GLESRenderer : public FSTUFF_Renderer<FSTUFF_GLESRenderer> {
    FSTUFF_GLVersion glVersion = FSTUFF_GLVersion::GLESv3;
    
    void * nativeView = nullptr;
    FSTUFF_NativeViewType nativeViewType = FSTUFF_NativeViewType::Unknown;
    
    std::function<void *(const char *)> getProcAddress;
    
    void (FSTUFF_stdcall * glVertexAttribDivisor)(GLuint, GLuint) = nullptr;
    void (FSTUFF_stdcall * glDrawArraysInstanced)(GLenum, GLint, GLsizei, GLsizei) = nullptr;
    const GLubyte * (FSTUFF_stdcall * glGetStringi)(GLenum, GLuint);
    
    std::unordered_set<std::string> glExtensionsCache;

    gbMat4 projectionMatrix;

    GLuint mainVAO = 0;     // 'VAO' == 'Vertex Array Object'

    gbMat4 circleMatrices[FSTUFF_MaxCircles];
    GLuint circleMatricesBufID = -1;
    gbVec4 circleColors[FSTUFF_MaxCircles];
    GLuint circleColorsBufID = -1;
    gbMat4 boxMatrices[FSTUFF_MaxBoxes];
    GLuint boxMatricesBufID = -1;
    gbVec4 boxColors[FSTUFF_MaxBoxes];
    GLuint boxColorsBufID = -1;
    gbMat4 debugShapeMatrices[1];
    GLuint debugShapeMatricesBufID = -1;
    gbVec4 debugShapeColors[1];
    GLuint debugShapeColorsBufID = -1;

    GLuint programObject = 0;
    GLint vertexShaderAttribute_position = -1;
    GLint vertexShaderAttribute_colorRGBX = -1;
    GLint vertexShaderAttribute_alpha = -1;
    GLint vertexShaderAttribute_modelMatrix = -1;

    FSTUFF_GLESRenderer();
    ~FSTUFF_GLESRenderer() FSTUFF_OVERRIDE;
    void    Init();
    void    BeginFrame();
    void    DestroyVertexBuffer(void * gpuVertexBuffer) FSTUFF_OVERRIDE;
    void *  NewVertexBuffer(void * src, size_t size) FSTUFF_OVERRIDE;
    void    ViewChanged() FSTUFF_OVERRIDE;
    void    RenderShapes(FSTUFF_Shape * shape, size_t offset, size_t count, float alpha) FSTUFF_OVERRIDE;
    void    SetProjectionMatrix(const gbMat4 & matrix) FSTUFF_OVERRIDE;
    void    SetShapeProperties(FSTUFF_ShapeType shape, size_t i, const gbMat4 & matrix, const gbVec4 & color) FSTUFF_OVERRIDE;
    FSTUFF_CursorInfo GetCursorInfo() FSTUFF_OVERRIDE;
};


#endif // FSTUFF_OpenGL_h
