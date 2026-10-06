import { createLensMap } from '@liquefy-ui/core';

// WebKit cannot apply Liquefy's SVG displacement to a backdrop-filter. Reuse
// the package's actual lens map and sample the captured backdrop in WebGL instead.
const vertex = `#version 300 es
in vec2 position;
out vec2 uv;
void main() { uv = position * .5 + .5; gl_Position = vec4(position, 0., 1.); }`;
const fragment = `#version 300 es
precision highp float;
in vec2 uv;
out vec4 color;
uniform sampler2D backdrop;
uniform sampler2D lens;
uniform vec2 size;
uniform float displacement;
uniform float frost;
vec3 softened(vec2 point, float level) { return textureLod(backdrop, point, level).rgb; }
void main() {
  vec2 point = vec2(uv.x, 1. - uv.y);
  vec2 bend = (texture(lens, point).rg - .5) * displacement / size;
  vec2 sampleAt = point + bend;
  vec2 stepSize = vec2(frost) / size;
  float level = log2(max(1., frost * .75 * float(textureSize(backdrop, 0).x) / size.x));
  vec3 sampleColor = softened(sampleAt, level) * .24;
  sampleColor += softened(sampleAt + vec2(stepSize.x, 0.), level) * .12;
  sampleColor += softened(sampleAt - vec2(stepSize.x, 0.), level) * .12;
  sampleColor += softened(sampleAt + vec2(0., stepSize.y), level) * .12;
  sampleColor += softened(sampleAt - vec2(0., stepSize.y), level) * .12;
  sampleColor += softened(sampleAt + stepSize, level) * .07;
  sampleColor += softened(sampleAt - stepSize, level) * .07;
  sampleColor += softened(sampleAt + vec2(stepSize.x, -stepSize.y), level) * .07;
  sampleColor += softened(sampleAt + vec2(-stepSize.x, stepSize.y), level) * .07;
  color = vec4(sampleColor, 1.);
}`;

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error('The local backdrop image could not be decoded.'));
    image.src = url;
  });
}

export class NativeOptics {
  constructor(canvas) {
    this.canvas = canvas;
    this.frames = 0;
    this.darkBackdrop = null;
    this.sample = document.createElement('canvas'); this.sample.width = 1; this.sample.height = 1;
    this.revision = 0;
    this.gl = canvas.getContext('webgl2', { alpha: false, antialias: false, preserveDrawingBuffer: true });
    if (!this.gl) throw new Error('WebGL 2 is unavailable.');
    const gl = this.gl;
    const compile = (type, source) => {
      const shader = gl.createShader(type);
      gl.shaderSource(shader, source); gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
      return shader;
    };
    this.program = gl.createProgram();
    for (const [type, source] of [[gl.VERTEX_SHADER, vertex], [gl.FRAGMENT_SHADER, fragment]]) {
      const shader = compile(type, source); gl.attachShader(this.program, shader); gl.deleteShader(shader);
    }
    gl.linkProgram(this.program);
    if (!gl.getProgramParameter(this.program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(this.program));
    gl.useProgram(this.program);
    const buffer = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 1,-1, -1,1, -1,1, 1,-1, 1,1]), gl.STATIC_DRAW);
    const position = gl.getAttribLocation(this.program, 'position');
    gl.enableVertexAttribArray(position); gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
    this.textures = [0, 1].map(unit => {
      const texture = gl.createTexture(); gl.activeTexture(gl.TEXTURE0 + unit); gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      return texture;
    });
    gl.uniform1i(gl.getUniformLocation(this.program, 'backdrop'), 0);
    gl.uniform1i(gl.getUniformLocation(this.program, 'lens'), 1);
    this.uniforms = Object.fromEntries(['size','displacement','frost'].map(name => [name, gl.getUniformLocation(this.program, name)]));
  }

  async configure(properties) {
    this.properties = properties;
    const width = Math.max(4, Math.round(innerWidth));
    const height = Math.max(4, Math.round(innerHeight));
    const key = `${width}/${height}/${properties.radius}`;
    if (this.key !== key) {
      this.key = key;
      const revision = ++this.revision;
      const map = createLensMap({ width, height, radius: properties.radius, bezel: 30, curve: 2.4, strength: .92 });
      if (!map) throw new Error('Liquefy could not create its lens map.');
      const image = await loadImage(map.url);
      if (revision !== this.revision) return;
      this.map = map;
      this.upload(image, 1);
    }
    this.draw();
  }

  upload(image, unit) {
    const gl = this.gl;
    gl.activeTexture(gl.TEXTURE0 + unit); gl.bindTexture(gl.TEXTURE_2D, this.textures[unit]);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
    if (unit === 0) gl.generateMipmap(gl.TEXTURE_2D);
  }

  async updateFrame(url) {
    const image = await loadImage(url);
    const context = this.sample.getContext('2d', { willReadFrequently: true });
    context.drawImage(image, 0, 0, 1, 1);
    const [r,g,b] = context.getImageData(0,0,1,1).data;
    const luminance = (r*.2126 + g*.7152 + b*.0722) / 255;
    if (this.darkBackdrop === null) this.darkBackdrop = luminance < .5;
    else if (luminance < .4) this.darkBackdrop = true;
    else if (luminance > .6) this.darkBackdrop = false;
    this.upload(image, 0); this.hasBackdrop = true; this.frames++;
    this.draw();
  }

  draw() {
    if (!this.map || !this.hasBackdrop || !this.properties) return;
    const {width, height} = this.map;
    const scale = Math.min(devicePixelRatio || 1, 2);
    if (this.canvas.width !== Math.round(width * scale)) this.canvas.width = Math.round(width * scale);
    if (this.canvas.height !== Math.round(height * scale)) this.canvas.height = Math.round(height * scale);
    const gl = this.gl; gl.useProgram(this.program); gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    gl.uniform2f(this.uniforms.size, width, height);
    gl.uniform1f(this.uniforms.displacement, this.properties.reduceTransparency ? 0 : this.map.scale);
    gl.uniform1f(this.uniforms.frost, 4.5 + (1 - this.properties.transparency) * 6);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }
}
