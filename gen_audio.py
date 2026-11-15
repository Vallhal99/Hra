import numpy as np, wave, random
SR=16000
def mid(n): return 440.0*2**((n-69)/12)
def env(n,a,d,s,r,sus_len=None):
    t=np.arange(n)/SR
    e=np.ones(n)
    e=np.minimum(1,t/max(a,1e-4))
    dur=n/SR
    e*=np.where(t<a,1,np.exp(-(t-a)/d*3)*(1-s)+s)
    rel=np.clip((dur-t)/r,0,1)
    return e*rel
def tone(f,dur,kind='tri',vol=0.3,a=0.01,d=0.4,s=0.0,r=0.08):
    n=int(dur*SR); t=np.arange(n)/SR
    ph=2*np.pi*f*t
    if kind=='sin': w=np.sin(ph)
    elif kind=='tri': w=2/np.pi*np.arcsin(np.sin(ph))
    elif kind=='pluck': w=np.sin(ph)+0.5*np.sin(2*ph)*np.exp(-t*6)+0.25*np.sin(3*ph)*np.exp(-t*9)
    elif kind=='bell': w=np.sin(ph)+0.5*np.sin(2.76*ph)*np.exp(-t*3)+0.3*np.sin(5.4*ph)*np.exp(-t*5)
    elif kind=='saw': w=2*((f*t)%1)-1; w*=0.6
    else: w=np.sin(ph)
    return w*env(n,a,d,s,r)*vol
def mix(buf,sig,t0):
    i=int(t0*SR); j=min(len(buf),i+len(sig))
    if i<len(buf): buf[i:j]+=sig[:j-i]
def noise(dur,vol,decay=20):
    n=int(dur*SR); t=np.arange(n)/SR
    return (np.random.uniform(-1,1,n))*np.exp(-t*decay)*vol
