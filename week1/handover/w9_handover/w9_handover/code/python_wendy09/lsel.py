import sys; sys.path.insert(0,'/home/claude/w8/lad')
import core, score, numpy as np, polars as pl, itertools, json, os
from bench import d2 as d2b
R=pl.read_parquet('/mnt/user-data/uploads/Kaggle_2026/output/4_check_reported/wendy07_final2/row_preds.parquet')
def avail(L,p,comp):
    fs=set()
    for f in os.listdir(core.LD+'preds'):
        pre=f'{L.line}_{p}_{comp}_'
        if f.startswith(pre): fs.add(f[len(pre):].rsplit('_',1)[0])
    return sorted(s for s in fs if all(core.has(L,p,comp,s,vy) for vy,_ in core.FOLDS))
def choose(line,fcands=None,scands=None,verbose=True):
    L=score.getL(line); res={}
    for p in core.PERILS[line]:
        F=[f for f in avail(L,p,'freq') if f!='F0' and (fcands is None or f in fcands)]
        S=[s for s in avail(L,p,'sev') if (scands is None or s in scands)]
        tab={}
        for f in F:
            for s in S:
                o=score.peril_scores(line,p,f,s); tab[(f,s)]=(o[2023]['d2'],o[2024]['d2'])
        best=max(tab,key=lambda k:np.mean(tab[k]))
        b23=max(tab,key=lambda k:tab[k][0]); b24=max(tab,key=lambda k:tab[k][1])
        res[p]=dict(best=best,score=tab[best],pick23_on24=tab[b23][1],pick24_on23=tab[b24][0],b23=b23,b24=b24,n=len(tab))
        if verbose: print(line,p.ljust(18),'best',best,np.round(tab[best],4),'| pick on 23',b23,'->24',round(tab[b23][1],4),'| pick on 24',b24,'->23',round(tab[b24][0],4),'| combos',len(tab))
    return res
def assemble(combos):
    """combos {line:{peril:(f,s)}} -> ALL and line D2 per fold vs final2"""
    out={}
    for vy in (2023,2024):
        ys=[];ps=[];es=[];fs=[];per={}
        for line,cb in combos.items():
            o,pr=score.line_scores(line,cb); rid,tot,y,e=pr[vy]
            f2=pl.DataFrame({'row_id':rid}).join(R.filter(pl.col('valid_year')==vy).select('row_id','pred','reported_raw'),on='row_id',how='left',maintain_order='left')
            assert np.allclose(f2['reported_raw'].to_numpy(),y), 'actual mismatch'
            per[line]=(core.d2(y,tot,e),core.d2(y,f2['pred'].to_numpy(),e))
            ys.append(y);ps.append(tot);es.append(e);fs.append(f2['pred'].to_numpy())
        y=np.concatenate(ys);p=np.concatenate(ps);e=np.concatenate(es);f=np.concatenate(fs)
        out[vy]=dict(ALL=core.d2(y,p,e),ALL_f2=core.d2(y,f,e),lines=per)
    return out
if __name__=='__main__':
    fc=sys.argv[1].split(',') if len(sys.argv)>1 and sys.argv[1]!='all' else None
    sc=sys.argv[2].split(',') if len(sys.argv)>2 and sys.argv[2]!='all' else None
    combos={}
    for line in ['motor','buildings','contents']:
        r=choose(line,fc,sc); combos[line]={p:v['best'] for p,v in r.items()}
    a=assemble(combos)
    for vy,v in a.items(): print(vy,'ALL ladder',round(v['ALL'],5),'final2',round(v['ALL_f2'],5),{k:(round(x,4),round(y,4)) for k,(x,y) in v['lines'].items()})
    json.dump({l:{p:list(v) for p,v in c.items()} for l,c in combos.items()},open(core.LD+'best_combo.json','w'))
