#version 300 es

precision mediump float;

//// Utility functions

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

/////// Basic SD object functions
// Sphere
float sphereSD(vec3 p, float rad) {
    return length(p) - rad;
}
// plane parral XZ 
float planeY_SDF(vec3 p) {
    return p.y;
}
// round SD to object
// Draw the surface that is a distance of 'h' from the surface 'd' 
float roundSD(float d, float h) {
    return d - h;
}
float intersectSDF(float distA, float distB) {
    return max(distA, distB);
}
float unionSDF(float distA, float distB) {
    return min(distA, distB);
}
float differenceSDF(float distA, float distB) {
    return max(distA, -distB);
}
// Smooth minimum
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
    return mix(a, b, h) - k*h*(1.0-h);
}

// Cube with length 2
float cubeSD(vec3 p, vec3 s) {
    vec3 q = abs(p) - s;
            // Distance outside    // Distance inside
    return length(max(q, 0.)) + min(max(q.x,max(q.y,q.z)),0.0);
}


float cyllinderSDF(vec3 p, float radius, float height) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(radius, height);
    return min(max(d.x, d.y), 0.) + length(max(d, 0.));
}

float torusSDF(vec3 p, float ringRadius, float torusRadius) {
    vec2 d = vec2(length(p.xz) - torusRadius, p.y);
    return length(d) - ringRadius;
}
float torusWavesSDF(vec3 p, float ringRadius, float torusRadius) {
    float aTorus = atan(p.x, p.z);
    vec2 d = vec2(length(p.xz) - torusRadius, p.y);
    float aRing = atan(d.x, d.y);
    
    return length(d) - (ringRadius + sin(aTorus*30.)*cos(aRing*15.)*0.1);
}
float torusEngravingSDF(vec3 p, float ringRadius, float torusRadius) {
    float aTorus = atan(p.x, p.z);
    vec2 d = vec2(length(p.xz) - torusRadius, p.y);
    float aRing = atan(d.x, d.y);
    
    return length(d) - ringRadius;
}
float boxSD(vec3 p, vec3 b){
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}
float SDFSphere(vec3 pos, vec3 center, float radius) {
    return length(center-pos) - radius;
}

///// Object on scene
// types of objects:
// 0. plane
// 1. Cuboid
// 2. Sphere
// 3. Reflective Sphere
struct BasicObject {
    int type;
    vec3 pos;
    vec3 scale;
    vec3 rot;
    vec3 color;
    vec3 offset;
};


/////// Uniforms and constants
uniform sampler2D u_texture;

uniform float iTime;

uniform mat4 uViewMatrix;
uniform mat4 uModelMatrix;

uniform vec3 uEye;
uniform vec3 uFocus;
uniform vec3 uUp;

uniform float uFOV;
uniform vec2 uRes;

in vec2 vXY;
    
const int MAX_MARCHING_STEPS = 150;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.01;
const float PI = 3.14159265359;

out vec4 myOutputColor;
uniform float iCameraDist;

// Object to loading from js
const int OBJECTS_MAX = OBJECTS_MAX_TOKEN;
//uniform int uObjectsN;
uniform BasicObject uObjects[OBJECTS_MAX];
// Sd transformations
vec3 translate(vec3 p, vec3 d) {
    return p + d;
}

vec3 twist(vec3 p) {
    float k  = 0.2;
    float c = cos(k*p.z);
    float s = sin(k*p.z);
    // 2d Rotation matrix
    mat2 m = mat2(c, -s, s, c);
    return vec3(m*p.xy, p.z);
}
vec3 wobble(vec3 p) {
    return vec3(p.x, p.y + 5.*cos(p.x/10.)*sin(p.z/10.), p.z);
}

// X rot
vec3 rotateX(vec3 p, float angle) {
    mat3 rotationMatrix = mat3(1., 0., 0., 0., cos(angle), -sin(angle), 0., sin(angle), cos(angle));
    return p*rotationMatrix;
}
// Y rot
vec3 rotateY(vec3 p, float angle) {
    mat3 rotationMatrix = mat3(cos(angle), 0., sin(angle), 0., 1., 0., -sin(angle), 0., cos(angle));
    return p*rotationMatrix;
}
// Z rot
vec3 rotateZ(vec3 p, float angle) {
    mat3 rotationMatrix = mat3(cos(angle), -sin(angle), 0., sin(angle), cos(angle), 0., 0., 0., 1.);
    return p*rotationMatrix;
}

//    =====>
// Apply Y, Z, Z rotations
         //yaw,pitch, roll 
