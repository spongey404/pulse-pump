// ══════════════════════════════════════════════════════════════
// Pulse Pump — Modals & Confirmations component library
// 5 reusable patterns for replacing native iOS alerts
// ══════════════════════════════════════════════════════════════

const TL = {
  bg:'#fbf8f2', surf:'#f4f0e6', surf2:'#ece7d8', surf3:'#e2dccd',
  ink:'#1f1c19', muted:'rgba(31,28,25,0.5)', faint:'rgba(31,28,25,0.13)',
  hair:'rgba(31,28,25,0.08)', hair2:'rgba(31,28,25,0.13)',
  accent:'#c8553d', accentSoft:'rgba(200,85,61,0.08)',
  up:'#1f8f5a', down:'#c0341a', pr:'#c9892e',
  tickerBg:'#1a1816', tickerFg:'#ece5d6',
};
const TD = {
  bg:'#1a1816', surf:'#252220', surf2:'#2e2a26', surf3:'#363028',
  ink:'#ece5d6', muted:'rgba(236,229,214,0.5)', faint:'rgba(236,229,214,0.13)',
  hair:'rgba(236,229,214,0.08)', hair2:'rgba(236,229,214,0.13)',
  accent:'#dc7d4a', accentSoft:'rgba(220,125,74,0.10)',
  up:'#3fb777', down:'#e05a45', pr:'#d4a03c',
  tickerBg:'#0e0c0a', tickerFg:'#ece5d6',
};

const StatusBar = ({dark=false}) => (
  <div style={{height:44,display:'flex',alignItems:'flex-end',justifyContent:'space-between',padding:'0 22px 6px',flexShrink:0}}>
    <div style={{fontFamily:'"Archivo",sans-serif',fontWeight:600,fontSize:14,color:dark?'#ece5d6':'#1f1c19'}}>9:41</div>
    <div style={{display:'flex',gap:5,alignItems:'center'}}>
      <svg width="17" height="11" viewBox="0 0 17 11"><path d="M1 9.5h2v-3H1v3zm4 0h2v-5H5v5zm4 0h2v-7H9v7zm4 0h2v-9h-2v9z" fill={dark?'#ece5d6':'#1f1c19'}/></svg>
      <svg width="22" height="11" viewBox="0 0 22 11"><rect x="0.5" y="0.5" width="18" height="10" rx="2.5" fill="none" stroke={dark?'#ece5d6':'#1f1c19'} opacity="0.5"/><rect x="2" y="2" width="14" height="7" rx="1.2" fill={dark?'#ece5d6':'#1f1c19'}/></svg>
    </div>
  </div>
);

