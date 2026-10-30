import sys; sys.path.insert(0,'/home/claude/w8')
import fe, polars as pl, numpy as np, lightgbm as lgb, os, json, time
from bench import BASE_EXCL
P=1.5
VAL=np.datetime64('2025-01-01').astype('datetime64[D]').astype(np.int64)
LD='/home/claude/w8/lad/'
PERILS={'motor':['own_damage','third_party_prop','bodily_injury','theft','glass_hail'],
        'buildings':['storm','flood','escape_of_water','subsidence','fire','accidental_damage'],
        'contents':['theft','escape_of_water','accidental_damage','flood']}
FOLDS=[(2025,[2021,2022,2023,2024])] if os.environ.get('LAD_FINAL') else [(2023,[2021,2022]),(2024,[2021,2022,2023])]
def tdev(y,mu):
    mu=np.maximum(mu,1e-9)
    return 2*np.sum(np.where(y>0, y**(2-P)/((1-P)*(2-P)),0) - y*mu**(1-P)/(1-P) + mu**(2-P)/(2-P))
def d2(y,mu,e): return 1-tdev(y,mu)/tdev(y,e*y.sum()/e.sum())
def pdev(y,mu):
    mu=np.maximum(mu,1e-12); return 2*np.sum(np.where(y>0,y*np.log(np.where(y>0,y,1)/mu),0)-(y-mu))
def share_rows(lag,s,e,cut=VAL):
    s=s.astype('datetime64[D]').astype(np.int64); e=e.astype('datetime64[D]').astype(np.int64); acc=np.zeros(len(s))
    for q in (np.arange(16)+.5)/16: acc+=np.searchsorted(lag,cut-(s+(e-s)*q),side='right')/len(lag)
    return np.maximum(acc/16,0.03)
class Line:
    def __init__(self,line):
        self.line=line
        cache=LD+f'data_{line}.parquet'
        if os.path.exists(cache) and os.path.exists(cache+'.cats.json'):
            d=pl.read_parquet(cache); cj=json.load(open(cache+'.cats.json')); fe.CATS=set(cj['cats']); fe.CATMAX=cj['catmax']
        else:
            d=fe.load(line)
            hd=pl.read_parquet(f'/home/claude/w8/hd_{line}.parquet').select('row_id','N','E')
            d=d.join(hd,on='row_id',how='left')
            c=pl.read_parquet(f'/home/claude/w8/claims_rows_{line}.parquet').filter(pl.col('status')!='repudiated')
            for p in PERILS[line]:
                cp=c.filter(pl.col('peril')==p)
                agg=cp.group_by('row_id').agg(pl.col('net').sum().alias(f'c_{p}'),(pl.col('net')>0).sum().alias(f'n_{p}'))
                d=d.join(agg,on='row_id',how='left').with_columns(pl.col(f'c_{p}',f'n_{p}').fill_null(0))
                cl=cp.filter(pl.col('loss_date').dt.year()<=2022)
                lag=np.sort(np.maximum((cl['report_date'].cast(pl.Date)-cl['loss_date']).dt.total_days().to_numpy(),0))
                d=d.with_columns(pl.Series(f's_{p}',share_rows(lag,d['period_start'].to_numpy(),d['period_end'].to_numpy())))
            d.write_parquet(cache); json.dump({'cats':sorted(fe.CATS),'catmax':fe.CATMAX},open(cache+'.cats.json','w'))
        hd=pl.read_parquet(f'/home/claude/w8/hd_{line}.parquet').drop('N','E')
        d=d.join(hd,on='row_id',how='left',maintain_order='left')
        sd=d['period_start'].dt.ordinal_day().to_numpy(); ed=d['period_end'].dt.ordinal_day().to_numpy()
        days=np.arange(1,367)[None,:]
        qs={}
        for qi,(a,b) in enumerate([(1,90),(91,181),(182,273),(274,366)]):
            lo=np.maximum(sd,a); hi=np.minimum(ed,b); qs[f'sea_q{qi+1}']=np.maximum(hi-lo+1,0)/np.maximum(ed-sd+1,1)
        d=d.with_columns(start_doy=pl.Series(sd),end_doy=pl.Series(ed),**{k:pl.Series(v) for k,v in qs.items()})
        d=d.with_columns(cred5=(5+pl.col('N'))/(5+pl.col('E')),credd=(3+pl.col('N_d0.6'))/(3+pl.col('E_d0.6')),N_c=pl.col('N').clip(0,4))
        self.d=d
        self.cats=set(fe.CATS); self.catmax=dict(fe.CATMAX)
        self.allfeats=[c for c in d.columns if c not in fe.DROP and c not in BASE_EXCL and not c.startswith(('c_','n_','s_','Np_','N_d','E_d','S_d')) and c not in ('N','E','cred5','credd','N_c','start_doy','end_doy','sea_q1','sea_q2','sea_q3','sea_q4')]
        self.seafeats=['start_doy','end_doy','sea_q1','sea_q2','sea_q3','sea_q4']
        self.histfeats=['N_c','cred5','credd']
        self.claims=pl.read_parquet(f'/home/claude/w8/claims_rows_{line}.parquet').filter((pl.col('status')!='repudiated')&(pl.col('net')>0))
        self.year=d['year'].to_numpy(); self.is_test=d['is_test'].to_numpy()==1
        self.expo=d['exposure'].to_numpy()
        self.hold=(d['policy_id'].hash(3)%10==0).to_numpy()
        self._X={}
    def X(self,feats):
        key=tuple(feats)
        if key not in self._X:
            self._X={}  # keep one
            M=np.empty((self.d.height,len(feats)),dtype=np.float32)
            for i,f in enumerate(feats): M[:,i]=self.d[f].cast(pl.Float32).to_numpy()
            self._X[key]=M
        return self._X[key]
    def cat_idx(self,feats): return [i for i,f in enumerate(feats) if f in self.cats]
    def masks(self,vy,fy):
        tr=np.isin(self.year,fy)&~self.is_test
        sc=(self.year==vy)&~self.is_test if vy<2025 else self.is_test
        return tr,sc
