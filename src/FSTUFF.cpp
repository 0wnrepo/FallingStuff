//
//  FSTUFF.cpp
//  FallingStuff
//
//  Created by David Ludwig on 5/30/16.
//  Copyright © 2018 David Ludwig. All rights reserved.
//

//#import "FSTUFF_AppleMetalStructs.h"
#include "FSTUFF.h"
#include <sys/time.h>   // for gettimeofday()
#include <random>

#define GB_MATH_IMPLEMENTATION
#include "gb_math.h"


#pragma mark - Random Number Generation

cpFloat FSTUFF_RandRangeF(std::mt19937 & rng, cpFloat a, cpFloat b)
{
    std::uniform_real_distribution<cpFloat> distribution(a, b);
    return distribution(rng);
}

int FSTUFF_RandRangeI(std::mt19937 & rng, int a, int b)
{
    std::uniform_int_distribution<int> distribution(a, b);
    return distribution(rng);
}


#pragma mark - Rendering

FSTUFF_Renderer::~FSTUFF_Renderer()
{
}

constexpr gbVec4 FSTUFF_Color(uint32_t rgb, uint8_t a)
{
    return {
        ((((uint32_t)rgb) >> 16) & 0xFF) / 255.0f,
        ((((uint32_t)rgb) >> 8) & 0xFF) / 255.0f,
        (rgb & 0xFF) / 255.0f,
        (a) / 255.0f
    };
}

constexpr gbVec4 FSTUFF_Color(uint32_t rgb)
{
    return FSTUFF_Color(rgb, 0xff);
}


#pragma mark - Shapes, Circle

static const unsigned kNumCircleParts = 64; //32;

#define FSTUFF_countof(arr) (sizeof(arr) / sizeof(arr[0]))

#define RAD_IDX(I) (((float)I) * kRadianStep)
#define COS_IDX(I) ((float)cos(RAD_IDX(I)))
#define SIN_IDX(I) ((float)sin(RAD_IDX(I)))

void FSTUFF_MakeCircleFilledTriangles(gbVec4 * vertices,
                                      int maxVertices,
                                      int * numVertices,
                                      int numPartsToGenerate,
                                      float radius,
                                      float offsetX,
                                      float offsetY)
{
//    // TODO: check the size of the vertex buffer!
//    static const int kVertsPerPart = 3;
//    const float kRadianStep = ((((float)M_PI) * 2.0f) / (float)numPartsToGenerate);
//    *numVertices = numPartsToGenerate * kVertsPerPart;
//    for (unsigned i = 0; i < numPartsToGenerate; ++i) {
//        vertices[(i * kVertsPerPart) + 0] = {           0,            0, 0, 1};
//        vertices[(i * kVertsPerPart) + 1] = {COS_IDX( i ), SIN_IDX( i ), 0, 1};
//        vertices[(i * kVertsPerPart) + 2] = {COS_IDX(i+1), SIN_IDX(i+1), 0, 1};
//    }

//    numPartsToGenerate = 8;

    const gbVec4 * verticesOrig = vertices;
    const int n = numPartsToGenerate / 2;
    float rad = 0.;
    const float radStep = M_PI/(float)n;

    // start
    *vertices++ = { (1.f*radius) + offsetX,                 ( 0.f*radius) + offsetY,                  0,  1};
    *vertices++ = { (cosf(rad + radStep)*radius) + offsetX, (-sinf(rad + radStep)*radius) + offsetY,  0,  1};
    *vertices++ = { (cosf(rad + radStep)*radius) + offsetX, ( sinf(rad + radStep)*radius) + offsetY,  0,  1};
    rad += radStep;
    
    // mid
    for (int i = 1; i <= (n-2); ++i) {
        *vertices++ = { (cosf(rad)*radius) + offsetX,         ( sinf(rad)*radius) + offsetY,            0,  1};
        *vertices++ = { (cosf(rad)*radius) + offsetX,         (-sinf(rad)*radius) + offsetY,            0,  1};
        *vertices++ = { (cosf(rad+radStep)*radius) + offsetX, (-sinf(rad+radStep)*radius) + offsetY,    0,  1};
        *vertices++ = { (cosf(rad+radStep)*radius) + offsetX, (-sinf(rad+radStep)*radius) + offsetY,    0,  1};
        *vertices++ = { (cosf(rad+radStep)*radius) + offsetX, ( sinf(rad+radStep)*radius) + offsetY,    0,  1};
        *vertices++ = { (cosf(rad)*radius) + offsetX,         ( sinf(rad)*radius) + offsetY,            0,  1};

        rad += radStep;
    }
    
    // end
    *vertices++ = { (cosf(rad)*radius) + offsetX,           ( sinf(rad)*radius) + offsetY,            0,  1};
    *vertices++ = { (cosf(rad)*radius) + offsetX,           (-sinf(rad)*radius) + offsetY,            0,  1};
    *vertices++ = { (-1.f*radius) + offsetX,                ( 0.f*radius) + offsetY,                  0,  1};

    *numVertices = (int) (((intptr_t)vertices - (intptr_t)verticesOrig) / sizeof(vertices[0]));
}

