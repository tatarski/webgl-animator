// Does not work
// Functions for raymarching in js
function lengthV(v) {
    return Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

function add(p, p2) {
    let res = [];
    for (let i = 0; i < p.length; i++) {
        res[i] = p[i] + p2[i];
    }
    return res;
}
// Sum of vector
function sum(p) {
    let res = 0;
    for (let i = 0; i < p.length; i++) {
        res += p[i];
    }
    return res;
}

// Transpose matrix
function transpose(mat) {
    let res = [];
    for (let i = 0; i < mat[0].length; i++) {
        res[i] = [];
    }
    for (let i = 0; i < mat.length; i++) {
        for (let j = 0; j < mat[i].length; j++) {
            res[j][i] = mat[i][j];
        }
    }
    return res;
}

// Dist to sphere 
function sphereDist(p, rad) {
    return lengthV(p) - rad;
}
// Dist to plane parral XZ 
function planeYDist(p) {
    return p[1];
}
// Draw the surface that is a distance of 'h' from the original surface
function roundDist(d, h) {
    return d - h;
}

function absV(v) {
    return [Math.abs(v[0]), Math.abs(v[1]), Math.abs(v[2])];
}

function maxV(v1, n) {
    return [Math.max(v[0], n), Math.max(v[1], n), Math.max(v[2], n)]
}

function scaleV(v1, v2) {
    return [v1[0] * v2[0], v1[1] * v2[1], v1[2] * v2[2]]
}
// Dist to cube
function cubeDist(p, b) {
    let q = add(absV(p), scaleV(b, [-1, -1, -1]));
    // Distance outside
    return length(max(q, 0.0));
}

//// Combination of 3d objects
function intersectDist(distA, distB) {
    return Math.max(distA, distB);
}

function unionDist(distA, distB) {
    return Math.min(distA, distB);
}

function differenceDist(distA, distB) {
    return Math.max(distA, -distB);
}


//// Transformations with points
function translate(p, d) {
    return add(p, d);
}

// Multiply two matricies
function multiplyMat(mat1, mat2) {
    let t_mat2 = transpose(mat2);
    let res = [];
    for (let i = 0; i < mat1.length; i++) {
        res[i] = [];
        for (let j = 0; j < t_mat2.length; j++) {
            res[i][j] = sum(scaleV(mat1[i], t_mat2[j]));
        }
    }
    return res;
}
// X rot
function rotateX(p, angle) {
    let rotationMatrix = [
                [1., 0., 0.],
                [0., cos(angle), -sin(angle)],
                [0., sin(angle), cos(angle)]
            ];
    return multiplyMat([p], rotationMatrix)[0];
}
// Y rot
function rotateY(p, angle) {
    let rotationMatrix = [
                [cos(angle), 0., sin(angle)],
                [0., 1., 0.],
                [-sin(angle), 0., cos(angle)]
            ];

    return multiplyMat([p], rotationMatrix)[0];
}
// Z rot
function rotateZ(p, angle) {
    let rotationMatrix = [
                [cos(angle), -sin(angle), 0.],
                [sin(angle), cos(angle), 0.],
                [0., 0., 1.]
            ];

    return multiplyMat([p], rotationMatrix)[0];
}
//    =====>
// Apply Y, Z, Y rotations
//yaw,pitch, roll 
function rotateP(p, localRot) {
    //localRot.z is ignored
    return rotateY(rotateZ(rotateY(p, localRot[0]), localRot[1]), localRot[2]);
}

function toRad(deg) {
    return deg / 57.2957795;
}

function scale(p, s) {
    return scaleV(p, s);
}

function normalize(v) {
    return [v[0] / lengthV(v), v[2] / lengthV(v), v[1] / lengthV(v)]
}
// Does not work
class rayMarchMouse {
    constructor() {}
    rayDirection(fieldOfView, size, x, y) {
        return normalize([x - size[0] / 2, y - size[1] / 2, -size[1] / Math.tan(toRad(fieldOfView) / 2)])
    }

    raymarch() {
        let MAX_MARCHING_STEPS = 150;
        let EPSILON = 0.01;
        let depth = begin_depth;
        for (let i = 0; i < MAX_MARCHING_STEPS; i++) {
            let dist = this.sceneSDF(p + scaleV(dir, depth));
            if (dist > max_depth - EPSILON) {
                return depth;
            }
            if (dist < EPSILON) {
                return depth;
            }
            // We can safely march with distance to closest Object
            depth += dist;
        }
        return depth;
    }
    distanceToObjects(p) {
        let minDist = 9999999;
        // Union on 3d objects: min(O1, O2, O3, ...)
        for (let i = 0; i < OBJECTS_MAX; i++) {
            let sceneSDF;
            let p_obj_transform = this.applyObjectState(p, i);
            if (uObjects[i].type == 0) {
                sceneSDF = planeYDist(p_obj_transform);
            }
            if (uObjects[i].type == 1) {
                sceneSDF = cubeDist(p_obj_transform, vec3(0.5, 0.5, 0.5));
            }
            if (uObjects[i].type == 2) {
                sceneSDF = sphereDist(p_obj_transform, 0.5);
            }
            if (sceneSDF < minDist) {
                minDist = sceneSDF;
            }
        }
        return minDist;
    }

    applyObjectState(p, i) {
        return translate(rotateP(p, basicObjectList[i].rot), basicObjectList[i].pos);
    }
}
