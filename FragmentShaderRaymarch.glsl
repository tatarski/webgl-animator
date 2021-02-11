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
//    float distToCyllinder = length(p.xz);
//    if(abs(p.y) > height) {
//        if(distToCyllinder > radius) {
//            return length(vec2(distToCyllinder - radius, p.y - height));
//        } else {
//            return abs(p.y) - height;
//        }
//    } else {
//        return distToCyllinder - radius;
//    }
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
struct BasicObject {
    vec3 translate;
    vec4 localRot;
    vec3 scale;
    int type;
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
    
const int MAX_MARCHING_STEPS = 300;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.001;
const float PI = 3.14159265359;

out vec4 myOutputColor;
uniform float iCameraDist;

// Object loading from js
//const int MAX_OBJECTS = 7;
const int OBJECTS_MAX = 3;
//uniform int uObjectsN;
uniform BasicObject uObjects[OBJECTS_MAX];
//BasicObject sceneObjects[MAX_OBJECTS];

// Local definitions of objects to be added to sceneObjectsArray

// Fill array with BasicObjects
//void initLocalObjects() {
//    BasicObject groundPlane = BasicObject(vec3(0., 15., 0.), vec3(0., 0., 0.), vec3(1., 1., 1.), 0, vec3(1., 0., 0.));
//    BasicObject cube1 = BasicObject(vec3(0., -6. + 6.*sin(iTime), 0.), vec3(iTime, 0., 0.), vec3(2., 2., 2.), 1, vec3(0., 1., 0.));
//    BasicObject sphere1 = BasicObject(vec3(0., -6., 0.), vec3(0., 0., 0.), vec3(1., 1., 1.), 2, vec3(0., 0., 1.));
//    BasicObject sphere2 = BasicObject(vec3(-3., -6., 0.), vec3(0., 0., 0.), vec3(1., 1., 1.), 2, vec3(1., 1., 1.));
//    BasicObject sphere3 = BasicObject(vec3(3., -6., 0.), vec3(0., 0., 0.), vec3(1., 1., 1.), 2, vec3(0., 1., 1.));
//    BasicObject sphere4 = BasicObject(vec3(0., -6., -3.), vec3(0., 0., 0.), vec3(1., 1., 1.), 2, vec3(1., 0., 1.));
//    BasicObject sphere5 = BasicObject(vec3(0., -6., 3.), vec3(0., 0., 0.), vec3(1., 1., 1.), 2, vec3(1., 0.5, 0.3));
//
//    sceneObjects[0] = groundPlane;
//    sceneObjects[1] = cube1;
//    sceneObjects[2] = sphere1;
//    sceneObjects[3] = sphere2;
//    sceneObjects[4] = sphere3;
//    sceneObjects[5] = sphere4;
//    sceneObjects[6] = sphere5;
//}

////// Trying to load custom object positions from js
//vec3 extractProperty(int i, int n) {
//    return texture(u_geometry_tex, vec2(float(n)/64., float(i)/64.)).xyz;
//}
//
//void extractObjectsFromTexture() {
//    for(int i = 0; i < MAX_OBJECTS; i++) {
//        sceneObjects[i] = BasicObject(
//            extractProperty(i, 2),
//            extractProperty(i, 1),
//            extractProperty(i, 0),
//            int(extractProperty(i, 3).x),
//            extractProperty(i, 4));
//    }
//}


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
vec3 rotateP(vec3 p, vec4 localRot) {
    //localRot.z is ignored
    return rotateY(rotateZ(rotateY(p, localRot.x), localRot.y), localRot.w);
}

vec3 scale(vec3 p, vec3 s) {
    return vec3(p.x*s.x, p.y*s.y, p.z*s.z);
}
vec3 applyObjectState(BasicObject obj, vec3 p) {
    // TODO: add rot YZ
    vec3 p_trans = translate(p, obj.translate);
    
    vec3 p_rot = rotateP(p_trans, obj.localRot);
    return translate(p_rot, obj.offset);
}
// Get SD to union of all scene objects
vec4 getObjectsUnionSD(vec3 p) {
    float minDist = MAX_DIST;
    int minI = -1;
    for(int i = 0; i < OBJECTS_MAX; i++) {
        float sceneSDF;
        vec3 p_obj_transform = applyObjectState(uObjects[i], p);
        if(uObjects[i].type == 0) {
            sceneSDF = planeY_SDF(p_obj_transform);
        }
        if(uObjects[i].type == 1) {
            sceneSDF = boxSD(p_obj_transform, uObjects[i].scale);
        }
        if(uObjects[i].type == 2) {
            sceneSDF = sphereSD(p_obj_transform, uObjects[i].scale.x);
        }
        if(sceneSDF < minDist) {
            minDist = sceneSDF;
            minI = i;
        }
    }
    return vec4(uObjects[minI].color, minDist);
}

/*
Signed distance function that represents the whole scene
Positive distance => outside
0 => on the surface
Negative distance => inside
*/
vec4 sceneSDF(vec3 p) {
    return getObjectsUnionSD(p);
}


/**
 * Return the shortest distance from the eyepoint to the scene surface along
 * the marching direction. If no part of the surface is found between start and end,
 * return end.
 * 
 * eye: the eye point, acting as the origin of the ray
 * marchingDirection: the normalized direction to march in
 * start: the starting distance away from the eye
 * end: the max distance away from the ey to march before giving up
 */
// X: distance, y: minDistance
vec4 shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) {
    float depth = start;
    float minDist = end;
    vec3 minColor = vec3(0., 0. ,0.);
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        vec4 res = sceneSDF(eye + depth * marchingDirection);
        float dist = res.w;
        vec3 curColor = res.xyz;
        if(dist < minDist) {
            minDist = dist;
            minColor = curColor;
        }
        if (dist < EPSILON) {
			return vec4(minColor, depth);
        }
        depth += dist;
        if (depth >= end) {
            return vec4(minColor, end);
        }
    }
    return vec4(minColor, end);
}
/**
 * Return the normalized direction to march in from the eye point for a single pixel.
 * 
 * fieldOfView: vertical field of view in degrees
 * size: resolution of the output image
 * fragCoord: the x,y coordinate of the pixel in the output image
 */
vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

// Normal of scene surface at point p
vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)).w - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)).w,
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)).w - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)).w,
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)).w - sceneSDF(vec3(p.x, p.y, p.z - EPSILON)).w
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


// Get color with phong lighting
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

void main() {
//    uObjects;
//    initObjects();
//    loadObjects();
    
    // Old functions for object loading
//    extractObjectsFromTexture();
//    initLocalObjects();
    
    uViewMatrix;
    iCameraDist;
    uModelMatrix;
    vec2 fragCoord = (vXY + 0.5) *512.;
    vec3 viewDir = rayDirection(uFOV, uRes, fragCoord);
    vec3 eye = vec3(cos(iTime/20.)*iCameraDist, iCameraDist/2., sin(iTime/20.)*iCameraDist);
    
    mat4 viewToWorld = viewMatrix(uEye, uFocus, uUp);
//    mat4 viewToWorld = uViewMatrix;
    
    vec3 worldDir = (viewToWorld*vec4(viewDir, 0.0)).xyz;
    
    vec4 res = shortestDistanceToSurface(uEye, worldDir, MIN_DIST, MAX_DIST);
    float dist = res.w;
    vec3 c = res.xyz;
    
    
//    myOutputColor = texture(u_geometry_tex, (vec2(vXY.x, -vXY.y)/2.) + 0.5);
//    myOutputColor = vec4(extractProperty(int(1), int(4)), 1.);
//    return;
    if (dist > MAX_DIST - EPSILON) {
        myOutputColor = vec4(0.4, 0.4, 0.8, 1.);
        return;
    }
    
    // The closest point on the surface to the eyepoint along the view ray
    vec3 p = uEye + dist * worldDir;
    
    vec3 K_a = c;
    vec3 K_d = vec3(0.7, 0.7, 0.7);
    vec3 K_s = vec3(0.6, 0.6, 0.6);
    float shininess = 20.;
    
    vec3 color = phongLighting(K_a, K_d, K_s, shininess, p, uEye, c);
    
    myOutputColor = vec4(color, 1.0);
}

////// Old code below


//float sceneSDF_OLD(vec3 p) {
//              // Rotation    // Translation
//    vec3 p_r = rotateX(p/2., PI/2.);
//    vec3 p_t_1 = p - vec3(3., 3., 3.);
//    vec3 p_t_2 = p - vec3(-3., 3., -3.);
//    vec3 p_torus = p - vec3(0., 6., 0.);
//    vec3 p_torus2 = p - vec3(0., 2., 0.);
//    vec3 p_sphere= p - vec3(sin(iTime)*3.,  3. + 3.*cos(iTime/20.), cos(iTime)*3.);
////    vec3 p_t = twist(p);
//    return unionSDF(
////                roundSDF(cubeSDF(p_t), 0.1),
////                cyllinderSDF(p_t, 1., 2.),
////                roundSDF(cyllinderSDF(p_t, 0.5, 1.), 0.2),
//        smin(unionSDF(unionSDF(
//            smin(roundSDF(cubeSDF(p_r, vec3(2., 2., 1.)), 0.2),  -torusWavesSDF(p_torus2, 1., 5.), -0.5),
//            torusWavesSDF(p_torus, 1., 4.)),
//                 unionSDF(
//                     cyllinderSDF(p_t_1, 0.4, 3.),
//                     cyllinderSDF(p_t_2, 0.4, 3.)
//                 )),
//             -sphereSDF(p_sphere, 2.), -1.),
//        planeY_SDF(wobble(p) + 10.)
//    );
//}
