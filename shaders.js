var vShader =
    'uniform mat4 uProjectionMatrix;' +
    'uniform mat4 uViewMatrix;' +
    'uniform mat4 uModelMatrix;' +
    'uniform mat4 uNormalMatrix;' +
    'uniform bool uUseNormalMatrix;' +
    '' +
    'uniform vec3 uAmbientColor;' +
    'uniform vec3 uDiffuseColor;' +
    '' +
    'uniform vec3 uLightDir;' +
    '' +
    'attribute vec3 aXYZ;' +
    'attribute vec3 aColor;' +
    'attribute vec3 aNormal;' +
    '' +
    'varying vec3 vColor;' +
    '' +
    'void main ()' +
    '{' +
    '	mat4 mvMatrix = uViewMatrix * uModelMatrix;' +
    '	gl_Position = uProjectionMatrix * mvMatrix * vec4(aXYZ,1);' +
    '	mat4 nMatrix = uUseNormalMatrix?uNormalMatrix:mvMatrix;' +
    '' +
    '	vColor = uAmbientColor*aColor;' +
    '' +
    '	vec3 light = normalize(-uLightDir);' +
    '	vec3 normal = vec3(normalize(nMatrix*vec4(aNormal,0)));' +
    '	vColor += aColor*uDiffuseColor*max(dot(normal,light),0.0);' +
    '}';

var fShader =
    'precision mediump float;' +
    'varying vec3 vColor;' +
    'void main( )' +
    '{' +
    '	gl_FragColor = vec4(vColor,1);' +
    '}';
var vShaderPhong =
    'uniform mat4 uProjectionMatrix;' +
    'uniform mat4 uViewMatrix;' +
    'uniform mat4 uModelMatrix;' +
    'uniform mat4 uNormalMatrix;' +
    'uniform bool uUseNormalMatrix;' +
    '' +
    'uniform vec3 uAmbientColor;' +
    'uniform vec3 uDiffuseColor;' +
    '' +
    'uniform vec3 uLightDir;' +
    '' +
    'attribute vec3 aXYZ;' +
    'attribute vec3 aColor;' +
    'attribute vec3 aNormal;' +
    '' +
    'varying vec3 vColor;' +
    'varying vec3 vNormal;' +
    'varying vec3 vPos;' +
    '' +
    'void main ()' +
    '{' +
    '	mat4 mvMatrix = uViewMatrix * uModelMatrix;' +
    '	vec4 pos = mvMatrix * vec4(aXYZ,1);' +
    '	gl_Position = uProjectionMatrix * pos;' +
    '	mat4 nMatrix = uUseNormalMatrix?uNormalMatrix:mvMatrix;' +
    '' +
    '	vColor = uAmbientColor*aColor;' +
    '' +
    '	vec3 light = normalize(-uLightDir);' +
    '	vec3 normal = vec3(normalize(nMatrix*vec4(aNormal,0)));' +
    '	vColor += aColor*uDiffuseColor*max(dot(normal,light),0.0);' +
    '' +
    '	vPos = pos.xyz/pos.w;' +
    '	vNormal = normal;' +
    '}';

var fShaderPhong =
    'precision mediump float;' +
    '' +
    'uniform highp vec3 uLightDir;' +
    'uniform vec3 uSpecularColor;' +
    'uniform float uShininess;' +
    '' +
    'varying vec3 vNormal;' +
    'varying vec3 vColor;' +
    'varying vec3 vPos;' +
    '' +
    'void main( )' +
    '{' +
    '	vec3 specularColor = vec3(0);' +
    '' +
    '	vec3 light = normalize(-uLightDir);' +
    '	vec3 reflectedLight = normalize(reflect(light,normalize(vNormal)));' +
    '	vec3 viewDir = normalize(vPos);' +
    '' +
    '	float cosa = max(dot(reflectedLight,viewDir),0.0);' +
    '	specularColor = uSpecularColor*pow(cosa,uShininess);' +
    '' +
    '	gl_FragColor = vec4(vColor+specularColor,1);' +
    '}';