def save(name,buf,norm=0.85):
    buf=np.tanh(buf*1.1); m=np.max(np.abs(buf)); buf=buf/max(m,1e-6)*norm
    with wave.open(f'/home/claude/proj/Babrak2/audio/{name}.wav','wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((buf*32767).astype('<i2').tobytes())
def reverb(buf,amt=0.25):
    out=buf.copy()
    for d,g in [(0.09,0.5),(0.17,0.35),(0.29,0.25)]:
        k=int(d*SR); out[k:]+=buf[:-k]*g*amt*2
    return out
random.seed(7); np.random.seed(7)

def theme(name,bpm,bars,beats,scale,root,chords,mel_kind,pad_kind,mel_density,bass=True,perc=0,mel_vol=0.22,octave=12,arp=False):
    spb=60.0/bpm; dur=bars*beats*spb
    buf=np.zeros(int(dur*SR)+SR)
    for b in range(bars):
        ch=chords[b%len(chords)]
        t0=b*beats*spb
        for k,iv in enumerate(ch):
            mix(buf,tone(mid(root+iv),beats*spb*1.02,pad_kind,0.09,a=0.5,d=2,s=0.7,r=0.6),t0)
        if bass: 
            for q in range(beats):
                if q%2==0 or beats==3 and q==0: mix(buf,tone(mid(root+ch[0]-12),spb*1.8,'sin',0.2,a=0.02,d=0.6,s=0.2),t0+q*spb)
        if arp:
            for q in range(beats*2):
                mix(buf,tone(mid(root+ch[q%len(ch)]+12),spb*0.5,mel_kind,0.1,a=0.005,d=0.15),t0+q*spb*0.5)
        # melody
        pos=0.0
        while pos<beats:
            if random.random()<mel_density:
                deg=random.choice(scale)
                oct_=random.choice([0,0,12])
                note=root+deg+oct_+ (ch[0] if random.random()<0.3 else 0)
                ln=random.choice([0.5,1,1,1.5])
                mix(buf,tone(mid(note+octave),ln*spb,mel_kind,mel_vol,a=0.01,d=0.5),t0+pos*spb)
                pos+=ln
            else: pos+=0.5
        if perc:
            for q in range(beats*2):
                if q%2==0: mix(buf,noise(0.12,0.28*perc,35)*1.0,t0+q*spb*0.5)
                if q%4==2: mix(buf,np.sin(2*np.pi*70*np.arange(int(0.18*SR))/SR)*np.exp(-np.arange(int(0.18*SR))/SR*18)*0.5*perc,t0+q*spb*0.5)
    buf=reverb(buf[:int(dur*SR)],0.3)
    # soft loop fade
    f=int(0.05*SR); buf[:f]*=np.linspace(0,1,f); buf[-f:]*=np.linspace(1,0,f)
    save(name,buf)

PENT=[0,2,4,7,9]; MINP=[0,3,5,7,10]
theme('m_pole',84,16,4,PENT,60,[[0,4,7],[5,9,12],[7,11,14],[0,4,7],[9,12,16],[5,9,12],[7,11,14],[0,4,7]],'pluck','sin',0.55,octave=0,arp=False)
theme('m_vesnice',108,16,3,[0,2,4,7,9,11],62,[[0,4,7],[7,11,14],[9,12,16],[5,9,12]],'pluck','tri',0.6,octave=0,arp=True)
theme('m_hrbitov',58,12,4,[0,3,5,7,8,10],57,[[0,3,7],[8,12,15],[5,8,12],[7,10,14]],'bell','sin',0.35,octave=12,mel_vol=0.14)
theme('m_hrobka',50,12,4,[0,1,3,5,7],45,[[0,3,7],[0,1,7],[0,3,6]],'bell','saw',0.22,octave=12,mel_vol=0.1)
theme('m_jeskyne',60,12,4,[0,2,3,7,10],50,[[0,7,12],[3,10,15],[0,7,12],[5,12,17]],'bell','sin',0.3,octave=12,mel_vol=0.12)
theme('m_boj',140,16,4,[0,2,3,5,7,8,10],57,[[0,3,7],[0,3,7],[8,12,15],[5,8,12],[7,10,14],[0,3,7],[10,14,17],[7,11,14]],'saw','saw',0.7,perc=1.0,arp=True,mel_vol=0.16,octave=0)
theme('m_boss',158,16,4,[0,1,3,5,6,8,11],52,[[0,3,6],[0,1,7],[8,11,14],[5,8,11],[0,3,6],[1,5,8],[8,11,14],[7,11,14]],'saw','saw',0.8,perc=1.3,arp=True,mel_vol=0.18,octave=0)

# SFX
def sfx(name,sig): save(name,sig,0.8)
n=int(0.25*SR); t=np.arange(n)/SR
sfx('s_hit',noise(0.25,0.9,18)+np.sin(2*np.pi*(180-300*t)*t)*np.exp(-t*14)*0.7)
sfx('s_slash',noise(0.2,0.6,12)*np.sin(np.linspace(0,np.pi,int(0.2*SR))))
buf=np.zeros(int(0.8*SR)); [mix(buf,tone(mid(n_),0.3,'bell',0.4),i*0.1) for i,n_ in enumerate([72,76,79,84])]; sfx('s_heal',buf)
buf=np.zeros(int(1.5*SR)); [mix(buf,tone(mid(n_),0.35,'pluck',0.4),i*0.14) for i,n_ in enumerate([67,72,76,79,84,88])]; sfx('s_win',buf)
buf=np.zeros(int(0.5*SR)); mix(buf,tone(mid(60),0.2,'tri',0.4),0); mix(buf,tone(mid(67),0.3,'tri',0.4),0.12); sfx('s_chest',buf)
sfx('s_click',tone(mid(84),0.06,'sin',0.5,d=0.05))
sfx('s_move',tone(mid(76),0.04,'sin',0.4,d=0.03))
buf=np.zeros(int(0.7*SR)); [mix(buf,tone(mid(n_),0.2,'sin',0.4),i*0.1) for i,n_ in enumerate([60,64,67,72,76])]; sfx('s_levelup',buf)
buf=np.zeros(int(1.2*SR)); mix(buf,noise(1.0,0.8,3),0); mix(buf,tone(mid(36),1.0,'sin',0.6,d=1.0),0); sfx('s_boss',buf)
print('done')