// ══════════════════════════════════════════════════════════════
// PATTERN A — Inline confirmation strip
// Slides above the docked CTA. For: low-stakes destructive
// confirms in the logger / Home (discard workout, delete set)
// ══════════════════════════════════════════════════════════════
function InlineConfirm({C, title, body, cancelLabel='CANCEL', confirmLabel='CONFIRM', onCancel, onConfirm}) {
  return (
    <div style={{padding:'10px 14px',background:C.surf,borderRadius:10,border:`1px solid ${C.hair2}`}}>
      <div style={{fontFamily:'"Archivo",sans-serif',fontSize:13,fontWeight:600,color:C.ink,marginBottom:3}}>{title}</div>
      <div style={{fontFamily:'"Archivo",sans-serif',fontSize:12,color:C.muted,marginBottom:10,lineHeight:1.4}}>{body}</div>
      <div style={{display:'flex',gap:8}}>
        <div onClick={onCancel} style={{flex:1,height:40,borderRadius:10,background:C.surf2,border:`1px solid ${C.hair2}`,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer',overflow:'hidden'}}>
          <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:11,letterSpacing:0.8,color:C.muted,whiteSpace:'nowrap'}}>{cancelLabel}</span>
        </div>
        <div onClick={onConfirm} style={{flex:1,height:40,borderRadius:10,background:C.down,boxShadow:`0 6px 16px ${C.down}55`,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer',overflow:'hidden'}}>
          <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:11,letterSpacing:0.6,color:'#fff',whiteSpace:'nowrap'}}>{confirmLabel}</span>
        </div>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════════════════
// PATTERN B — Full-bleed destructive modal
// Centered card, bold, dense Bloomberg style
// For: delete account, cancel subscription, delete program
// ══════════════════════════════════════════════════════════════
function DestructiveModal({C, kicker, title, body, consequences, cancelLabel='KEEP', confirmLabel='DELETE', accent}) {
  const acc = accent || C.down;
  return (
    <div style={{position:'absolute',inset:0,background:'rgba(0,0,0,0.55)',display:'flex',alignItems:'center',justifyContent:'center',padding:'0 20px',zIndex:100,backdropFilter:'blur(2px)'}}>
      <div style={{width:'100%',background:C.bg,borderRadius:14,overflow:'hidden',border:`1px solid ${C.hair2}`}}>
        {/* Top warning strip */}
        <div style={{background:acc,padding:'8px 16px',display:'flex',alignItems:'center',justifyContent:'space-between'}}>
          <span style={{fontFamily:'"Space Mono",monospace',fontSize:9,letterSpacing:1.8,color:'#fff',fontWeight:700}}>⚠ {kicker}</span>
          <span style={{fontFamily:'"Space Mono",monospace',fontSize:9,letterSpacing:1.5,color:'rgba(255,255,255,0.7)'}}>IRREVERSIBLE</span>
        </div>
        <div style={{padding:'18px 18px 16px'}}>
          <div style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:22,color:C.ink,letterSpacing:0.3,lineHeight:1.05,marginBottom:8}}>{title}</div>
          <div style={{fontFamily:'"Archivo",sans-serif',fontSize:13,color:C.muted,lineHeight:1.5,marginBottom:14}}>{body}</div>
          {consequences && (
            <div style={{background:C.surf,borderRadius:8,border:`1px solid ${C.hair}`,marginBottom:14}}>
              <div style={{padding:'7px 12px',borderBottom:`1px solid ${C.hair}`,background:C.surf2}}>
                <span style={{fontFamily:'"Space Mono",monospace',fontSize:8,letterSpacing:1.5,color:C.muted,fontWeight:700}}>WHAT YOU'LL LOSE</span>
              </div>
              {consequences.map((c,i)=>(
                <div key={i} style={{display:'flex',alignItems:'center',gap:10,padding:'8px 12px',borderBottom:i<consequences.length-1?`1px solid ${C.hair}`:'none'}}>
                  <span style={{fontFamily:'"Space Mono",monospace',fontSize:11,fontWeight:700,color:acc,minWidth:38}}>{c.value}</span>
                  <span style={{fontFamily:'"Archivo",sans-serif',fontSize:12,color:C.ink,flex:1}}>{c.label}</span>
                </div>
              ))}
            </div>
          )}
        </div>
        <div style={{padding:'12px 14px 14px',display:'flex',gap:8,borderTop:`1px solid ${C.hair}`}}>
          <div style={{flex:1,height:44,borderRadius:10,background:C.surf2,border:`1px solid ${C.hair2}`,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
            <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:13,letterSpacing:1,color:C.muted,whiteSpace:'nowrap'}}>{cancelLabel}</span>
          </div>
          <div style={{flex:1,height:44,borderRadius:10,background:acc,boxShadow:`0 6px 16px ${acc}55`,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
            <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:13,letterSpacing:1,color:'#fff',whiteSpace:'nowrap'}}>{confirmLabel}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════════════════
// PATTERN C — Bottom sheet action menu
// Slides up from bottom. Replaces native action sheet.
// For: ··· menus, share, photo picker
// ══════════════════════════════════════════════════════════════
function ActionSheet({C, title, sub, items, cancelLabel='CANCEL'}) {
  return (
    <div style={{position:'absolute',inset:0,background:'rgba(0,0,0,0.5)',display:'flex',flexDirection:'column',justifyContent:'flex-end',zIndex:100}}>
      <div style={{background:C.bg,borderRadius:'14px 14px 0 0',overflow:'hidden',padding:'8px 0 28px'}}>
        <div style={{width:36,height:4,background:C.faint,borderRadius:2,margin:'4px auto 8px'}}/>
        {(title||sub) && (
          <div style={{padding:'6px 16px 12px',borderBottom:`1px solid ${C.hair}`}}>
            {sub && <div style={{fontFamily:'"Space Mono",monospace',fontSize:8,letterSpacing:1.5,color:C.muted,fontWeight:700,marginBottom:3}}>{sub}</div>}
            {title && <div style={{fontFamily:'"Archivo",sans-serif',fontWeight:700,fontSize:16,color:C.ink,letterSpacing:0.2}}>{title}</div>}
          </div>
        )}
        {items.map((it,i)=>{
          const isDanger = it.danger;
          const col = isDanger?C.down:C.ink;
          return (
            <div key={i} style={{display:'flex',alignItems:'center',gap:12,padding:'14px 16px',borderBottom:i<items.length-1?`1px solid ${C.hair}`:'none',cursor:'pointer'}}>
              <div style={{width:28,height:28,borderRadius:7,background:isDanger?'rgba(192,52,26,0.10)':C.surf2,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke={col} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">{it.icon}</svg>
              </div>
              <div style={{flex:1}}>
                <div style={{fontFamily:'"Archivo",sans-serif',fontWeight:600,fontSize:14,color:col,letterSpacing:0.2}}>{it.label}</div>
                {it.sub && <div style={{fontFamily:'"Archivo",sans-serif',fontSize:11,color:C.muted,marginTop:1}}>{it.sub}</div>}
              </div>
              {it.shortcut && <span style={{fontFamily:'"Space Mono",monospace',fontSize:9,letterSpacing:1.2,color:C.muted}}>{it.shortcut}</span>}
            </div>
          );
        })}
        <div style={{height:8,background:C.surf2}}/>
        <div style={{padding:'14px 16px',display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
          <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:14,letterSpacing:1.5,color:C.ink}}>{cancelLabel}</span>
        </div>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════════════════
// PATTERN D — Pre-permission priming screen
// Full-screen explanation BEFORE triggering iOS native prompt
// For: HealthKit, Notifications, Camera, Photos
// ══════════════════════════════════════════════════════════════
function PrimingScreen({C, kicker, title, body, bullets, primaryLabel, secondaryLabel='NOT NOW', icon}) {
  const dark = C===TD;
  return (
    <div style={{width:'100%',height:'100%',background:C.bg,display:'flex',flexDirection:'column',color:C.ink}}>
      <StatusBar dark={dark}/>
      {/* Ticker strip */}
      <div style={{background:C.tickerBg,height:24,padding:'0 14px',display:'flex',alignItems:'center',gap:14,flexShrink:0}}>
        <span style={{fontFamily:'"Space Mono",monospace',fontSize:9,color:'#dc7d4a',fontWeight:700,letterSpacing:1.5}}>● PERMISSION</span>
        <span style={{fontFamily:'"Space Mono",monospace',fontSize:9,color:C.tickerFg,opacity:0.6,letterSpacing:1.2}}>STEP 1/1</span>
      </div>
      <div style={{flex:1,display:'flex',flexDirection:'column',padding:'40px 22px 22px',overflow:'hidden'}}>
        <div style={{fontFamily:'"Space Mono",monospace',fontSize:9,letterSpacing:2,color:C.accent,fontWeight:700,marginBottom:20}}>⚡ {kicker}</div>
        {/* Big icon */}
        <div style={{width:88,height:88,borderRadius:20,background:C.accentSoft,border:`1.5px solid ${C.accent}`,display:'flex',alignItems:'center',justifyContent:'center',marginBottom:24}}>
          <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke={C.accent} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{icon}</svg>
        </div>
        <div style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:30,color:C.ink,letterSpacing:0.2,lineHeight:1,marginBottom:12}}>{title}</div>
        <div style={{fontFamily:'"Archivo",sans-serif',fontSize:14,color:C.muted,lineHeight:1.5,marginBottom:22}}>{body}</div>
        {/* Bullet list */}
        <div style={{background:C.surf,borderRadius:10,border:`1px solid ${C.hair}`,marginBottom:'auto'}}>
          <div style={{padding:'8px 12px',borderBottom:`1px solid ${C.hair}`,background:C.surf2}}>
            <span style={{fontFamily:'"Space Mono",monospace',fontSize:8,letterSpacing:1.5,color:C.muted,fontWeight:700}}>WHAT WE'LL DO WITH IT</span>
          </div>
          {bullets.map((b,i)=>(
            <div key={i} style={{display:'flex',gap:10,padding:'10px 12px',borderBottom:i<bullets.length-1?`1px solid ${C.hair}`:'none'}}>
              <span style={{fontFamily:'"Space Mono",monospace',fontSize:10,color:C.accent,fontWeight:700,minWidth:18}}>0{i+1}</span>
              <span style={{fontFamily:'"Archivo",sans-serif',fontSize:13,color:C.ink,lineHeight:1.4,flex:1}}>{b}</span>
            </div>
          ))}
        </div>
        {/* CTAs */}
        <div style={{display:'flex',flexDirection:'column',gap:8,marginTop:20}}>
          <div style={{height:54,borderRadius:12,background:C.accent,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
            <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:16,letterSpacing:2,color:'#fff'}}>{primaryLabel}</span>
          </div>
          <div style={{height:44,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
            <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:13,letterSpacing:1.5,color:C.muted}}>{secondaryLabel}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════════════════
// PATTERN E — Toast / banner system
// Top-of-screen ticker-style banner
// For: PR achieved, synced, friend added, network status
// ══════════════════════════════════════════════════════════════
function Toast({C, kind='info', kicker, title, value, onDismiss}) {
  const colors = {
    success:{bg:C.up, fg:'#fff', tag:'SAVED'},
    pr:{bg:C.pr, fg:'#1f1c19', tag:'PR'},
    error:{bg:C.down, fg:'#fff', tag:'ERROR'},
    info:{bg:C.tickerBg, fg:C.tickerFg, tag:'INFO'},
    offline:{bg:'#3a342d', fg:'#ece5d6', tag:'OFFLINE'},
  }[kind] || {bg:C.tickerBg,fg:C.tickerFg,tag:'INFO'};
  return (
    <div style={{margin:'0 12px',background:colors.bg,borderRadius:10,padding:'10px 12px',display:'flex',alignItems:'center',gap:10,boxShadow:'0 2px 8px rgba(0,0,0,0.15)'}}>
      <span style={{fontFamily:'"Space Mono",monospace',fontSize:9,letterSpacing:1.8,color:colors.fg,opacity:0.7,fontWeight:700,minWidth:48}}>● {kicker||colors.tag}</span>
      <div style={{flex:1,minWidth:0}}>
        <div style={{fontFamily:'"Archivo",sans-serif',fontWeight:700,fontSize:13,color:colors.fg,letterSpacing:0.2,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{title}</div>
      </div>
      {value && <span style={{fontFamily:'"Space Mono",monospace',fontSize:13,fontWeight:700,color:colors.fg,letterSpacing:0.5}}>{value}</span>}
    </div>
  );
}

// ══════════════════════════════════════════════════════════════
// PR CELEBRATION — special big toast for PR moments
// ══════════════════════════════════════════════════════════════
function PRCelebration({C, exercise, oldVal, newVal, unit='KG'}) {
  return (
    <div style={{position:'absolute',inset:0,background:'rgba(0,0,0,0.7)',display:'flex',alignItems:'center',justifyContent:'center',padding:'0 28px',zIndex:100,backdropFilter:'blur(3px)'}}>
      <div style={{width:'100%',background:C.bg,borderRadius:14,overflow:'hidden',border:`1.5px solid ${C.pr}`,position:'relative'}}>
        {/* Diagonal stripe pattern */}
        <div style={{position:'absolute',inset:0,opacity:0.04,background:`repeating-linear-gradient(45deg, ${C.pr} 0, ${C.pr} 8px, transparent 8px, transparent 16px)`,pointerEvents:'none'}}/>
        <div style={{background:C.pr,padding:'12px 18px',display:'flex',alignItems:'center',justifyContent:'space-between'}}>
          <span style={{fontFamily:'"Space Mono",monospace',fontSize:10,letterSpacing:2.5,color:'#1f1c19',fontWeight:700}}>★ PERSONAL RECORD ★</span>
          <span style={{fontFamily:'"Space Mono",monospace',fontSize:9,letterSpacing:1.5,color:'rgba(31,28,25,0.7)',fontWeight:700}}>NEW</span>
        </div>
        <div style={{padding:'24px 20px 18px',position:'relative'}}>
          <div style={{fontFamily:'"Space Mono",monospace',fontSize:9,letterSpacing:1.8,color:C.muted,fontWeight:700,marginBottom:6}}>EXERCISE</div>
          <div style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:24,color:C.ink,letterSpacing:0.3,lineHeight:1,marginBottom:18}}>{exercise.toUpperCase()}</div>
          {/* Big numbers */}
          <div style={{display:'flex',alignItems:'baseline',gap:14,marginBottom:6}}>
            <div>
              <div style={{fontFamily:'"Space Mono",monospace',fontSize:8,letterSpacing:1.5,color:C.muted,fontWeight:700,marginBottom:2}}>PREVIOUS</div>
              <div style={{fontFamily:'"Space Mono",monospace',fontSize:26,fontWeight:700,color:C.muted,textDecoration:'line-through'}}>{oldVal}</div>
            </div>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={C.pr} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{marginBottom:4}}><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            <div>
              <div style={{fontFamily:'"Space Mono",monospace',fontSize:8,letterSpacing:1.5,color:C.pr,fontWeight:700,marginBottom:2}}>NEW · {unit}</div>
              <div style={{fontFamily:'"Space Mono",monospace',fontSize:38,fontWeight:700,color:C.ink,lineHeight:1}}>{newVal}</div>
            </div>
          </div>
          <div style={{fontFamily:'"Space Mono",monospace',fontSize:10,letterSpacing:1.5,color:C.up,fontWeight:700}}>▲ +{(newVal-oldVal).toFixed(1)} {unit}</div>
        </div>
        <div style={{display:'flex',borderTop:`1px solid ${C.hair2}`}}>
          <div style={{flex:1,height:48,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer',borderRight:`1px solid ${C.hair2}`}}>
            <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:13,letterSpacing:1.5,color:C.muted}}>DISMISS</span>
          </div>
          <div style={{flex:1.4,height:48,background:C.accent,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer',gap:6}}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.6" y1="13.5" x2="15.4" y2="17.5"/><line x1="15.4" y1="6.5" x2="8.6" y2="10.5"/></svg>
            <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:13,letterSpacing:1.5,color:'#fff'}}>SHARE TO FEED</span>
          </div>
        </div>
      </div>
    </div>
  );
}

// ══════════════════════════════════════════════════════════════
// PATTERN F — Inline rename input (replaces iOS text alert)
// ══════════════════════════════════════════════════════════════
function RenameModal({C, kicker, title, currentValue, placeholder, label='NAME', confirmLabel='SAVE'}) {
  return (
    <div style={{position:'absolute',inset:0,background:'rgba(0,0,0,0.55)',display:'flex',alignItems:'center',justifyContent:'center',padding:'0 20px',zIndex:100,backdropFilter:'blur(2px)'}}>
      <div style={{width:'100%',background:C.bg,borderRadius:14,overflow:'hidden',border:`1px solid ${C.hair2}`}}>
        <div style={{padding:'14px 16px 12px',borderBottom:`1px solid ${C.hair}`}}>
          <div style={{fontFamily:'"Space Mono",monospace',fontSize:9,letterSpacing:1.8,color:C.accent,fontWeight:700,marginBottom:4}}>✎ {kicker}</div>
          <div style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:18,color:C.ink,letterSpacing:0.3}}>{title}</div>
        </div>
        <div style={{padding:'14px 16px 16px'}}>
          <div style={{fontFamily:'"Space Mono",monospace',fontSize:8,letterSpacing:1.5,color:C.muted,fontWeight:700,marginBottom:6}}>{label}</div>
          <div style={{height:46,background:C.surf,border:`1.5px solid ${C.accent}`,borderRadius:10,padding:'0 14px',display:'flex',alignItems:'center'}}>
            <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:700,fontSize:16,color:C.ink,letterSpacing:0.2,flex:1}}>{currentValue||placeholder}</span>
            <span style={{width:1.5,height:20,background:C.accent,marginLeft:2,animation:'blink 1s infinite'}}/>
          </div>
          <div style={{fontFamily:'"Space Mono",monospace',fontSize:9,letterSpacing:1.2,color:C.muted,fontWeight:700,marginTop:6,textAlign:'right'}}>{(currentValue||'').length}/40</div>
        </div>
        <div style={{padding:'12px 14px 14px',display:'flex',gap:8,borderTop:`1px solid ${C.hair}`}}>
          <div style={{flex:1,height:44,borderRadius:10,background:C.surf2,border:`1px solid ${C.hair2}`,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
            <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:13,letterSpacing:1,color:C.muted,whiteSpace:'nowrap'}}>CANCEL</span>
          </div>
          <div style={{flex:1,height:44,borderRadius:10,background:C.accent,boxShadow:`0 6px 16px ${C.accent}55`,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
            <span style={{fontFamily:'"Archivo",sans-serif',fontWeight:900,fontSize:13,letterSpacing:1,color:'#fff',whiteSpace:'nowrap'}}>{confirmLabel}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  TL, TD, StatusBar,
  InlineConfirm, DestructiveModal, ActionSheet,
  PrimingScreen, Toast, PRCelebration, RenameModal,
});
