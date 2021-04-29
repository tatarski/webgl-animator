#version 300 es

precision mediump float;


// Constants
const int MAX_MARCHING_STEPS = 150;
const float MIN_DIST = 0.0;
const float MAX_DIST = 30.0;
const float EPSILON = 0.01;
const float PI = 3.14159265359;
in vec2 vXY;
out vec4 myOutputColor;

uniform float iCameraDist;
// Passed time
uniform float iTime;
// Eye
uniform vec3 uEye;
// Focus
uniform vec3 uFocus;
// Up
uniform vec3 uUp;
// FOV
uniform float uFOV;
// Resolution
uniform vec2 uRes;

uniform bool uUseAmbient;
uniform bool uUseDiffuse;
uniform bool uUseSpecular;

/////Slow: Object on scene
// types of objects:
// 0. plane
// 1. Cuboid
// 2. Sphere
// 3. Torus waves
// 4. Torus
//struct BasicObject {
//    int type;
//    vec3 pos;
//    vec3 scale;
//    // Local Yaw/roll/pitch rotation
//    vec3 rot;
//    vec3 color;
//    vec3 offset;
//};

// token will be replaced by integer
//const int OBJECTS_MAX = OBJECTS_MAX_TOKEN;
//uniform BasicObject uObjects[OBJECTS_MAX];


// Global variables
// Holds index of object from uObjects
int closestObjectIndex = -1;
// Is an object from uObjects hit
bool closestObjectCollision = false;
// Whether or not to calculate phong lighting 
bool usePhongLighting = false;
vec3 viewDir;
mat4 viewToWorld;
vec3 worldDir;
vec3 lightPos;

mat4 viewMatrix(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat4(
        vec4(s, 0.0),
        vec4(u, 0.0),
        vec4(-f, 0.0),
        vec4(0.0, 0.0, 0.0, 1)
    );
}


//// Distance to basic 3d object

// Dist to sphere 
float sphere(vec3 p, float rad) {
    return length(p) - rad;
}
// Dist to plane parral XZ 
float planeY(vec3 p) {
    return p.y;
}
// Draw the surface that is a distance of 'h' from the original surface
float roundd(float d, float h) {
    return d - h;
}
// Dist to cube
float cube(vec3 p, vec3 b){
    vec3 q = abs(p) - b;
            // Distance outside
    return length(max(q,0.0));
}

// Dist to cyllinder
float cyllinder(vec3 p, float radius, float height) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(radius, height);
    return length(max(d, 0.));
}

// Dist to torus
float torus(vec3 p, float ringRadius, float torusRadius) {
    vec2 d = vec2(length(p.xz) - torusRadius, p.y);
    return length(d) - ringRadius;
}

// Dist to torus with waves
float torus2(vec3 p, float ringRadius, float torusRadius) {
    float aTorus = atan(p.x, p.z);
    vec2 d = vec2(length(p.xz) - torusRadius, p.y);
    float aRing = atan(d.x, d.y);
    
    return length(d) - (ringRadius + sin(aTorus*10.)*cos(aRing*5.)*0.1);
}


//// Combination of 3d objects

float intersect(float distA, float distB) {
    return max(distA, distB);
}
float unionn(float distA, float distB) {
    return min(distA, distB);
}
float difference(float distA, float distB) {
    return max(distA, -distB);
}
// Smooth minimum
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
    return mix(a, b, h) - k*h*(1.0-h);
}

//// Transformations with points
vec3 translate(vec3 p, vec3 d) {
    return p + d;
}


vec3 wobble(vec3 p) {
    return vec3(p.x, p.y + 5.*cos(p.x/10.)*sin(p.z/10.), p.z);
}

// X axis rot
vec3 rotateX(vec3 p, float angle) {
    mat3 rotationMatrix = mat3(1., 0., 0., 0., cos(angle), -sin(angle), 0., sin(angle), cos(angle));
    return p*rotationMatrix;
}
// Y axis rot
vec3 rotateY(vec3 p, float angle) {
    mat3 rotationMatrix = mat3(cos(angle), 0., sin(angle), 0., 1., 0., -sin(angle), 0., cos(angle));
    return p*rotationMatrix;
}
// Z axis rot
vec3 rotateZ(vec3 p, float angle) {
    mat3 rotationMatrix = mat3(cos(angle), -sin(angle), 0., sin(angle), cos(angle), 0., 0., 0., 1.);
    return p*rotationMatrix;
}

// Apply Y  ,Z    ,Y    rotations
//       yaw,pitch,roll 
vec3 rotateP(vec3 p, vec3 localRot) {
    return rotateY(rotateZ(rotateY(p, localRot.x), localRot.y), localRot.z);
}

vec3 scale(vec3 p, vec3 s) {
    return vec3(p.x*s.x, p.y*s.y, p.z*s.z);
}
float sphereField(vec3 p, float r, float offset) {
    return length(mod(p, vec3(2.*r)) - r) - r;
}


//// uObjects utility functions
// Apply object state on point
//vec3 applyObjectState(BasicObject obj, vec3 p) {
//    vec3 p_trans = translate(p, obj.pos);
//    vec3 p_rot = rotateP(p_trans, obj.rot);
//    vec3 p_scale = scale(p_rot, obj.scale);
//    
//    return translate(p_scale, obj.offset);
//}

