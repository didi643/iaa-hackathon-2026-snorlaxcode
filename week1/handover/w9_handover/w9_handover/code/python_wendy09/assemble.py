import sys; sys.path.insert(0,'/home/claude/w8/lad')
import core, score, numpy as np, polars as pl, json
from swap import C5, MIX
from lsel import choose
R=pl.read_parquet('/mnt/user-data/uploads/Kaggle_2026/output/4_check_reported/wendy07_final2/row_preds.parquet')
S3=pl.read_parquet('/mnt/user-data/uploads/Kaggle_2026/output/4_check_reported/sam03/row_preds_models.parquet').select('valid_year','row_id','blend')
A={'motor':8,'buildings':5,'contents':5}
GRID=np.array([0,.25,.5,.75,1.0])
def frames(line,combo):
    L=score.getL(line); out={}
    hd=pl.read_parquet(f'/home/claude/w8/hd_{line}.parquet').select('row_id','N','E')
    for vy,fy in core.FOLDS:
        tr,sc=L.masks(vy,fy); rid=L.d['row_id'].to_numpy()[sc]
        base=pl.DataFrame({'row_id':rid})
        c=base.join(C5.filter(pl.col('valid_year')==vy),on='row_id',how='left',maintain_order='left')
        f2=base.join(R.filter(pl.col('valid_year')==vy).select('row_id','pred'),on='row_id',how='left',maintain_order='left')['pred'].to_numpy()
        s3=base.join(S3.filter(pl.col('valid_year')==vy),on='row_id',how='left',maintain_order='left')['blend'].to_numpy()
        h=base.join(hd,on='row_id',how='left',maintain_order='left'); M=((A[line]+h['N'])/(A[line]+h['E'])).to_numpy()
        mine={};c5={};act={}
        for p in core.PERILS[line]:
            f,s=combo[p]; mine[p]=core.load(L,p,'freq',f,vy)*core.load(L,p,'sev',s,vy)
            c5[p]=c[f'pred_{p}_{MIX[line][p]}'].to_numpy(); act[p]=core.actual(L,p,vy)
        out[vy]=dict(mine=mine,c5=c5,act=act,e=L.expo[sc],f2=f2,s3=s3,M=M,pol=L.d['policy_id'].to_numpy()[sc])
    return out
def run(combo_all,verbose=True):
    F={l:frames(l,combo_all[l]) for l in combo_all}
    stages={}
    def all_d2(get):
        r={}
        for vy in (2023,2024):
            ys=[];ps=[];es=[]
            for l in F:
                d=F[l][vy]; ys.append(sum(d['act'].values())); ps.append(get(l,vy)); es.append(d['e'])
            r[vy]=core.d2(np.concatenate(ys),np.concatenate(ps),np.concatenate(es))
        return r
    stages['final2']=all_d2(lambda l,vy:F[l][vy]['f2'])
    stages['C5 alone']=all_d2(lambda l,vy:sum(F[l][vy]['c5'].values()))
    stages['ladder alone']=all_d2(lambda l,vy:sum(F[l][vy]['mine'].values()))
    # per-peril blend weight (on mine) chosen on mean of folds
    W={}
    for l in F:
        W[l]={}
        for p in core.PERILS[l]:
            sc=[]
            for w in GRID:
                v=[]
                for vy in (2023,2024):
                    d=F[l][vy]; tot=sum(d['c5'].values())-d['c5'][p]+(w*d['mine'][p]+(1-w)*d['c5'][p])
                    v.append(core.d2(sum(d['act'].values()),tot,d['e']))
                sc.append(v)
            sc=np.array(sc); W[l][p]=dict(w=float(GRID[np.argmax(sc.mean(1))]),w23=float(GRID[np.argmax(sc[:,0])]),w24=float(GRID[np.argmax(sc[:,1])]),gain=(sc.max(0)-sc[0]).round(5).tolist())
    def peril_blend(l,vy):
        d=F[l][vy]; return sum(W[l][p]['w']*d['mine'][p]+(1-W[l][p]['w'])*d['c5'][p] for p in core.PERILS[l])
    stages['C5 x ladder per-peril blend']=all_d2(peril_blend)
    # line blend with SAM3, weight on W9 chosen on mean of folds
    LW={}
    for l in F:
        sc=[]
        for a in np.arange(0,1.01,0.1):
            sc.append([core.d2(sum(F[l][vy]['act'].values()),a*peril_blend(l,vy)+(1-a)*F[l][vy]['s3'],F[l][vy]['e']) for vy in (2023,2024)])
        sc=np.array(sc); LW[l]=float(np.arange(0,1.01,0.1)[np.argmax(sc.mean(1))])
    def line_blend(l,vy): return LW[l]*peril_blend(l,vy)+(1-LW[l])*F[l][vy]['s3']
    stages['+ SAM3 line blend']=all_d2(line_blend)
    def cred(l,vy):
        b=line_blend(l,vy); q=b*F[l][vy]['M']; return q*b.sum()/q.sum()
    stages['+ credibility']=all_d2(cred)
    if verbose:
        for k,v in stages.items(): print(f'{k:32s} 2023 {v[2023]:.5f}  2024 {v[2024]:.5f}  mean {np.mean(list(v.values())):.5f}  vs final2 {np.mean(list(v.values()))-np.mean(list(stages["final2"].values())):+.5f}')
        print('per-peril weights on ladder:',{l:{p:(v['w'],v['w23'],v['w24']) for p,v in W[l].items()} for l in W})
        print('line weights on peril-blend vs SAM3:',LW)
    json.dump({'W':{l:{p:v['w'] for p,v in W[l].items()} for l in W},'LW':LW,'stages':{k:{str(a):b for a,b in v.items()} for k,v in stages.items()}},open(core.LD+'assemble_weights.json','w'))
    return stages,W,LW,F
if __name__=='__main__':
    fc=sys.argv[1].split(','); scs=sys.argv[2].split(',')
    combos={}
    for l in ['motor','buildings','contents']:
        r=choose(l,fc,scs,verbose=False); combos[l]={p:v['best'] for p,v in r.items()}
        print(l,{p:v['best'] for p,v in r.items()})
    run(combos)
    json.dump(combos,open(core.LD+'assemble_combo.json','w'))
