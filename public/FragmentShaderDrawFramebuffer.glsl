#version 300 es
precision mediump float;

in vec2 vXY;
uniform sampler2D uTexUnit;
out vec4 myOutputColor;

void main() {
    myOutputColor = texture(uTexUnit, gl_FragCoord.xy/512.);
}