void FSTUFF_MakeCircleTriangleStrip(gbVec4 * vertices, int maxVertices, int * numVertices, int numPartsToGenerate,
                                    float innerRadius, float outerRadius)
{
    // TODO: check the size of the vertex buffer!
    const float kRadianStep = ((((float)M_PI) * 2.0f) / (float)numPartsToGenerate);
    *numVertices = 2 + (numPartsToGenerate * 2);
    for (unsigned i = 0; i <= numPartsToGenerate; ++i) {
        vertices[(i * 2) + 0] = {COS_IDX(i)*innerRadius, SIN_IDX(i)*innerRadius, 0, 1};
        vertices[(i * 2) + 1] = {COS_IDX(i)*outerRadius, SIN_IDX(i)*outerRadius, 0, 1};
    }
}

void FSTUFF_MakeCircleLineStrip(gbVec4 * vertices, int maxVertices, int * numVertices, int numPartsToGenerate,
                                float radius)
{
    // TODO: check the size of the vertex buffer!
    const float kRadianStep = ((((float)M_PI) * 2.0f) / (float)numPartsToGenerate);
    *numVertices = (numPartsToGenerate + 1);
    for (unsigned i = 0; i <= numPartsToGenerate; ++i) {
        vertices[i] = {COS_IDX(i)*radius, SIN_IDX(i)*radius, 0, 1};
    }
}

