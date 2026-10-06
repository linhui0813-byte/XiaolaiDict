import { useEffect, useState } from 'react';
import { LiquidGlass, LiquefyProvider, LiquidSlider } from '@liquefy-ui/react';
import { ChevronRightIcon, SearchIcon, XIcon } from '@liquefy-ui/icons';
import { Volume2 } from 'lucide-react';
import '@liquefy-ui/react/styles.css';

const entries = {
  refused: {
    phonetic: '/rɪˈfjuːzd/',
    rows: [['v.', '拒绝（refuse 的过去式和过去分词）'], ['v.', '不接受；拒收'], ['adj.', '遭拒绝的，被拒绝的']],
    example: 'She refused to give up.',
    note: 'Past tense and past participle of refuse.',
  },
  latest: {
    phonetic: '/ˈleɪtɪst/',
    rows: [['adj.', '最新的'], ['adj.', '最近的；晚的；迟的'], ['n.', '最新消息；最新事物']],
    example: 'Have you read the latest news?',
    note: 'Superlative form of late.',
  },
  appearance: {
    phonetic: '/əˈpɪərəns/',
    rows: [['n.', '外观'], ['n.', '到来；外表；出版；出庭；演出']],
    example: 'The appearance of the card changes as you move the slider.',
    note: 'The way someone or something looks.',
  },
};

function usePreference(query) {
  const [matches, setMatches] = useState(() => window.matchMedia(query).matches);
  useEffect(() => {
    const media = window.matchMedia(query);
    const update = () => setMatches(media.matches);
    media.addEventListener('change', update);
    return () => media.removeEventListener('change', update);
  }, [query]);
  return matches;
}

function DictionaryCard({ word, transmission, onClose, onWordChange }) {
  const entry = entries[word];
  const [expanded, setExpanded] = useState(false);
  const [searching, setSearching] = useState(false);
  const [query, setQuery] = useState('');
  const [message, setMessage] = useState('');
  useEffect(() => { setExpanded(false); setMessage(''); }, [word]);

  const lookup = (event) => {
    event.preventDefault();
    const next = query.trim().toLowerCase();
    if (!entries[next]) {
      setMessage('Try refused, latest, or appearance in this preview.');
      return;
    }
    onWordChange(next);
    setSearching(false);
    setQuery('');
  };
  const pronounce = () => {
    if (!('speechSynthesis' in window)) {
      setMessage('Pronunciation is unavailable in this browser.');
      return;
    }
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(word);
    utterance.lang = 'en-GB';
    utterance.rate = 0.85;
    utterance.onerror = () => setMessage('Pronunciation is unavailable. Please try again.');
    window.speechSynthesis.speak(utterance);
  };

  return (
    <LiquidGlass className="dictionary-card" radius={28} padding={23} interactive={false}
      frost={1.5 + (1 - transmission) * 5} softness={0.6} bezel={24} curve={2} saturation={1.12}
      role="dialog" aria-labelledby="entry-word" id="dictionary-card">
      <header className="entry-header">
        <h2 id="entry-word">{word}</h2>
        <div className="entry-actions">
          <button className="icon-button" aria-label="Close dictionary card" onClick={onClose}><XIcon /></button>
          <button className="icon-button" aria-label="Search preview words" aria-expanded={searching}
            onClick={() => { setSearching(!searching); setMessage(''); }}><SearchIcon /></button>
        </div>
      </header>
      {searching && <form className="word-search" onSubmit={lookup}>
        <label htmlFor="word-query">Preview word</label>
        <div className="search-row">
          <input id="word-query" autoFocus value={query} onChange={(e) => setQuery(e.target.value)}
            placeholder="refused, latest, appearance" autoComplete="off" />
          <button type="submit">Look up</button>
        </div>
      </form>}
      <div className="phonetic"><span>{entry.phonetic}</span>
        <button className="icon-button audio-button" aria-label={`Pronounce ${word}`} onClick={pronounce}><Volume2 /></button>
      </div>
      <dl className="meanings" lang="zh-Hans">
        {entry.rows.map(([part, meaning], index) => <div className="meaning-row" key={index}>
          <dt>{part}</dt><dd>{meaning}</dd>
        </div>)}
      </dl>
      {expanded && <div className="entry-detail" id="entry-detail">
        <p>{entry.note}</p><blockquote>{entry.example}</blockquote>
      </div>}
      <div className="entry-footer">
        <button className="more-button" aria-expanded={expanded} aria-controls="entry-detail"
          onClick={() => setExpanded(!expanded)}>{expanded ? 'Fewer meanings' : 'More meanings'}<ChevronRightIcon /></button>
      </div>
      {message && <p className="entry-message" role="status">{message}</p>}
    </LiquidGlass>
  );
}