// Returns distance to closest member of uObjects
//float getClosestObject(vec3 p) {
//    float minDist = MAX_DIST;
//    closestObjectIndex = -1;
//    closestObjectCollision = false;
//    // Union on 3d objects: min(O1, O2, O3, ...)
//    for(int i = 0; i < OBJECTS_MAX; i++) {
//        float sceneSDF;
//        vec3 p_obj_transform = applyObjectState(uObjects[i], p);
//        if(uObjects[i].type == 0) {
//            sceneSDF = planeYDist(p_obj_transform);
//        }
//        if(uObjects[i].type == 1) {
//            sceneSDF = cubeDist(p_obj_transform, vec3(0.5, 0.5, 0.5));
//        }
//        if(uObjects[i].type == 2) {
//            sceneSDF = sphereDist(p_obj_transform, 0.5);
//        }
//        if(uObjects[i].type == 3) {
//            sceneSDF = torusWavesSDF(p_obj_transform, 0.3, 1.);
//        }
//        if(uObjects[i].type == 4) {
//            sceneSDF = torusSDF(p_obj_transform, 0.3, 1.);
//        }
//        if(sceneSDF < minDist) {
//            minDist = sceneSDF;
//            closestObjectIndex = i;
//            if(sceneSDF < EPSILON) {
//                closestObjectCollision = true;
//            }
//        }
//    }
//    return minDist;
//}

// Returns distance of closest const object
//float getClosestConstObject(vec3 p) {
//    float dist = max(sphereDist(translate(p, vec3(5., -5., 2.)), 3.),
//                sphereDist(translate(p, vec3(7., -5., 0.)), 4.));
//    if(dist < EPSILON) {
//        usePhongLighting = true;
//    }
//    return dist;
//}
float sceneSDF(vec3  p) {
    return TOKEN_FORMULA;
    //return min(getClosestConstObject(p), getClosestObject(p));
}

// Get ray direction by given pixel x,y
vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

// Normal of scene surface at point p
vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

// Calculates phong lighting by given color and point in world view (transformed with viewToWorld)
vec3 calculatePhongLighting(vec3 colorObj, vec3 p) {
    vec3 ambientColor = vec3(0.5, 0.5, 0.5),
        diffuseColor = vec3(0.4, 0.4, 0.4),
        specularColor = vec3(0.6, 0.6, 0.6),
        lightPos_ = lightPos,
        normal = estimateNormal(p),
        lightDir = normalize(lightPos_-p);
    
    float shininess = 5.;
    vec3 color = vec3(0, 0, 0);
    
    if(uUseAmbient) {
        color += ambientColor*colorObj;
    }
    if(uUseDiffuse) {
        color += colorObj* diffuseColor * max(dot(normal, lightDir), 0.);
    }
    if(uUseSpecular) {
        vec3 reflectedLightRay = normalize(reflect(normal, lightDir));
        float cosa=max(dot(reflectedLightRay, worldDir), 0.);
        color+=ambientColor*specularColor*pow(cosa, shininess);
    }
    return color;
}

//Returns depth and fill closestObjectIndex
float raymarchDepth(vec3 p, vec3 dir, float begin_depth, float max_depth) {
    float depth = begin_depth;
    for(int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sceneSDF(p + depth*dir);
        if(dist > max_depth - EPSILON) {
            return depth;
        }
        if(dist < EPSILON) {
            return depth;
        }
        // We can safely march with distance to closest Object
        depth += dist;
    }
    return depth;
}
//vec4 selectColor(float dist) {
//    // Out of bounds or no closest object found
//    if(closestObjectIndex == -1 || dist > MAX_DIST){
//        return vec4(0.4, 0.4, 0.8, 1.);
//    }
//    
//    vec3 colorHit = uObjects[closestObjectIndex].color;
//    // No collision with any object from uObjects
//    // But still in screen bounds
//    // Collision with const object
//    if(!closestObjectCollision && usePhongLighting) {
//        colorHit = vec3(0.3, 0.9, 0.3);
//    }
//    
//    // Unobstructed distance that could be marched towards the light
//    vec3 pHit = uEye + worldDir*(dist-EPSILON);
//
//    // Raymarch towards light
//    float maxDistToLight = abs(length(lightPos - pHit));
//    float distToLight = raymarchDepth(pHit, normalize(lightPos-pHit), MIN_DIST, maxDistToLight);
//    // Shadows
//    
//    vec3 color = calculatePhongLighting(colorHit, uEye + dist*worldDir);
//    if(distToLight < maxDistToLight - EPSILON) {
//        float k = -log(1.-distToLight/maxDistToLight);
//        return vec4(sin(k)*color + sin(1.-k)*vec3(0, 0, 0), 0.);
//    }
//    return vec4(color, 1.);
//}
void main() {
    vec2 fragCoord = (vXY + 0.5) * uRes;
    viewDir = rayDirection(uFOV, uRes, fragCoord);
    viewToWorld = viewMatrix(uEye, uFocus, uUp);
    worldDir = (viewToWorld*vec4(viewDir, 0.0)).xyz;
    
    lightPos = vec3(0., 6., 10.);
    iTime;
    float depth = raymarchDepth(uEye, worldDir, MIN_DIST, MAX_DIST);
    // Which color has been hit
    vec3 colorHit = vec3(0.8,0.4,.4);
    vec3 pHit = uEye + worldDir*(depth-EPSILON*20.);
    float maxDistToLight = abs(length(lightPos - pHit));
    float distToLight = raymarchDepth(pHit, normalize(lightPos-pHit), MIN_DIST, maxDistToLight);
//    // Shadows
//    
    vec3 color = calculatePhongLighting(colorHit, uEye + depth*worldDir);
    if(distToLight < maxDistToLight - EPSILON) {
        float k = -log(1.-distToLight/maxDistToLight);
        myOutputColor = vec4(0.3*color, 1.);
    } else {
        myOutputColor = vec4(calculatePhongLighting(colorHit, uEye + depth*worldDir), 1.);
    }
    return;

}