void FSTUFF_ShapeInit(FSTUFF_Shape * shape, FSTUFF_Renderer * renderer)
{
    // Generate vertices in CPU-accessible memory
//    vector_float4 vertices[2048];
    gbVec4 vertices[2048];
    const size_t maxElements = FSTUFF_countof(vertices);
    bool didSet = false;
    
    //
    // Circles
    //
    if (shape->type == FSTUFF_ShapeCircle) {
        if (shape->appearance == FSTUFF_ShapeAppearanceEdged) {
            didSet = true;
#if 0
            shape->primitiveType = FSTUFF_PrimitiveTriangleFan;
            FSTUFF_MakeCircleTriangleStrip(vertices, maxElements, &shape->numVertices, shape->circle.numParts,
                                           0.9,     // inner radius
                                           1.0);    // outer radius
#else
            shape->primitiveType = FSTUFF_PrimitiveLineStrip;
            FSTUFF_MakeCircleLineStrip(vertices, maxElements, &shape->numVertices, shape->circle.numParts,
                                       1.0);        // radius
#endif
        } else if (shape->appearance == FSTUFF_ShapeAppearanceFilled) {
            didSet = true;
            shape->primitiveType = FSTUFF_PrimitiveTriangles;
            FSTUFF_MakeCircleFilledTriangles(vertices, maxElements, &shape->numVertices, shape->circle.numParts, 1.f, 0.f, 0.f);
        }
    }
    
    //
    // Boxes
    //
    else if (shape->type == FSTUFF_ShapeBox) {
        if (shape->appearance == FSTUFF_ShapeAppearanceEdged) {
            didSet = true;
            shape->primitiveType = FSTUFF_PrimitiveLineStrip;
            shape->numVertices = 5;
            vertices[0] = {-.5f,  .5f,  0, 1};
            vertices[1] = { .5f,  .5f,  0, 1};
            vertices[2] = { .5f, -.5f,  0, 1};
            vertices[3] = {-.5f, -.5f,  0, 1};
            vertices[4] = {-.5f,  .5f,  0, 1};
        } else if (shape->appearance == FSTUFF_ShapeAppearanceFilled) {
            didSet = true;
            shape->primitiveType = FSTUFF_PrimitiveTriangleFan;
            shape->numVertices = 4;
            vertices[0] = {-.5f, -.5f, 0, 1};
            vertices[1] = {-.5f,  .5f, 0, 1};
            vertices[2] = { .5f, -.5f, 0, 1};
            vertices[3] = { .5f,  .5f, 0, 1};
        }
    }
    else if (shape->type == FSTUFF_ShapeDebug) {
        didSet = true;
        shape->primitiveType = FSTUFF_PrimitiveTriangles;
        shape->numVertices = 3;
        vertices[0] = {10.f, 10.f, 0.f, 1.f};
        vertices[1] = {30.f, 10.f, 0.f, 1.f};
        vertices[2] = {30.f, 30.f, 0.f, 1.f};
    }

    if (didSet) {
        shape->gpuVertexBuffer = renderer->NewVertexBuffer(vertices,
                                                           shape->numVertices * sizeof(gbVec4));
    } else {
        shape->gpuVertexBuffer = NULL;
    }
}


#pragma mark - Simulation

static const size_t kNumSubSteps = 10;
const cpFloat kStepTimeS = 1./60.;          // step time, in seconds



#define SPACE           (this->world.physicsSpace)

//#define BODY(IDX)       (&this->world.bodies[(IDX)])
//#define CIRCLE(IDX)     (&(this->world.circles[(IDX)]))
//#define BOX(IDX)        (&(this->world.boxes[(IDX)]))

//#define BODY_ALLOC()    (BODY(this->world.numBodies++))
//#define CIRCLE_ALLOC()  (CIRCLE(this->world.numCircles++))
//#define BOX_ALLOC()     (BOX(this->world.numBoxes++))
//
//#define CIRCLE_IDX(VAL) ((((uintptr_t)(VAL)) - ((uintptr_t)(&this->world.circles[0]))) / sizeof(sim->world.circles[0]))
//#define BOX_IDX(VAL)    ((((uintptr_t)(VAL)) - ((uintptr_t)(&this->world.boxes[0]))) / sizeof(sim->world.boxes[0]))


