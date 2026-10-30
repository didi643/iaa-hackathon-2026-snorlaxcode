import sys; sys.path.insert(0,'/home/claude/w8/lad')
import core, numpy as np, polars as pl, lightgbm as lgb, fe, time
SEV_BASE=dict(objective='gamma',learning_rate=0.03,num_leaves=7,min_data_in_leaf=200,feature_fraction=0.8,bagging_fraction=0.8,bagging_freq=1,lambda_l2=10,verbose=-1,num_threads=2,seed=6,max_bin=63,cat_smooth=50,min_data_per_group=100)
def sev_gbm(L,p,vy,fy,feats,params,cap_q=0.995,trend=True,notrend=(),lo=-0.02,hi=0.10,fixed=None,prior=None,z=None,enc=None):
    g=core.sev_trend(L,p,fy,cap_q,lo,hi) if (trend and p not in notrend) else 0.0
    if fixed is not None: g=fixed
    if prior is not None: g=z*g+(1-z)*prior
    c,amt,cap,load=core.sev_frame(L,p,fy,cap_q,trend=g,target_year=vy)
    rid=L.d['row_id'].to_numpy(); idx={r:i for i,r in enumerate(rid)}
    rows=np.array([idx[r] for r in c['row_id'].to_list()])
    X=L.X(feats); ci=L.cat_idx(feats)
    if enc=='rate':
        X=X.copy(); mu=amt.mean()
        for i,f in enumerate(feats):
            if f not in L.cats: continue
            codes=np.nan_to_num(X[:,i],nan=-1).astype(np.int64)+1; m=codes.max()+1
            cr=codes[rows]; s_=np.bincount(cr,weights=amt,minlength=m); k_=np.bincount(cr,minlength=m)
            rate=(s_+30*mu)/(k_+30); order=np.argsort(np.argsort(rate)).astype(np.float32); X[:,i]=order[codes]
        ci=[]
    Xc=X[rows]
    h=(c['policy_id'].hash(3)%10==0).to_numpy()
    dt=lgb.Dataset(Xc[~h],amt[~h],categorical_feature=ci,free_raw_data=False); dv=lgb.Dataset(Xc[h],amt[h],reference=dt,categorical_feature=ci)
    m=lgb.train(params,dt,3000,valid_sets=[dv],callbacks=[lgb.early_stopping(100,verbose=False)])
    r=max(m.best_iteration,5); m=lgb.train(params,lgb.Dataset(Xc,amt,categorical_feature=ci),r)
    bal=amt.mean()/m.predict(Xc).mean()
    _,sc=L.masks(vy,fy)
    return m.predict(X[sc])*bal*load, r, g
if __name__=='__main__':
    line=sys.argv[1]; steps=sys.argv[2].split(','); perils=sys.argv[3].split(',') if len(sys.argv)>3 else core.PERILS[line]
    L=core.Line(line)
    for p in perils:
        for vy,fy in core.FOLDS:
            _,sc=L.masks(vy,fy); t=time.time()
            for st in steps:
                if core.has(L,p,'sev',st,vy): continue
                info=''
                if st=='S1':   # flat + trend
                    g=core.sev_trend(L,p,fy); c,amt,cap,load=core.sev_frame(L,p,fy,trend=g,target_year=vy)
                    arr=np.full(sc.sum(),amt.mean()*load); info=f'trend {g:.3f}'
                elif st=='S2':  # GBM all feats + trend
                    arr,r,g=sev_gbm(L,p,vy,fy,L.allfeats,SEV_BASE); info=f'rounds {r} trend {g:.3f}'
                elif st=='S3':  # additive stumps (GAM-like) + trend
                    arr,r,g=sev_gbm(L,p,vy,fy,L.allfeats,dict(SEV_BASE,num_leaves=2,max_depth=1,min_data_in_leaf=300)); info=f'rounds {r}'
                elif st=='S4':  # GBM, trend clamp [0,10%]
                    arr,r,g=sev_gbm(L,p,vy,fy,L.allfeats,SEV_BASE,lo=0.0); info=f'trend {g:.3f}'
                elif st=='S5':  # GBM, trend = 50% data (clamp -2..10) + 50% prior 5%
                    arr,r,g=sev_gbm(L,p,vy,fy,L.allfeats,SEV_BASE,prior=0.05,z=0.5); info=f'trend {g:.3f}'
                elif st=='S6':  # GBM, fixed 5% trend
                    arr,r,g=sev_gbm(L,p,vy,fy,L.allfeats,SEV_BASE,fixed=0.05); info=f'trend {g:.3f}'
                elif st=='S7':  # GBM, no trend
                    arr,r,g=sev_gbm(L,p,vy,fy,L.allfeats,SEV_BASE,trend=False); info='no trend'
                elif st=='S8':  # S4 with cap 0.99
                    arr,r,g=sev_gbm(L,p,vy,fy,L.allfeats,SEV_BASE,lo=0.0,cap_q=0.99); info=f'cap .99 trend {g:.3f}'
                elif st=='S9':  # S4 with cap 0.999
                    arr,r,g=sev_gbm(L,p,vy,fy,L.allfeats,SEV_BASE,lo=0.0,cap_q=0.999); info=f'cap .999 trend {g:.3f}'
                elif st=='SA':  # GBM no HC, trend clamp >=0
                    arr,r,g=sev_gbm(L,p,vy,fy,[f for f in L.allfeats if f not in ('previous_insurer','occupation')],SEV_BASE,lo=0.0); info=f'trend {g:.3f}'
                elif st=='SB':  # GBM rate-encoded, no HC, trend clamp >=0
                    arr,r,g=sev_gbm(L,p,vy,fy,[f for f in L.allfeats if f not in ('previous_insurer','occupation')],SEV_BASE,lo=0.0,enc='rate'); info=f'trend {g:.3f}'
                elif st=='SC':  # GBM rate-encoded all feats, trend clamp >=0
                    arr,r,g=sev_gbm(L,p,vy,fy,L.allfeats,SEV_BASE,lo=0.0,enc='rate'); info=f'trend {g:.3f}'
                elif st=='S1n': # flat, no trend
                    c,amt,cap,load=core.sev_frame(L,p,fy); arr=np.full(sc.sum(),amt.mean()*load)
                core.save(L,p,'sev',st,vy,arr); print(line,p,vy,st,info,round(time.time()-t),flush=True)
