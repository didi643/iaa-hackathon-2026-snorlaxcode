import sys; sys.path.insert(0,'/home/claude/w8/lad')
import core, numpy as np, json, polars as pl
from assemble import frames
combos=json.load(open(core.LD+'assemble_combo.json')); combos={l:{p:tuple(v) for p,v in c.items()} for l,c in combos.items()}
wts=json.load(open(core.LD+'assemble_weights.json'))
F={l:frames(l,combos[l]) for l in combos}
def cand(l,vy):
    d=F[l][vy]; W=wts['W'][l]; pb=sum(W[p]*d['mine'][p]+(1-W[p])*d['c5'][p] for p in core.PERILS[l])
    b=wts['LW'][l]*pb+(1-wts['LW'][l])*d['s3']; q=b*d['M']; return q*b.sum()/q.sum()
def wd2(y,mu,e,w):
    P=1.5; mu=np.maximum(mu,1e-9)
    dev=lambda m: np.sum(w*(np.where(y>0,y**(2-P)/((1-P)*(2-P)),0)-y*m**(1-P)/(1-P)+m**(2-P)/(2-P)))
    return 1-dev(mu)/dev(e*np.sum(w*y)/np.sum(w*e))
D={}
for vy in (2023,2024):
    y=np.concatenate([sum(F[l][vy]['act'].values()) for l in F]); e=np.concatenate([F[l][vy]['e'] for l in F])
    q=np.concatenate([cand(l,vy) for l in F]); f=np.concatenate([F[l][vy]['f2'] for l in F]); pol=np.concatenate([F[l][vy]['pol'] for l in F])
    D[vy]=(y,e,q,f,pol); print(vy,'final2',round(core.d2(y,f,e),5),'W9',round(core.d2(y,q,e),5))
pols=np.unique(np.concatenate([D[v][4] for v in D])); idx={p:i for i,p in enumerate(pols)}
pid={vy:pl.Series(D[vy][4]).replace_strict(idx).to_numpy() for vy in D}
rng=np.random.default_rng(42); g=[]
for b in range(200):
    cnt=np.bincount(rng.integers(0,len(pols),len(pols)),minlength=len(pols))
    g.append(np.mean([wd2(D[vy][0],D[vy][2],D[vy][1],cnt[pid[vy]])-wd2(D[vy][0],D[vy][3],D[vy][1],cnt[pid[vy]]) for vy in D]))
g=np.array(g); print('W9 vs final2 mean 2023-24 gain',round(g.mean(),5),'2SE',round(2*g.std(),5),'share>0',(g>0).mean())