var vShaderRaymarch = `#version 300 es
    in vec2 aXY;
    out vec2 vXY;
    void main() {
        vXY = aXY;
        gl_Position = vec4(aXY, 0., 1.);
    }
`
var fShaderDrawOnCanvas = `#version 300 es
    precision mediump float;

    in vec2 vXY;
    uniform sampler2D uTexUnit;
    out vec4 myOutputColor;

    void main() {
        myOutputColor = texture(uTexUnit, gl_FragCoord.xy/512.);
//        if(gl_FragCoord.x > 256.) {
//            gl_FragColor = vec4(1., 0., 0., 1.);
//        } else {
//            gl_FragColor = vec4(0., 0., 1., 1.);
//        }
    }
`;
var fShaderRaymarch = `
    precision mediump float;
    uniform float uUpdates;

    uniform float near;
    uniform float far;

    uniform mat4 uViewMatrix;
    uniform mat4 uModelMatrix;
    mat4 mvMatrix = uViewMatrix*uModelMatrix;

    varying vec2 vXY;
    const int MAX_MARCHING_STEPS = 1000;
    const float EPSILON = 1.;

    

    vec3 SPHERE_CENTER_1 = (mvMatrix*vec4(0., 0., 0., 1.)).xyz;
    float SPHERE_RADIUS_1 = 100.;
    vec3 SPHERE_CENTER_2 = (mvMatrix*vec4(50. + cos(uUpdates/200.)*200., -220. + 20., -40. + -0.*cos(uUpdates/500.), 1.)).xyz;
    float SPHERE_RADIUS_2 = 70.;
    vec3 SPHERE_CENTER_3 = (mvMatrix*vec4(0. + cos(uUpdates/100.)*40., 0., -100. + -0.*cos(uUpdates/500.), 1.)).xyz;
    float SPHERE_RADIUS_3 = 100.;
    vec3 SPHERE_CENTER_4 = (mvMatrix*vec4(50. + cos(uUpdates/200.)*200., -20. + 20., -40. + -0.*cos(uUpdates/500.), 1.)).xyz;
    float SPHERE_RADIUS_4 = 70.;
    vec3 SPHERE_CENTER_5 = (mvMatrix*vec4(0. + cos(uUpdates/100.)*40., 220., -100. + -0.*cos(uUpdates/500.), 1.)).xyz;
    float SPHERE_RADIUS_5 = 100.;
    vec3 SPHERE_CENTER_6 = (mvMatrix*vec4(50. + cos(uUpdates/200.)*200., 220. + 20., -40. + -0.*cos(uUpdates/500.), 1.)).xyz;
    float SPHERE_RADIUS_6 = 70.;

    vec3 BOX_BOUNDS_1 = vec3(100., 100., 100.);
    float smin(float a, float b, float k) {
        float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
        return mix(a, b, h) - k*h*(1.0-h);
    }
    float UDBox(vec3 p, vec3 size) {
        return length(max(abs(p)- size, 0.));
    }
    float sdBox(vec3 p, vec3 b )
    {
         vec3 q = abs(p) - b;
         return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
    }
    float SDFSphere(vec3 pos, vec3 center, float radius) {
        return length(center-pos) - radius;
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
    
    float SDF(vec3 pos) {
        float smin_coef = 100.*abs(sin(uUpdates/10.));
        return sdBox((mvMatrix*vec4(pos,1.)).xyz, BOX_BOUNDS_1);
        return SDFSphere(pos, SPHERE_CENTER_1, SPHERE_RADIUS_1);
        return min(min(smin(SDFSphere(pos, SPHERE_CENTER_1, SPHERE_RADIUS_1),
                    -SDFSphere(pos, SPHERE_CENTER_2, SPHERE_RADIUS_2),
                    -smin_coef),
                    smin(SDFSphere(pos, SPHERE_CENTER_3, SPHERE_RADIUS_3),
                        SDFSphere(pos, SPHERE_CENTER_4, SPHERE_RADIUS_4),
                        smin_coef)),
                    smin(SDFSphere(pos, SPHERE_CENTER_5, SPHERE_RADIUS_5),
                        SDFSphere(pos, SPHERE_CENTER_6, SPHERE_RADIUS_6),
                        -smin_coef));
    }
    vec2 getDepthFreq(vec3 viewRayDirection, float start, float end) {
        float depth = start;
        float minDist = 999999.;
        for(int i = 0; i < MAX_MARCHING_STEPS; i++) {
            float dist = SDF(depth*viewRayDirection);
            if(minDist >= dist) {
                minDist = dist;
            }
            if(dist < EPSILON) {
                return vec2(depth, minDist);
            }
            depth += dist;
            if(depth >= end) {
                return vec2(end, minDist);
            }
        }
        return vec2(end, minDist);
    }
    vec3 estNormal(vec3 p) {
        return normalize(
            vec3(
            SDF(vec3(p.x + EPSILON, p.y, p.z)) - SDF(vec3(p.x - EPSILON, p.y, p.z)),
            SDF(vec3(p.x, p.y + EPSILON, p.z)) - SDF(vec3(p.x, p.y-EPSILON, p.z)),
            SDF(vec3(p.x , p.y, p.z + EPSILON)) - SDF(vec3(p.x , p.y, p.z - EPSILON))
            )
        );
    }
    void main() {
uViewMatrix;
uModelMatrix;
        vec3 ambientColor = vec3(0.3, 0.3, 0.3);
        vec3 diffuseColor = vec3(0.9, 0.9, 0.9);
        vec3 specularColor = vec3(1., 1., 1.);
        vec3 mainColor = vec3(1., 0.7, 0.);

        vec3 rayDirection = normalize(vec3(vXY*400., near));
        vec2 dMinDist = getDepthFreq(rayDirection, near, far);
        float d = dMinDist.x;
        float minDist = dMinDist.y;
        vec3 colPos = d*rayDirection;
        float uShininess = 20.;
        vec3 color = mainColor;

        uUpdates; 

        // Ambient lighting
        color *= ambientColor;
        
        // Diffuse lighting
        vec3 light_dir = vec3(0.3, 0.5, 1.);
        vec3 light = normalize(-light_dir);
        vec3 normal = estNormal(colPos);
        color += mainColor*diffuseColor*max(dot(normal,light), 0.);
        
        // Specular lighting
        vec3 reflectedLight = normalize(reflect(light,normalize(normal)));
        vec3 viewDir = normalize(rayDirection);
        float cosa = max(dot(reflectedLight,viewDir),0.0);
        vec3 specColor = specularColor*pow(cosa,uShininess);

        if(!(d < far)) {
            if(abs(minDist) < 5.) {
                gl_FragColor = vec4(0., 0., 0., 1.);
            }else {
                gl_FragColor = vec4(0.9, 0.9, 0.9, 1.);
            }
        } else {
            gl_FragColor = vec4(color + specColor, 1.);
        }
    }
`;
