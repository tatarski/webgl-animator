#version 300 es
in vec2 aXY;
out vec2 vXY;
void main() {
    vXY = aXY;
    gl_Position = vec4(aXY, 0., 1.);
}
