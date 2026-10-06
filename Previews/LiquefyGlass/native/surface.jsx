import React from 'react';
import { createRoot } from 'react-dom/client';
import { flushSync } from 'react-dom';
import { LiquidGlass, LiquefyProvider } from '@liquefy-ui/react';
import '@liquefy-ui/react/styles.css';
import './surface.css';
import { NativeOptics } from './optics';

const properties = { transparency: .55, radius: 28, theme: 'light', reduceMotion: false, reduceTransparency: false };
const root = createRoot(document.querySelector('#surface'));
const optics = new NativeOptics(document.querySelector('#backdrop'));
let failure = null;
let pending = false;
const status = () => ({
  library: '@liquefy-ui/react', version: '1.0.0',
  ready: Boolean(optics.map && optics.hasBackdrop && !failure),
  lens: Boolean(optics.map), frames: optics.frames, error: failure,
  transparency: properties.reduceTransparency ? 0 : properties.transparency,
  shader: Boolean(document.querySelector('.lq-surface__shader')),
  darkBackdrop: optics.darkBackdrop,
  fill: document.querySelector('.native-glass') ? getComputedStyle(document.querySelector('.native-glass')).backgroundColor : null,
});

function render() {
  const transmission = properties.reduceTransparency ? 0 : properties.transparency;
  document.documentElement.style.setProperty('--radius', `${properties.radius}px`);
  flushSync(() => root.render(
    <LiquefyProvider theme={properties.theme} motion={!properties.reduceMotion} lens={false}
      veil={Math.pow(1 - transmission, 1.45)} intensity={1.4} glow shimmer tint="#8f8f8f">
      <LiquidGlass className="native-glass" radius={properties.radius} padding={0} frost={0}
        interactive={false} aria-hidden="true" />
    </LiquefyProvider>
  ));
}

window.HuiDictGlass = {
  async configure(update) {
    Object.assign(properties, update);
    properties.transparency = Math.max(0, Math.min(1, properties.transparency));
    render();
    try { await optics.configure(properties); failure = null; }
    catch (error) { failure = String(error); }
    return status();
  },
  async frame(url) {
    if (pending) return status();
    pending = true;
    try { await optics.updateFrame(url); failure = null; }
    catch (error) { failure = String(error); }
    finally { pending = false; }
    return status();
  },
  status,
};
window.addEventListener('resize', () => window.HuiDictGlass.configure(properties));
window.HuiDictGlass.configure(properties);
