// Metronome — macOS native-style utility app
// Compact single-pane window: traffic lights, LCD tempo, +/- nudges,
// quick-tempo grid, big start/stop button.

const { useState, useEffect, useRef, useCallback } = React;

const MIN_BPM = 30;
const MAX_BPM = 300;
const QUICK_TEMPOS = [60, 80, 100, 120, 140, 160];

// ─── Traffic lights ────────────────────────────────────────────────
function TrafficLights() {
  const dot = (bg, shadow) => (
    <div style={{
      width: 12, height: 12, borderRadius: '50%',
      background: bg,
      boxShadow: `inset 0 0.5px 0 rgba(255,255,255,0.45), inset 0 -0.5px 0 ${shadow}, 0 0 0 0.5px rgba(0,0,0,0.18)`,
    }} />
  );
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      {dot('#ff5f57', 'rgba(0,0,0,0.18)')}
      {dot('#febc2e', 'rgba(0,0,0,0.18)')}
      {dot('#28c840', 'rgba(0,0,0,0.18)')}
    </div>
  );
}

// ─── LCD display ───────────────────────────────────────────────────
function LCD({ value, beat }) {
  // Render ghost "888" behind the live digits to mimic a real LCD.
  // Live digits are right-aligned so 60, 120, etc. all sit flush right.
  const str = String(value);
  const ghost = '888';

  return (
    <div style={{
      flex: 1,
      position: 'relative',
      borderRadius: 14,
      padding: '18px 22px 16px',
      background: 'linear-gradient(180deg, #b8c98a 0%, #c9d89a 50%, #b8c98a 100%)',
      boxShadow:
        'inset 0 2px 6px rgba(0,0,0,0.35), inset 0 -1px 0 rgba(255,255,255,0.25), 0 1px 0 rgba(255,255,255,0.6)',
      overflow: 'hidden',
    }}>
      {/* tiny labels in the LCD corners */}
      <div style={{
        position: 'absolute',
        top: 6, left: 12,
        fontFamily: '-apple-system, "Helvetica Neue", sans-serif',
        fontSize: 9,
        fontWeight: 700,
        letterSpacing: 1.2,
        color: 'rgba(40,55,15,0.55)',
      }}>
        TEMPO
      </div>
      <div style={{
        position: 'absolute',
        top: 6, right: 12,
        fontFamily: '-apple-system, "Helvetica Neue", sans-serif',
        fontSize: 9,
        fontWeight: 700,
        letterSpacing: 1.2,
        color: 'rgba(40,55,15,0.55)',
      }}>
        BPM
      </div>

      {/* Beat indicator dot, top-center */}
      <div style={{
        position: 'absolute',
        top: 7,
        left: '50%',
        transform: 'translateX(-50%)',
        display: 'flex',
        alignItems: 'center',
        gap: 5,
      }}>
        <div style={{
          width: 7, height: 7, borderRadius: '50%',
          background: beat ? 'rgba(40,55,15,0.85)' : 'rgba(40,55,15,0.18)',
          transition: 'background 60ms ease-out',
        }} />
      </div>

      {/* The digits — ghost layer behind active digits, right-aligned */}
      <div style={{
        position: 'relative',
        marginTop: 10,
        textAlign: 'right',
        fontFamily: 'DSEG7, "Courier New", monospace',
        fontSize: 56,
        fontWeight: 700,
        lineHeight: 1,
        letterSpacing: 0,
        paddingRight: 4,
      }}>
        <div style={{
          position: 'absolute',
          inset: 0,
          paddingRight: 4,
          color: 'rgba(40,55,15,0.10)',
        }}>{ghost}</div>
        <div style={{
          position: 'relative',
          color: 'rgba(20,35,5,0.92)',
          textShadow: '0 1px 0 rgba(255,255,255,0.15)',
        }}>{str}</div>
      </div>

      {/* subtle scanline reflection */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'linear-gradient(180deg, rgba(255,255,255,0.18) 0%, rgba(255,255,255,0) 35%, rgba(255,255,255,0) 65%, rgba(0,0,0,0.06) 100%)',
        pointerEvents: 'none',
      }} />
    </div>
  );
}

// ─── Round nudge button (+ / −) ────────────────────────────────────
function NudgeButton({ symbol, onClick, onHoldStart, onHoldEnd, ariaLabel }) {
  const [pressed, setPressed] = useState(false);
  return (
    <button
      aria-label={ariaLabel}
      onMouseDown={() => { setPressed(true); onHoldStart && onHoldStart(); }}
      onMouseUp={() => { setPressed(false); onHoldEnd && onHoldEnd(); }}
      onMouseLeave={() => { if (pressed) { setPressed(false); onHoldEnd && onHoldEnd(); } }}
      onClick={onClick}
      style={{
        width: 56, height: 56, borderRadius: '50%',
        border: 'none',
        cursor: 'pointer',
        background: pressed
          ? 'linear-gradient(180deg, #d8d3cb 0%, #ebe5db 100%)'
          : 'linear-gradient(180deg, #fbfaf6 0%, #e3ddd2 100%)',
        boxShadow: pressed
          ? 'inset 0 2px 4px rgba(0,0,0,0.22), inset 0 -1px 0 rgba(255,255,255,0.4), 0 0 0 0.5px rgba(0,0,0,0.18)'
          : '0 2px 5px rgba(0,0,0,0.18), inset 0 1px 0 rgba(255,255,255,0.85), inset 0 -1px 0 rgba(0,0,0,0.08), 0 0 0 0.5px rgba(0,0,0,0.18)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        transition: 'transform 80ms ease-out',
        transform: pressed ? 'translateY(0.5px)' : 'translateY(0)',
        flexShrink: 0,
      }}
    >
      <span style={{
        fontFamily: '-apple-system, "Helvetica Neue", sans-serif',
        fontSize: 28,
        fontWeight: 300,
        color: '#3a3530',
        lineHeight: 1,
        marginTop: -2,
      }}>{symbol}</span>
    </button>
  );
}