void FSTUFF_Simulation::InitGPUShapes()
{
    //
    // GPU init
    //
    this->circleFilled.debugName = "FSTUFF_CircleFilled";
    this->circleFilled.type = FSTUFF_ShapeCircle;
    this->circleFilled.appearance = FSTUFF_ShapeAppearanceFilled;
    this->circleFilled.circle.numParts = kNumCircleParts;
    FSTUFF_ShapeInit(&(this->circleFilled), this->renderer);

    this->circleDots.debugName = "FSTUFF_CircleDots";
    this->circleDots.type = FSTUFF_ShapeCircle;
    this->circleDots.appearance = FSTUFF_ShapeAppearanceFilled;
    this->circleDots.circle.numParts = kNumCircleParts;
    this->circleDots.primitiveType = FSTUFF_PrimitiveTriangles;
    {
        gbVec4 vertices[2048];
        const int numCirclePartsForDot = 6;
        const float dotRadius = 0.08f;  // size of dot: 0 to 1; 0 is no-size, 1 is as big as containing-circle
        const float dotDistance = 0.7f; // from 0 to 1
        int tmpVertexCount;
        this->circleDots.numVertices = 0;
        for (int i = 0, n = 6; i < n; ++i) {
            const float rad = float(i) * ((M_PI * 2.f) / float(n));
            FSTUFF_MakeCircleFilledTriangles(
                &vertices[this->circleDots.numVertices],
                0,
                &tmpVertexCount,
                numCirclePartsForDot,
                dotRadius,
                cosf(rad) * dotDistance,
                sinf(rad) * dotDistance
            );
            this->circleDots.numVertices += tmpVertexCount;
        }
        this->circleDots.gpuVertexBuffer = this->renderer->NewVertexBuffer(vertices, (this->circleDots.numVertices * sizeof(gbVec4)));
    }

    this->circleEdged.debugName = "FSTUFF_CircleEdged";
    this->circleEdged.type = FSTUFF_ShapeCircle;
    this->circleEdged.appearance = FSTUFF_ShapeAppearanceEdged;
    this->circleEdged.circle.numParts = kNumCircleParts;
    FSTUFF_ShapeInit(&(this->circleEdged), this->renderer);

    this->boxFilled.debugName = "FSTUFF_BoxEdged";
    this->boxFilled.type = FSTUFF_ShapeBox;
    this->boxFilled.appearance = FSTUFF_ShapeAppearanceFilled;
    FSTUFF_ShapeInit(&(this->boxFilled), this->renderer);
    
    this->boxEdged.debugName = "FSTUFF_BoxEdged";
    this->boxEdged.type = FSTUFF_ShapeBox;
    this->boxEdged.appearance = FSTUFF_ShapeAppearanceEdged;
    FSTUFF_ShapeInit(&(this->boxEdged), this->renderer);

    this->debugShape.debugName = "FSTUFF_DebugShape";
    this->debugShape.type = FSTUFF_ShapeDebug;
    this->debugShape.appearance = FSTUFF_ShapeAppearanceFilled;
    FSTUFF_ShapeInit(&(this->debugShape), this->renderer);
}