function ReadingPage({ word }) {
  return <article className="reading-page" aria-label="Reading background">
    <div className="reading-label">A MOMENT TO READ</div>
    <h2>A clearer perspective</h2>
    <p>Progress comes from paying attention. We continued reading, looking for a clearer explanation. Each word opened another way to understand the story.</p>
    <p>The proposal was <mark>{word}</mark>. We paused, considered the details, and returned with a different perspective. A small change can make familiar things feel new again.</p>
    <p>Beyond the window, the light shifted across the room. The page stayed still while the world carried on around it.</p>
    <p>There is always more to discover when we take the time to look a little closer.</p>
  </article>;
}

export function App() {
  const reducedMotion = usePreference('(prefers-reduced-motion: reduce)');
  const reducedTransparency = usePreference('(prefers-reduced-transparency: reduce)');
  const [transparency, setTransparency] = useState(reducedTransparency ? 0 : 68);
  const [backdrop, setBackdrop] = useState('color');
  const [word, setWord] = useState('refused');
  const [visible, setVisible] = useState(true);
  const dark = backdrop === 'dark';
  // Change the glass only; never apply opacity or a filter to the definition text.
  // Veil scales the material dressing while retaining Liquefy's refracting rim.
  const transmission = reducedTransparency ? 0 : transparency / 100;
  useEffect(() => { if (reducedTransparency) setTransparency(0); }, [reducedTransparency]);

  return <LiquefyProvider theme="light" tint="#087dff" motion={!reducedMotion} lens={false} className="app-shell">
    <main className="appearance">
      <header className="page-header">
        <div><p className="app-name">HuiDict</p><h1>Appearance</h1></div>
        <a className="trial-label" href="https://github.com/liquefy-ui/liquefy-ui" target="_blank" rel="noreferrer">Liquefy UI trial<ChevronRightIcon /></a>
      </header>
      <section className="appearance-panel" aria-labelledby="glass-heading">
        <div className="panel-description"><h2 id="glass-heading">Liquid Glass</h2>
          <p>Choose how much of the background shows through.</p></div>
        <div className="panel-content">
          <div className="stage" data-backdrop={backdrop}>
            <ReadingPage word={word} />
            <LiquefyProvider theme={dark ? 'dark' : 'light'} motion={!reducedMotion} webgl={!reducedMotion} lens={transmission > 0}
              refraction={1} veil={1 - transmission} intensity={1.4}
              glow shimmer tint="#8f8f8f" className="glass-layer">
              {visible ? <DictionaryCard word={word} transmission={transmission} onClose={() => setVisible(false)} onWordChange={setWord} />
                : <button className="show-card" onClick={() => setVisible(true)}>Show dictionary card</button>}
            </LiquefyProvider>
          </div>
          <div className="background-row"><span>Background</span>
            <div className="background-options" role="group" aria-label="Preview background">
              {['reading', 'color', 'dark'].map((value) => <button key={value} aria-pressed={backdrop === value}
                onClick={() => setBackdrop(value)}>{value === 'reading' ? 'Reading' : value === 'color' ? 'Color' : 'Dark'}</button>)}
            </div>
          </div>
          <div className="transparency-control">
            <div className="slider-heading"><span>Transparency</span>
              <output id="transparency-value">{transparency}%</output></div>
            <LiquidSlider aria-label="Glass transparency" min={0} max={100} step={1} value={transparency}
              disabled={reducedTransparency} onValueChange={setTransparency} />
            <div className="slider-captions"><span>More opaque</span><span>Clearer</span></div>
          </div>
          <p className="control-note">{reducedTransparency ? 'Reduce Transparency is enabled in your system settings.' : 'Text and icons stay crisp.'}</p>
        </div>
      </section>
    </main>
  </LiquefyProvider>;
}