// ─── Quick-tempo pill button ───────────────────────────────────────
function QuickButton({ value, active, onClick }) {
  const [hover, setHover] = useState(false);
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        height: 36,
        borderRadius: 9,
        border: 'none',
        cursor: 'pointer',
        background: active
          ? 'linear-gradient(180deg, #4a8edb 0%, #2f6fc4 100%)'
          : hover
            ? 'linear-gradient(180deg, #fbfaf6 0%, #e8e2d6 100%)'
            : 'linear-gradient(180deg, #f6f2ea 0%, #e3ddd2 100%)',
        boxShadow: active
          ? 'inset 0 1px 0 rgba(255,255,255,0.35), inset 0 -1px 0 rgba(0,0,0,0.18), 0 1px 2px rgba(0,0,0,0.18), 0 0 0 0.5px rgba(0,0,0,0.25)'
          : 'inset 0 1px 0 rgba(255,255,255,0.85), inset 0 -1px 0 rgba(0,0,0,0.06), 0 1px 1.5px rgba(0,0,0,0.10), 0 0 0 0.5px rgba(0,0,0,0.16)',
        fontFamily: '-apple-system, "Helvetica Neue", sans-serif',
        fontSize: 14,
        fontWeight: 600,
        color: active ? '#fff' : '#3a3530',
        letterSpacing: 0.2,
        transition: 'background 100ms ease-out',
      }}
    >
      {value}
    </button>
  );
}

// ─── Big Start / Stop button ───────────────────────────────────────
function PlayButton({ running, onClick }) {
  const [hover, setHover] = useState(false);
  const [pressed, setPressed] = useState(false);

  const baseGreen = 'linear-gradient(180deg, #4ec96a 0%, #2ea84a 100%)';
  const hoverGreen = 'linear-gradient(180deg, #5ad078 0%, #34b352 100%)';
  const baseRed = 'linear-gradient(180deg, #e85a52 0%, #c33d36 100%)';
  const hoverRed = 'linear-gradient(180deg, #ed665e 0%, #cf4640 100%)';

  const bg = running
    ? (hover ? hoverRed : baseRed)
    : (hover ? hoverGreen : baseGreen);

  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => { setHover(false); setPressed(false); }}
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      style={{
        width: '100%',
        height: 48,
        borderRadius: 11,
        border: 'none',
        cursor: 'pointer',
        background: bg,
        boxShadow: pressed
          ? 'inset 0 2px 5px rgba(0,0,0,0.30), 0 0 0 0.5px rgba(0,0,0,0.30)'
          : 'inset 0 1px 0 rgba(255,255,255,0.45), inset 0 -1px 0 rgba(0,0,0,0.22), 0 2px 5px rgba(0,0,0,0.22), 0 0 0 0.5px rgba(0,0,0,0.30)',
        fontFamily: '-apple-system, "Helvetica Neue", sans-serif',
        fontSize: 17,
        fontWeight: 700,
        letterSpacing: 0.5,
        color: '#fff',
        textShadow: '0 -1px 0 rgba(0,0,0,0.18)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 9,
        transition: 'background 120ms ease-out',
      }}
    >
      {running ? (
        <span style={{ width: 10, height: 10, background: '#fff', borderRadius: 1.5, display: 'inline-block' }} />
      ) : (
        <span style={{
          width: 0, height: 0,
          borderTop: '7px solid transparent',
          borderBottom: '7px solid transparent',
          borderLeft: '11px solid #fff',
          marginLeft: 2,
          display: 'inline-block',
        }} />
      )}
      {running ? 'Stop' : 'Start'}
    </button>
  );
}

