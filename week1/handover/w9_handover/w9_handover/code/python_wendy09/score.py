import sys; sys.path.insert(0,'/home/claude/w8/lad')
import core, numpy as np, polars as pl
_L={}
def getL(line):
    if line not in _L: _L[line]=core.Line(line)
    return _L[line]
def peril_scores(line,peril,fstep,sstep):
    L=getL(line); out={}
    for vy,fy in core.FOLDS:
        tr,sc=L.masks(vy,fy)
        f=core.load(L,peril,'freq',fstep,vy); s=core.load(L,peril,'sev',sstep,vy)
        y=core.actual(L,peril,vy); e=L.expo[sc]
        n=L.d[f'n_{peril}'].to_numpy()[sc]; sh=L.d[f's_{peril}'].to_numpy()[sc]
        f0=core.load(L,peril,'freq','F0',vy)
        fd2=1-core.pdev(n,f*sh)/core.pdev(n,f0*sh)
        out[vy]=dict(d2=core.d2(y,f*s,e),fd2=fd2,ae=y.sum()/(f*s).sum())
    return out
def line_scores(line,combo):
    """combo: {peril:(fstep,sstep)} -> line D2 per fold (reported_raw), plus preds"""
    L=getL(line); out={}; preds={}
    for vy,fy in core.FOLDS:
        tr,sc=L.masks(vy,fy); tot=np.zeros(sc.sum()); y=np.zeros(sc.sum())
        for p in core.PERILS[line]:
            fs,ss=combo.get(p,('F0','S0'))
            tot+=core.load(L,p,'freq',fs,vy)*core.load(L,p,'sev',ss,vy); y+=core.actual(L,p,vy)
        out[vy]=core.d2(y,tot,L.expo[sc]); preds[vy]=(L.d['row_id'].to_numpy()[sc],tot,y,L.expo[sc])
    return out,preds
def peril_scores_star(line,peril,fstep,sstep):
    L=getL(line); out={}
    for vy,fy in core.FOLDS:
        tr,sc=L.masks(vy,fy)
        mu=core.load(L,peril,'freq',fstep,vy)*core.load(L,peril,'sev',sstep,vy)
        y=core.actual(L,peril,vy); e=L.expo[sc]
        best=max(core.d2(y,mu*k,e) for k in np.exp(np.linspace(-0.4,0.4,33)))
        out[vy]=(core.d2(y,mu,e),best)
    return out