vec3 rotateP(vec3 p, vec3 localRot) {
    //localRot.z is ignored
    return rotateY(rotateZ(rotateY(p, localRot.x), localRot.y), localRot.z);
}

vec3 scale(vec3 p, vec3 s) {
    return vec3(p.x*s.x, p.y*s.y, p.z*s.z);
}
vec3 applyObjectState(BasicObject obj, vec3 p) {
    vec3 p_trans = translate(p, obj.pos);
    vec3 p_rot = rotateP(p_trans, obj.rot);
    vec3 p_scale = scale(p_rot, obj.scale);
    
    return translate(p_scale, obj.offset);
}
// Holds object index
int closestObjectIndex = -1;
// Returns distance
float getClosestObject(vec3 p) {
    float minDist = MAX_DIST;
    closestObjectIndex = -1;
    // Union on 3d objects: min(O1, O2, O3, ...)
    for(int i = 0; i < OBJECTS_MAX; i++) {
        float sceneSDF;
        vec3 p_obj_transform = applyObjectState(uObjects[i], p);
        if(uObjects[i].type == 0) {
            sceneSDF = planeY_SDF(p_obj_transform);
        }
        if(uObjects[i].type == 1) {
            sceneSDF = boxSD(p_obj_transform, vec3(0.5, 0.5, 0.5));
        }
        if(uObjects[i].type == 2) {
            sceneSDF = sphereSD(p_obj_transform, 0.5);
        }
        if(sceneSDF < minDist) {
            minDist = sceneSDF;
            closestObjectIndex = i;
        }
    }
    return minDist;
}

float sceneSDF(vec3  p) {
    return getClosestObject(p);
}

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

vec3 phongLightSingle(vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye,
                          vec3 lightPos, vec3 lightIntensity) {
    vec3 N = estimateNormal(p),
        L = normalize(lightPos - p),
        V = normalize(eye - p),
        R = normalize(reflect(-L, N));
    
    float dotLN = dot(L, N);
    float dotRV = dot(R, V);
    
    if (dotLN < 0.0) {
        // Light not visible from this point on the surface
        return vec3(0.0, 0.0, 0.0);
    } 
    
    if (dotRV < 0.0) {
        // Light reflection in opposite direction as viewer, apply only diffuse
        // component
        return lightIntensity * (k_d * dotLN);
    }
    return lightIntensity * (k_d * dotLN + k_s * pow(dotRV, alpha));
}

vec3 phongLighting(vec3 k_a, vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye, vec3 k_obj) {
    vec3 ambientLight = 0.5 * vec3(1., 1., 1.);
    vec3 color = ambientLight * k_a;
    
    vec3 light1Pos = vec3(10.0 * sin(iTime/20.),
                          10.0,
                          10.0 * cos(iTime/20.));
    
    vec3 light1Intensity = vec3(0.6, 0.6, 0.6);
    
    color += phongLightSingle(
        k_d,
        k_s,
        alpha,
        p,
        eye,
        light1Pos,
        light1Intensity);
    
//    vec3 light2Pos = vec3(0.,
//                          0.2,
//                          0.);
//    vec3 light2Intensity = vec3(0.4, 0.4, 0.4);
//    
//    color += phongLightSingle(k_d, k_s, alpha, p, eye,light2Pos,light2Intensity);    
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
void main() {
    uViewMatrix;
    iCameraDist;
    uModelMatrix;
    vec2 fragCoord = (vXY + 0.5) *512.;
    vec3 viewDir = rayDirection(uFOV, uRes, fragCoord);
    
    mat4 viewToWorld = viewMatrix(uEye, uFocus, uUp);
    
    vec3 worldDir = (viewToWorld*vec4(viewDir, 0.0)).xyz;
    
   float dist = raymarchDepth(uEye, worldDir, MIN_DIST, MAX_DIST);
    // Out of bounds or no closest object found
    if(closestObjectIndex == -1 || dist > MAX_DIST){
        myOutputColor = vec4(0.4, 0.4, 0.8, 1.);
        return;
    }
    // PHONG LIGHTING FROM ONE LIGHT
    vec3 p = uEye + dist * worldDir;
    vec3 K_a = uObjects[closestObjectIndex].color;
    vec3 K_d = vec3(0.7, 0.7, 0.7);
    vec3 K_s = vec3(0.6, 0.6, 0.6);
    float shininess = 20.;
    
    vec3 color = phongLighting(K_a, K_d, K_s, shininess, p, uEye, uObjects[closestObjectIndex].color);
    myOutputColor = vec4(color, 1.0);
    
    return;

}