// ─── Audio engine ──────────────────────────────────────────────────
function useMetronome(bpm, running, onBeat) {
  const ctxRef = useRef(null);
  const nextNoteRef = useRef(0);
  const beatRef = useRef(0);
  const timerRef = useRef(null);
  const bpmRef = useRef(bpm);

  useEffect(() => { bpmRef.current = bpm; }, [bpm]);

  const scheduleNote = useCallback((time, isDownbeat) => {
    const ctx = ctxRef.current;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.frequency.value = isDownbeat ? 1500 : 1000;
    osc.type = 'square';
    gain.gain.setValueAtTime(0, time);
    gain.gain.linearRampToValueAtTime(0.25, time + 0.001);
    gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.05);
    osc.connect(gain).connect(ctx.destination);
    osc.start(time);
    osc.stop(time + 0.06);
  }, []);

  useEffect(() => {
    if (!running) {
      if (timerRef.current) clearInterval(timerRef.current);
      timerRef.current = null;
      return;
    }
    if (!ctxRef.current) {
      ctxRef.current = new (window.AudioContext || window.webkitAudioContext)();
    }
    const ctx = ctxRef.current;
    if (ctx.state === 'suspended') ctx.resume();

    nextNoteRef.current = ctx.currentTime + 0.06;
    beatRef.current = 0;

    timerRef.current = setInterval(() => {
      const interval = 60 / bpmRef.current;
      while (nextNoteRef.current < ctx.currentTime + 0.1) {
        const t = nextNoteRef.current;
        const isDown = beatRef.current % 4 === 0;
        scheduleNote(t, isDown);
        const delay = (t - ctx.currentTime) * 1000;
        setTimeout(() => onBeat && onBeat(), Math.max(0, delay));
        nextNoteRef.current += interval;
        beatRef.current += 1;
      }
    }, 25);

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      timerRef.current = null;
    };
  }, [running, scheduleNote, onBeat]);
}

// ─── Window chrome ─────────────────────────────────────────────────
function App() {
  const [bpm, setBpm] = useState(120);
  const [running, setRunning] = useState(false);
  const [beat, setBeat] = useState(false);
  const beatTimerRef = useRef(null);

  const flashBeat = useCallback(() => {
    setBeat(true);
    if (beatTimerRef.current) clearTimeout(beatTimerRef.current);
    beatTimerRef.current = setTimeout(() => setBeat(false), 80);
  }, []);

  useMetronome(bpm, running, flashBeat);

  const clamp = (n) => Math.max(MIN_BPM, Math.min(MAX_BPM, n));
  const inc = () => setBpm((b) => clamp(b + 1));
  const dec = () => setBpm((b) => clamp(b - 1));

  // Press-and-hold acceleration for +/-
  const holdRef = useRef(null);
  const startHold = (dir) => {
    if (holdRef.current) return;
    let delay = 380;
    const tick = () => {
      setBpm((b) => clamp(b + dir));
      delay = Math.max(35, delay * 0.82);
      holdRef.current = setTimeout(tick, delay);
    };
    holdRef.current = setTimeout(tick, delay);
  };
  const endHold = () => {
    if (holdRef.current) clearTimeout(holdRef.current);
    holdRef.current = null;
  };

  // Spacebar toggles, arrows nudge
  useEffect(() => {
    const onKey = (e) => {
      if (e.code === 'Space') { e.preventDefault(); setRunning((r) => !r); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); inc(); }
      else if (e.key === 'ArrowDown') { e.preventDefault(); dec(); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  return (
    <div style={{
      width: 420,
      borderRadius: 12,
      background: 'linear-gradient(180deg, #ecead8 0%, #e3e0c8 100%)',
      boxShadow:
        '0 0 0 0.5px rgba(0,0,0,0.30), 0 24px 60px rgba(0,0,0,0.45), 0 8px 18px rgba(0,0,0,0.25)',
      overflow: 'hidden',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
    }}>
      {/* Title bar */}
      <div style={{
        height: 38,
        background: 'linear-gradient(180deg, #f4f2e2 0%, #e6e2cc 100%)',
        borderBottom: '0.5px solid rgba(0,0,0,0.18)',
        display: 'grid',
        gridTemplateColumns: '1fr auto 1fr',
        alignItems: 'center',
        padding: '0 12px',
        position: 'relative',
      }}>
        <div style={{ justifySelf: 'start' }}>
          <TrafficLights />
        </div>
        <div style={{
          fontSize: 13,
          fontWeight: 600,
          color: '#3a3530',
          letterSpacing: 0.1,
        }}>
          Metronome
        </div>
        <div />
      </div>

      {/* Body */}
      <div style={{ padding: '20px 22px 22px' }}>
        {/* LCD row with +/- on either side */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <NudgeButton
            symbol="−"
            onClick={dec}
            onHoldStart={() => startHold(-1)}
            onHoldEnd={endHold}
            ariaLabel="Decrease tempo"
          />
          <LCD value={bpm} beat={beat} />
          <NudgeButton
            symbol="+"
            onClick={inc}
            onHoldStart={() => startHold(1)}
            onHoldEnd={endHold}
            ariaLabel="Increase tempo"
          />
        </div>

        {/* Quick tempos */}
        <div style={{
          marginTop: 18,
          display: 'grid',
          gridTemplateColumns: 'repeat(6, 1fr)',
          gap: 7,
        }}>
          {QUICK_TEMPOS.map((t) => (
            <QuickButton
              key={t}
              value={t}
              active={bpm === t}
              onClick={() => setBpm(t)}
            />
          ))}
        </div>

        {/* Start / Stop */}
        <div style={{ marginTop: 18 }}>
          <PlayButton
            running={running}
            onClick={() => setRunning((r) => !r)}
          />
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