void FSTUFF_Simulation::InitWorld()
{
    //
    // Physics-world init
    //
    memset(&this->world, 0, sizeof(FSTUFF_Simulation::World));
    //sim->world.physicsSpace = (cpSpace *) &(sim->world._physicsSpaceStorage);
    //cpSpaceInit(sim->world.physicsSpace);
    this->world.physicsSpace = cpSpaceNew();
    
    cpSpaceSetIterations(this->world.physicsSpace, 2);
    cpSpaceSetGravity(this->world.physicsSpace, this->gravity);
    // TODO: try resizing cpSpace hashes
    //cpSpaceUseSpatialHash(this->world.physicsSpace, 2, 10);

    cpBody * body;
    cpShape * shape;
    
    
    //
    // Walls
    //

    body = cpBodyInit(NewBody(), 0, 0);
    cpBodySetType(body, CP_BODY_TYPE_STATIC);
    cpSpaceAddBody(SPACE, body);
    cpBodySetPosition(body, cpv(0, 0));
    static const cpFloat wallThickness = 5.0;
    static const cpFloat wallLeft   = -wallThickness / 2.;
    static const cpFloat wallRight  = this->viewSizeMM.x + (wallThickness / 2.);
    static const cpFloat wallBottom = -wallThickness / 2.;
    static const cpFloat wallTop    = this->viewSizeMM.y * 2.;   // use a high ceiling, to make sure off-screen falling things don't go over walls
    
    // Bottom
    shape = (cpShape*)cpSegmentShapeInit(NewBox(), body, cpv(wallLeft,wallBottom), cpv(wallRight,wallBottom), wallThickness/2.);
    cpSpaceAddShape(SPACE, shape);
    cpShapeSetElasticity(shape, 0.8);
    cpShapeSetFriction(shape, 1);
    this->world.boxColors[IndexOfBox(shape)] = FSTUFF_Color(0x000000, 0x00);
    // Left
    shape = (cpShape*)cpSegmentShapeInit(NewBox(), body, cpv(wallLeft,wallBottom), cpv(wallLeft,wallTop), wallThickness/2.);
    cpSpaceAddShape(SPACE, shape);
    cpShapeSetElasticity(shape, 0.8);
    cpShapeSetFriction(shape, 1);
    this->world.boxColors[IndexOfBox(shape)] = FSTUFF_Color(0x000000, 0x00);
    // Right
    shape = (cpShape*)cpSegmentShapeInit(NewBox(), body, cpv(wallRight,wallBottom), cpv(wallRight,wallTop), wallThickness/2.);
    cpSpaceAddShape(SPACE, shape);
    cpShapeSetElasticity(shape, 0.8);
    cpShapeSetFriction(shape, 1);
    this->world.boxColors[IndexOfBox(shape)] = FSTUFF_Color(0x000000, 0x00);


    //
    // Pegs
    //
    using namespace FSTUFF_Colors;
    const int pegColors[] = {
        Red,
        Red,
        Lime,
        Lime,
        Blue,
        Blue,
        Yellow,
        Cyan,
    };
    const int numPegs = round((this->viewSizeMM.x * this->viewSizeMM.y) * 0.0005);
    const cpFloat kPegScaleCircle = 2.5;
    const cpFloat kPegScaleBox = 4.;
    cpFloat cx, cy, radius, w, h, angleRad;
    int pegColorIndex;
    for (int i = 0; i < numPegs; ++i) {
        switch (rand() % 2) {
            case 0:
            {
                cx = FSTUFF_RandRangeF(this->rng, 0., this->viewSizeMM.x);
                cy = FSTUFF_RandRangeF(this->rng, 0., this->viewSizeMM.y);
                radius = kPegScaleCircle * FSTUFF_RandRangeF(this->rng, 6., 10.);
                pegColorIndex = FSTUFF_RandRangeI(this->rng, 0, FSTUFF_countof(pegColors)-1);

                body = cpBodyInit(NewBody(), 0, 0);
                cpBodySetType(body, CP_BODY_TYPE_STATIC);
                cpSpaceAddBody(SPACE, body);
                cpBodySetPosition(body, cpv(cx, cy));
                shape = (cpShape*)cpCircleShapeInit(NewCircle(), body, radius, cpvzero);
                ++this->world.numPegs;
                cpSpaceAddShape(SPACE, shape);
                cpShapeSetElasticity(shape, 0.8);
                cpShapeSetFriction(shape, 1);
                this->world.circleColors[IndexOfCircle(shape)] = FSTUFF_Color(pegColors[pegColorIndex]);
            } break;
            
            case 1:
            {
                cx = FSTUFF_RandRangeF(this->rng, 0., this->viewSizeMM.x);
                cy = FSTUFF_RandRangeF(this->rng, 0., this->viewSizeMM.y);
                w = kPegScaleBox * FSTUFF_RandRangeF(this->rng, 6., 14.);
                h = kPegScaleBox * FSTUFF_RandRangeF(this->rng, 1., 2.);
                angleRad = FSTUFF_RandRangeF(this->rng, 0., M_PI);
                pegColorIndex = FSTUFF_RandRangeI(this->rng, 0, FSTUFF_countof(pegColors)-1);
            
                body = cpBodyInit(NewBody(), 0, 0);
                cpBodySetType(body, CP_BODY_TYPE_STATIC);
                cpSpaceAddBody(SPACE, body);
                cpBodySetPosition(body, cpv(cx, cy));
                cpBodySetAngle(body, angleRad);
                shape = (cpShape*)cpSegmentShapeInit(NewBox(), body, cpv(-w/2.,0.), cpv(w/2.,0.), h/2.);
                cpSpaceAddShape(SPACE, shape);
                cpShapeSetElasticity(shape, 0.8);
                this->world.boxColors[IndexOfBox(shape)] = FSTUFF_Color(pegColors[pegColorIndex]);
            } break;
        }
    }
    
//    for (int i = 0; i < 1500; i++) {
//        this->AddMarble();
//    }
}