def lgb_params(base,**kw):
    p=dict(base); p.update(kw); return p
FREQ_BASE=dict(objective='poisson',learning_rate=0.05,num_leaves=31,min_data_in_leaf=500,feature_fraction=0.7,bagging_fraction=0.8,bagging_freq=1,lambda_l2=10,verbose=-1,num_threads=2,seed=5,max_bin=127,cat_smooth=20,min_data_per_group=200)
def rate_encode(L,X,feats,tr,n,w,k=None):
    """replace categorical columns by rank of credibility-weighted training rate; returns new X and empty cat list"""
    X=X.copy(); base=n[tr].sum()/w[tr].sum()
    for i,f in enumerate(feats):
        if f not in L.cats: continue
        col=X[:,i]; codes=np.nan_to_num(col,nan=-1).astype(np.int64)+1
        m=codes.max()+1
        nn=np.bincount(codes[tr],weights=n[tr],minlength=m); ww=np.bincount(codes[tr],weights=w[tr],minlength=m)
        kk=k if k is not None else 1.0/base*20   # credibility: ~20 expected claims
        rate=(nn+20)/(ww+kk)
        order=np.argsort(np.argsort(rate)).astype(np.float32)
        X[:,i]=order[codes]
    return X,[]
def fit_freq(L,peril,feats,vy,fy,params=FREQ_BASE,mono=None,rounds=None,ret_model=False,enc=None):
    """returns expected claim count (ultimate) on score rows, balanced to training"""
    tr,sc=L.masks(vy,fy); X=L.X(feats)
    n=L.d[f'n_{peril}'].to_numpy().astype(float); w=L.expo*L.d[f's_{peril}'].to_numpy()
    y=n/w
    prm=dict(params)
    if mono: prm['monotone_constraints']=[mono.get(f,0) for f in feats]; prm['monotone_constraints_method']='advanced'
    ci=L.cat_idx(feats)
    if enc=='rate': X,ci=rate_encode(L,X,feats,tr,n,w)
    itr=np.where(tr)[0]; h=L.hold[itr]
    if rounds is None:
        dt=lgb.Dataset(X[itr[~h]],y[itr[~h]],weight=w[itr[~h]],categorical_feature=ci,free_raw_data=False)
        dv=lgb.Dataset(X[itr[h]],y[itr[h]],weight=w[itr[h]],reference=dt,categorical_feature=ci)
        m=lgb.train(prm,dt,3000,valid_sets=[dv],callbacks=[lgb.early_stopping(100,verbose=False)])
        rounds=max(m.best_iteration,10)
    m=lgb.train(prm,lgb.Dataset(X[itr],y[itr],weight=w[itr],categorical_feature=ci),rounds)
    ptr=m.predict(X[itr])*w[itr]; bal=n[itr].sum()/ptr.sum()
    p=m.predict(X[sc])*L.expo[sc]*bal
    return (p,rounds,m) if ret_model else (p,rounds)
def sev_frame(L,peril,fy,cap_q=0.995,trend=None,target_year=None):
    c=L.claims.filter((pl.col('peril')==peril)&pl.col('loss_date').dt.year().is_in(fy)).with_columns(ly=pl.col('loss_date').dt.year())
    cap=c['net'].quantile(cap_q); load=c['net'].sum()/c['net'].clip(0,cap).sum()
    amt=c['net'].clip(0,cap).to_numpy()
    if trend is not None and target_year is not None: amt=amt*np.exp(trend*(target_year-c['ly'].to_numpy()))
    return c,amt,cap,load
def sev_trend(L,peril,fy,cap_q=0.995,lo=-0.02,hi=0.10):
    c=L.claims.filter((pl.col('peril')==peril)&pl.col('loss_date').dt.year().is_in(fy)).with_columns(ly=pl.col('loss_date').dt.year())
    cap=c['net'].quantile(cap_q)
    s=c.group_by('ly').agg(pl.col('net').clip(0,cap).mean().alias('s'),pl.len().alias('k')).sort('ly')
    if s.height<2: return 0.0
    b=np.polyfit(s['ly'].to_numpy(),np.log(s['s'].to_numpy()),1,w=np.sqrt(s['k'].to_numpy()))[0]
    return float(np.clip(b,lo,hi))
def save(L,peril,comp,step,vy,arr): np.save(LD+f'preds/{L.line}_{peril}_{comp}_{step}_{vy}.npy',arr)
def load(L,peril,comp,step,vy): return np.load(LD+f'preds/{L.line}_{peril}_{comp}_{step}_{vy}.npy')
def has(L,peril,comp,step,vy): return os.path.exists(LD+f'preds/{L.line}_{peril}_{comp}_{step}_{vy}.npy')
def actual(L,peril,vy):
    _,sc=L.masks(vy,[]); return L.d[f'c_{peril}'].to_numpy()[sc]
def log(rec):
    with open(LD+'register.jsonl','a') as f: f.write(json.dumps(rec)+'\n')
