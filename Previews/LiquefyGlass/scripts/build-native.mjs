import { build } from 'vite';
import react from '@vitejs/plugin-react';
import { createHash } from 'node:crypto';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const project = resolve(import.meta.dirname, '..');
const repository = resolve(project, '../..');
const output = resolve(repository, 'Resources/LiquefyGlass');
const result = await build({ configFile: false, root: project, plugins: [react()], define: { 'process.env.NODE_ENV': '"production"' },
  build: { write: false, minify: true, lib: { entry: resolve(project, 'native/surface.jsx'), name: 'HuiDictLiquefy', formats: ['iife'] } } });
const files = (Array.isArray(result) ? result : [result]).flatMap(item => item.output);
const script = files.filter(item => item.type === 'chunk').map(item => item.code).join('\n');
const css = files.filter(item => item.fileName.endsWith('.css')).map(item => item.source).join('\n');
const html = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; connect-src 'none'"><style>${css}</style></head><body><canvas id="backdrop"></canvas><div id="surface"></div><script>${script.replace(/<\/script/gi, '<\\/script')}</script></body></html>`;
const digest = data => createHash('sha256').update(data).digest('hex');
const inputs = {};
for (const file of ['native/surface.jsx', 'native/surface.css', 'native/optics.js', 'scripts/build-native.mjs', 'package.json', 'package-lock.json']) {
  inputs[`Previews/LiquefyGlass/${file}`] = digest(await readFile(resolve(project, file)));
}
const licences = [];
const packages = {};
const bundledPackages = new Set(files.filter(item => item.type === 'chunk').flatMap(chunk =>
  Object.entries(chunk.modules).filter(([id, info]) => id.includes('/node_modules/') && info.renderedLength > 0)
    .map(([id]) => { const parts = id.split('/node_modules/').at(-1).split('/'); return parts[0].startsWith('@') ? parts.slice(0, 2).join('/') : parts[0]; })));
for (const name of [...bundledPackages].sort()) {
  const pkg = JSON.parse(await readFile(resolve(project, `node_modules/${name}/package.json`), 'utf8'));
  const license = await readFile(resolve(project, `node_modules/${name}/LICENSE`), 'utf8');
  licences.push(`${name} ${pkg.version}\n${pkg.repository?.url || pkg.homepage || ''}\n\n${license}`);
  packages[name] = pkg.version;
}
const notices = `HuiDict's embedded Liquefy glass surface\n\n${licences.join('\n\n' + '='.repeat(80) + '\n\n')}`;
await mkdir(output, { recursive: true });
await writeFile(resolve(output, 'surface.html'), html);
await writeFile(resolve(output, 'ThirdPartyNotices.txt'), notices);
await writeFile(resolve(output, 'manifest.json'), JSON.stringify({ library: '@liquefy-ui/react', version: '1.0.0', packages, inputs,
  files: { 'surface.html': digest(html), 'ThirdPartyNotices.txt': digest(notices) } }, null, 2) + '\n');
console.log(`Packaged the offline Liquefy surface (${Buffer.byteLength(html)} bytes).`);
