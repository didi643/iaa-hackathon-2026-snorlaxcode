"""WENDY 9 blend from the handover panel only (no model refits).
Usage: python3 scripts/w9_blend.py [out.csv]
Edit W / LW / A below (or swap lad_<peril> columns) and rerun; prints fold D2 by stage and writes the 2025 submission."""
import sys, numpy as np, polars as pl
PERILS={'motor':['own_damage','third_party_prop','bodily_injury','theft','glass_hail'],
        'buildings':['storm','flood','escape_of_water','subsidence','fire','accidental_damage'],
        'contents':['theft','escape_of_water','accidental_damage','flood']}
W={'motor':dict(own_damage=0,third_party_prop=1,bodily_injury=0,theft=0,glass_hail=1),          # weight on ladder vs C5, per peril
   'buildings':dict(storm=1,flood=0,escape_of_water=0,subsidence=.5,fire=.25,accidental_damage=.25),
   'contents':dict(theft=0,escape_of_water=.75,accidental_damage=0,flood=.75)}
LW={'motor':.9,'buildings':.7,'contents':.9}   # weight on peril blend vs SAM 3, per line
A={'motor':8,'buildings':5,'contents':5}       # credibility constant: M=(A+N)/(A+E), rescaled to keep line total
def tdev(y,mu,p=1.5):
    mu=np.maximum(mu,1e-12); return 2*np.sum(np.where(y>0,y**(2-p)/((1-p)*(2-p)),0)-y*mu**(1-p)/(1-p)+mu**(2-p)/(2-p))
def d2(y,mu,e): return 1-tdev(y,mu)/tdev(y,e*y.sum()/e.sum())
def preds(P,line):
    f=lambda c: P[c].fill_null(0).to_numpy().astype(float)
    pb=sum(W[line][p]*f(f'lad_{p}')+(1-W[line][p])*f(f'c5_{p}') for p in PERILS[line])
    b=LW[line]*pb+(1-LW[line])*f('sam3')
    M=(A[line]+f('N'))/(A[line]+f('E')); q=b*M; q=q*b.sum()/q.sum()
    return dict(c5=sum(f(f'c5_{p}') for p in PERILS[line]),peril_blend=pb,line_blend=b,final=q)
D={l:pl.read_parquet(f'panel/panel_{l}.parquet') for l in PERILS}
for l,P in D.items():
    for p in PERILS[l]:
        if W[l][p]>0: assert P.filter(pl.col('valid_year')==2025)[f'lad_{p}'].null_count()==0, f'no 2025 ladder pred for {l} {p}: refit needed'
res={}
for vy in (2023,2024):
    ys,es,ps,pf2={},[],{},[]
    for l,P in D.items():
        Q=P.filter(pl.col('valid_year')==vy); y=sum(Q[f'act_{p}'].to_numpy().astype(float) for p in PERILS[l])
        ys.setdefault('y',[]).append(y); es.append(Q['exposure'].to_numpy().astype(float)); pf2.append(Q['final2'].to_numpy().astype(float))
        for k,v in preds(Q,l).items(): ps.setdefault(k,[]).append(v)
        res[(l,vy)]=d2(y,ps['final'][-1],es[-1])
    y=np.concatenate(ys['y']); e=np.concatenate(es)
    print(vy,'all lines D2 | final2 %.5f'%d2(y,np.concatenate(pf2),e),' '.join(f'| {k} {d2(y,np.concatenate(v),e):.5f}' for k,v in ps.items()))
print('line D2 (final):',{f'{l} {vy}':round(v,5) for (l,vy),v in res.items()})
out=pl.concat([pl.DataFrame({'row_id':P.filter(pl.col('valid_year')==2025)['row_id'],'prediction':preds(P.filter(pl.col('valid_year')==2025),l)['final']}) for l,P in D.items()])
assert out.height==626639 and out['prediction'].min()>=0
out.write_csv(sys.argv[1] if len(sys.argv)>1 else 'submission_w9_rebuilt.csv'); print('written',out.height)
