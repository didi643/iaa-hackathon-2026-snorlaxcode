import sys; sys.path.insert(0,'/home/claude/w8/lad')
import core, score, numpy as np, polars as pl, json
C5=pl.read_parquet('/mnt/user-data/uploads/Kaggle_2026/output/4_check_reported/wendy07_c5/row_preds_peril.parquet')
MIX={'motor':{'own_damage':'freq_sev','third_party_prop':'freq_sev','bodily_injury':'tweedie','theft':'freq_sev','glass_hail':'freq_sev'},
     'buildings':{p:'freq_sev' for p in core.PERILS['buildings']},
     'contents':{'theft':'freq_sev','escape_of_water':'tweedie','accidental_damage':'freq_sev','flood':'freq_sev'}}
best=json.load(open(core.LD+'best_combo.json'))
def get(line,vy):
    L=score.getL(line); tr,sc=L.masks(vy,[])
    rid=L.d['row_id'].to_numpy()[sc]
    c=pl.DataFrame({'row_id':rid}).join(C5.filter(pl.col('valid_year')==vy),on='row_id',how='left',maintain_order='left')
    mine={};c5={};act={}
    for p in core.PERILS[line]:
        f,s=best[line][p]; mine[p]=core.load(L,p,'freq',f,vy)*core.load(L,p,'sev',s,vy)
        c5[p]=c[f'pred_{p}_{MIX[line][p]}'].to_numpy(); act[p]=core.actual(L,p,vy)
        assert np.allclose(c[f'reported_raw_{p}'].to_numpy(),act[p]),p
    return mine,c5,act,L.expo[sc]
if __name__=='__main__':
    for line in ['motor','buildings','contents']:
        for vy in (2023,2024):
            mine,c5,act,e=get(line,vy); y=sum(act.values())
            M=sum(mine.values()); C=sum(c5.values())
            print(f'{line} {vy} line D2 mine {core.d2(y,M,e):.4f} C5 {core.d2(y,C,e):.4f} 50/50 {core.d2(y,.5*M+.5*C,e):.4f}')
            for p in core.PERILS[line]:
                sw=M-mine[p]+c5[p]; sw2=C-c5[p]+mine[p]
                print(f'   {p:18s} peril d2 mine {core.d2(act[p],mine[p],e):.4f} C5 {core.d2(act[p],c5[p],e):.4f} 50/50 {core.d2(act[p],.5*mine[p]+.5*c5[p],e):.4f} | AE mine {act[p].sum()/mine[p].sum():.2f} C5 {act[p].sum()/c5[p].sum():.2f} | line: mine+C5_p {core.d2(y,sw,e)-core.d2(y,M,e):+.4f}  C5+mine_p {core.d2(y,sw2,e)-core.d2(y,C,e):+.4f}')