void FSTUFF_Simulation::AddMarble()
{
    FSTUFF_Simulation * sim = this;
    cpBody * body = cpBodyInit(NewBody(), 0, 0);
    cpSpaceAddBody(SPACE, body);
    const cpFloat marbleRadius = FSTUFF_RandRangeF(sim->rng, sim->marbleRadius_Range[0], sim->marbleRadius_Range[1]);
    cpBodySetPosition(body, cpv(FSTUFF_RandRangeF(sim->rng, marbleRadius, sim->viewSizeMM.x - marbleRadius), sim->viewSizeMM.y * 1.1));
    cpShape * shape = (cpShape*)cpCircleShapeInit(NewCircle(), body, marbleRadius, cpvzero);
    cpSpaceAddShape(sim->world.physicsSpace, shape);
    cpShapeSetDensity(shape, 10);
    cpShapeSetElasticity(shape, 0.8);
    cpShapeSetFriction(shape, 1);
    sim->world.circleColors[IndexOfCircle(shape)] = FSTUFF_Color(FSTUFF_Colors::White);
    sim->marblesCount += 1;
}


void FSTUFF_Simulation::Init() //, void * gpuDevice, void * nativeView)
{
    FSTUFF_Log("%s, this:%p, state:%d, renderer:%p\n",
        __FUNCTION__, this, this->state, this->renderer);
    
    if ( ! this->renderer) {
        throw std::runtime_error("FSTUFF_Simulation's 'renderer' field must be set, before calling its Init() method!");
    }
    
    // Don't re-initialize simulations that are already alive
    if (this->state != FSTUFF_DEAD) {
        return;
    }

    // Preserve OS-native resource handles, within 'this'
    FSTUFF_Renderer * renderer = this->renderer;

    // Reset all variables in 'this'
    *this = FSTUFF_Simulation();

    // Mark simulation as alive
    this->state = FSTUFF_ALIVE;

    // Restore OS-native resource handles, to 'this'
    this->renderer = renderer;

    // Initialize 'this'
    float widthMM = 0.f;
    float heightMM = 0.f;
    this->renderer->GetViewSizeMM(&widthMM, &heightMM);
    this->ViewChanged(widthMM, heightMM);
    this->InitGPUShapes();
    this->InitWorld();
}

void FSTUFF_Simulation::ResetWorld()
{
    this->ShutdownWorld();
    this->InitWorld();
}

