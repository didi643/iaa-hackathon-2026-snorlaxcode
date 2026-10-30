import os, sys, json, subprocess
sys.path.insert(0,'/home/claude/w8/lad')
LD='/home/claude/w8/lad/'
combo=json.load(open(LD+'assemble_combo.json')); wts=json.load(open(LD+'assemble_weights.json'))
env=dict(os.environ,LAD_FINAL='1')
if __name__=='__main__' and sys.argv[1]=='fit':
    for line,c in combo.items():
        for p,(f,s) in c.items():
            if wts['W'][line][p]<=0: continue
            subprocess.run(['python3','-c',f"import sys;sys.path.insert(0,'{LD}');import run_freq;run_freq.run('{line}',['{f}'],['{p}'])"],env=env,check=True)
            subprocess.run(['python3',LD+'run_sev.py',line,s,p],env=env,check=True)
            print('fitted',line,p,f,s,flush=True)
if __name__=='__main__' and sys.argv[1]=='build':
    os.environ['LAD_FINAL']='1'
    import core, numpy as np, polars as pl
    U='/mnt/user-data/uploads/Kaggle_2026/'
    C5T=pl.read_parquet(U+'models/wendy_iteration_07/c5/test_preds_peril.parquet')
    S3T=pl.read_parquet(LD+'sam3_test.parquet')
    A={'motor':8,'buildings':5,'contents':5}
    parts=[]
    for line,c in combo.items():
        L=core.Line(line); sc=L.is_test; rid=L.d['row_id'].to_numpy()[sc]
        base=pl.DataFrame({'row_id':rid})
        c5=base.join(C5T,on='row_id',how='left',maintain_order='left'); s3=base.join(S3T,on='row_id',how='left',maintain_order='left')['s3'].to_numpy()
        hd=base.join(pl.read_parquet(f'/home/claude/w8/hd_{line}.parquet').select('row_id','N','E'),on='row_id',how='left',maintain_order='left')
        pb=np.zeros(len(rid)); info={}
        for p,(f,s) in c.items():
            w=wts['W'][line][p]; cp=c5[f'pred_{p}'].to_numpy()
            if w>0:
                mp=core.load(L,p,'freq',f,2025)*core.load(L,p,'sev',s,2025)
            else: mp=0*cp
            pb+=w*mp+(1-w)*cp
            info[p]=(w,round(float(mp.sum()/L.expo[sc].sum()),1),round(float(cp.sum()/L.expo[sc].sum()),1))
        lw=wts['LW'][line]; b=lw*pb+(1-lw)*s3
        M=((A[line]+hd['N'])/(A[line]+hd['E'])).to_numpy(); q=b*M; q=q*b.sum()/q.sum()
        e=L.expo[sc]
        print(line,'LW',lw,'burn: peril-blend',round(pb.sum()/e.sum(),1),'SAM3',round(s3.sum()/e.sum(),1),'final',round(q.sum()/e.sum(),1))
        for p,v in info.items(): print('   ',p,'w_ladder',v[0],'burn ladder',v[1],'C5',v[2])
        assert np.isfinite(q).all() and (q>=0).all()
        parts.append(pl.DataFrame({'row_id':rid,'prediction':q}))
    ss=pl.read_parquet(U+'data/week_1/sample_submission.parquet').select('row_id')
    out=ss.join(pl.concat(parts),on='row_id',how='left',maintain_order='left')
    assert out.height==626639 and out['prediction'].null_count()==0
    f2=pl.read_csv(U+'output/submission/submission_20261022_2328_wendy07_final2.csv')
    print('corr with final2',np.corrcoef(out['prediction'].to_numpy(),f2['prediction'].to_numpy())[0,1])
    out.write_csv(LD+'submission_20261023_wendy09.csv'); print('written')