void FSTUFF_Simulation::Update()
{
    // Initialize the simulation, if need be.
    if (this->state == FSTUFF_DEAD) {
        this->Init();
    }

    // Compute current time
    cpFloat nowS;           // current time, in seconds since UNIX epoch
    struct timeval nowSys;  // used to get current time from OS
    gettimeofday(&nowSys, NULL);
    nowS = (cpFloat)nowSys.tv_sec + ((cpFloat)nowSys.tv_usec / 1000000.);
    
    // Initialize simulation time vars, on first tick
    if (this->lastUpdateUTCTimeS == 0.) {
        this->lastUpdateUTCTimeS = nowS;
    }
    
    // Compute delta-time
    const double deltaTimeS = nowS - this->lastUpdateUTCTimeS;
    this->elapsedTimeS += deltaTimeS;
    
    // Add marbles, as warranted
    if (this->marblesCount < this->marblesMax) {
        if (this->addMarblesInS > 0) {
            this->addMarblesInS -= deltaTimeS;
            if (this->addMarblesInS <= 0) {
                this->AddMarble();
                this->addMarblesInS = FSTUFF_RandRangeF(this->rng, this->addMarblesInS_Range[0], this->addMarblesInS_Range[1]);
            }
        }
    }
    
    // Update physics
    const cpFloat kSubstepTimeS = kStepTimeS / ((cpFloat)kNumSubSteps);
    while ((this->lastUpdateUTCTimeS + kStepTimeS) <= nowS) {
        for (size_t i = 0; i < kNumSubSteps; ++i) {
            this->lastUpdateUTCTimeS += kSubstepTimeS;
            cpSpaceStep(SPACE, kSubstepTimeS);
        }
    }
    
    // Reset world, if warranted
    if (this->marblesCount >= this->marblesMax) {
        if (this->resetInS_default > 0) {
            if (this->resetInS <= 0) {
                this->resetInS = this->resetInS_default;
            } else {
                this->resetInS -= deltaTimeS;
            }
        }
        if (this->resetInS <= 0) {
            this->marblesCount = 0;
            this->ResetWorld();
        }
    }

    // Copy simulation/game data to GPU-accessible buffers
    this->renderer->SetProjectionMatrix(this->projectionMatrix);
    for (size_t i = 0; i < this->world.numCircles; ++i) {
        cpFloat shapeRadius = cpCircleShapeGetRadius((cpShape*)GetCircle(i));
        cpBody * body = cpShapeGetBody((cpShape*)GetCircle(i));
        cpVect bodyCenter = cpBodyGetPosition(body);
        cpFloat bodyAngle = cpBodyGetAngle(body);
        
        gbMat4 dest, tmp;
        gb_mat4_identity(&dest);
        gb_mat4_translate(&tmp, {(float)bodyCenter.x, (float)bodyCenter.y, 0.});
        dest *= tmp;
        gb_mat4_rotate(&tmp, {0., 0., 1.}, bodyAngle);
        dest *= tmp;
        gb_mat4_scale(&tmp, {(float)shapeRadius, (float)shapeRadius, 1});
        dest *= tmp;

        this->renderer->SetShapeProperties(FSTUFF_ShapeCircle, i, dest, this->world.circleColors[i]);
    }
    for (size_t i = 0; i < this->world.numBoxes; ++i) {
        cpVect a = cpSegmentShapeGetA((cpShape*)GetBox(i));
        cpVect b = cpSegmentShapeGetB((cpShape*)GetBox(i));
        cpVect center = cpvlerp(a, b, 0.5);
        cpFloat radius = cpSegmentShapeGetRadius((cpShape*)GetBox(i));
        cpBody * body = cpShapeGetBody((cpShape*)GetBox(i));
        cpVect bodyCenter = cpBodyGetPosition(body);
        cpFloat bodyAngle = cpBodyGetAngle(body);

        gbMat4 dest, tmp;
        gb_mat4_identity(&dest);
        gb_mat4_translate(&tmp, {(float)bodyCenter.x, (float)bodyCenter.y, 0.});
        dest *= tmp;
        gb_mat4_rotate(&tmp, {0., 0., 1.}, bodyAngle);
        dest *= tmp;
        gb_mat4_translate(&tmp, {(float)center.x, (float)center.y, 0.});
        dest *= tmp;
        gb_mat4_rotate(&tmp, {0., 0., 1.}, cpvtoangle(b-a));
        dest *= tmp;
        gb_mat4_scale(&tmp, {(float)cpvlength(b-a), (float)(radius*2.), 1.});
        dest *= tmp;
        
        this->renderer->SetShapeProperties(FSTUFF_ShapeBox, i, dest, this->world.boxColors[i]);
    }
    
/*
	self.unlit_peg_fill_alpha_min = 0.25
	self.unlit_peg_fill_alpha_max = 0.45

 pb.fill_alpha = rand_in_range(self.unlit_peg_fill_alpha_min, self.unlit_peg_fill_alpha_max)
*/
}

void FSTUFF_Simulation::Render()
{
    renderer->RenderShapes(&circleFilled, 0,             world.numCircles,                 0.35f);
    renderer->RenderShapes(&circleDots,   world.numPegs, world.numCircles - world.numPegs, 1.0f);
    renderer->RenderShapes(&circleEdged,  0,             world.numCircles,                 1.0f);
    renderer->RenderShapes(&boxFilled,    0,             world.numBoxes,                   0.35f);
    renderer->RenderShapes(&boxEdged,     0,             world.numBoxes,                   1.0f);

//    renderer->RenderShapes(&debugShape, 0, 1, 1.0f);
}

void FSTUFF_Simulation::ViewChanged(float widthMM, float heightMM)
{
    this->viewSizeMM = {widthMM, heightMM};

    gbMat4 translation;
    gb_mat4_translate(&translation, {-1, -1, 0});
    
    gbMat4 scaling;
    gb_mat4_scale(&scaling, {2.0f / widthMM, 2.0f / heightMM, 1});
    
    this->projectionMatrix = translation * scaling;
}

void FSTUFF_Simulation::ShutdownWorld()
{
    for (size_t i = 0; i < this->world.numCircles; ++i) {
        cpShapeDestroy((cpShape*)GetCircle(i));
    }
    for (size_t i = 0; i < this->world.numBoxes; ++i) {
        cpShapeDestroy((cpShape*)GetBox(i));
    }
    for (size_t i = 0; i < this->world.numBodies; ++i) {
        cpBodyDestroy(GetBody(i));
    }
    //cpSpaceDestroy(this->world.physicsSpace);
    cpSpaceFree(this->world.physicsSpace);
}

void FSTUFF_Simulation::ShutdownGPU()
{
    if (this->circleDots.gpuVertexBuffer) {
        this->renderer->DestroyVertexBuffer(this->circleDots.gpuVertexBuffer);
    }
    if (this->circleEdged.gpuVertexBuffer) {
        this->renderer->DestroyVertexBuffer(this->circleEdged.gpuVertexBuffer);
    }
    if (this->circleFilled.gpuVertexBuffer) {
        this->renderer->DestroyVertexBuffer(this->circleFilled.gpuVertexBuffer);
    }
    if (this->boxEdged.gpuVertexBuffer) {
        this->renderer->DestroyVertexBuffer(this->boxEdged.gpuVertexBuffer);
    }
    if (this->boxFilled.gpuVertexBuffer) {
        this->renderer->DestroyVertexBuffer(this->boxFilled.gpuVertexBuffer);
    }
}

//void FSTUFF_Shutdown(FSTUFF_Simulation * sim)
//{
//    sim->ShutdownWorld();
//    sim->ShutdownGPU();
//    sim->~FSTUFF_Simulation();
//    ::operator delete(sim);
//}


#pragma mark - Input Events

FSTUFF_Event FSTUFF_Event::NewKeyEvent(FSTUFF_EventType eventType, const char * utf8Char)
{
    FSTUFF_Event event;
    memset(&event, 0, sizeof(event));
    event.type = eventType;
    const size_t srcSize = strlen(utf8Char) + 1;
    const size_t copySize = std::min(sizeof(event.data.key.utf8), srcSize);
    strlcpy(const_cast<char *>(event.data.key.utf8), utf8Char, copySize);
    return event;
}

void FSTUFF_Simulation::EventReceived(FSTUFF_Event *event)
{
    switch (event->type) {
        case FSTUFF_EventNone: {
        } break;
        case FSTUFF_EventKeyDown: {
            switch (std::toupper(event->data.key.utf8[0])) {
                case 'R': {
                    this->ShutdownWorld();
                    this->InitWorld();
                    event->handled = true;
                } break;
            }
        } break;
    }
}