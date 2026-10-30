import sys; sys.path.insert(0,'/home/claude/w8/lad')
import core, numpy as np, time, json
P2A=dict(num_leaves=8,max_depth=3,min_data_in_leaf=100,min_sum_hessian_in_leaf=60)
HC=('previous_insurer','occupation')
PROP=('soil_type','year_built','property_type','roof_type','basement','trees_within_5m','listed_building','bedrooms','energy_rating','solar_panels','flood_zone','distance_to_river_km','elevation_m')
WX=('hail_days','wind_exposure_index','freezing_days','dry_summer_index','wildfire_index','rainfall_mm','mean_temperature_c','lr_hail_days','lr_wind_exposure_index','lr_freezing_days','lr_dry_summer_index','lr_wildfire_index','lr_rainfall_mm','lr_mean_temperature_c')
VAR={
 'F5':dict(params=P2A,feats=lambda L,p:L.allfeats+L.histfeats+[f'Np_{p}']),
 'F6':dict(params=P2A,feats=lambda L,p:[f for f in L.allfeats if f not in HC]+L.histfeats+[f'Np_{p}']),
 'F7':dict(params=P2A,enc='rate'),
 'F8':dict(params=P2A,enc='rate',feats=lambda L,p:[f for f in L.allfeats if f not in HC]),
 'F9':dict(params=P2A,feats=lambda L,p:[f for f in L.allfeats if f not in HC]+L.seafeats),
 'F10':dict(params=P2A,feats=lambda L,p:[f for f in L.allfeats if f not in HC]+L.seafeats+['days_quote_to_inception']),
 'F11':dict(params=P2A,enc='rate',feats=lambda L,p:[f for f in L.allfeats if f not in HC and f not in PROP and (f not in WX or (p=='glass_hail' and f in ('hail_days','wind_exposure_index','freezing_days','lr_hail_days')))]),
 'F12':dict(params=P2A,enc='rate',feats=lambda L,p:[f for f in L.allfeats if f not in HC and f not in PROP and (f not in WX or (p=='glass_hail' and f in ('hail_days','wind_exposure_index','freezing_days','lr_hail_days')))]+L.seafeats),
 'G1':dict(params=dict(P2A,num_leaves=16,max_depth=4),enc=None,feats='BASE'),
 'G2':dict(params=dict(P2A,min_sum_hessian_in_leaf=20),feats='BASE'),
 'G3':dict(params=dict(P2A,min_sum_hessian_in_leaf=150),feats='BASE'),
 'G4':dict(params=dict(P2A,num_leaves=4,max_depth=2),feats='BASE'),
 'G5':dict(params=dict(P2A,num_leaves=2,max_depth=1,learning_rate=0.1),feats='BASE'),
 'G6':dict(params=dict(P2A,num_leaves=4,max_depth=2,min_sum_hessian_in_leaf=150),feats='BASE'),
 'G7':dict(params=dict(P2A,num_leaves=3,max_depth=2,min_sum_hessian_in_leaf=60),feats='BASE'),
 'G8':dict(params=dict(P2A,min_sum_hessian_in_leaf=6),feats='BASE'),
 'G9':dict(params=dict(P2A,num_leaves=16,max_depth=4,min_sum_hessian_in_leaf=20),feats='BASE'),
 'F4':dict(params=P2A,feats=lambda L,p:[f for f in L.allfeats if f not in HC]),
 'F2a':dict(params=dict(num_leaves=8,max_depth=3,min_data_in_leaf=100,min_sum_hessian_in_leaf=60)),
 'F2b':dict(params=dict(num_leaves=16,max_depth=4,min_data_in_leaf=100,min_sum_hessian_in_leaf=200)),
 'F2c':dict(params=dict(num_leaves=8,max_depth=3,min_data_in_leaf=100,min_sum_hessian_in_leaf=200)),
}
def run(line,steps,perils=None,feats_fn=None,extra=None):
    L=core.Line(line)
    for p in perils or core.PERILS[line]:
        for st in steps:
            v=dict((extra or VAR)[st])
            if v.get('feats')=='BASE':   # line-specific base recipe: motor = F8 (rate enc, no HC); home = F4 (no HC)
                v['feats']=lambda L,p:[f for f in L.allfeats if f not in HC]
                v['enc']='rate' if line=='motor' else None
            feats=v.get('feats',lambda L,p:L.allfeats)(L,p)
            prm=core.lgb_params(core.FREQ_BASE,**v.get('params',{}))
            for vy,fy in core.FOLDS:
                if core.has(L,p,'freq',st,vy): continue
                t=time.time(); pr,r=core.fit_freq(L,p,feats,vy,fy,prm,mono=v.get('mono',{}) and v['mono'](L,p),enc=v.get('enc')); core.save(L,p,'freq',st,vy,pr)
                print(line,p,st,vy,'rounds',r,'nfeat',len(feats),round(time.time()-t),flush=True)
if __name__=='__main__':
    run(sys.argv[1],sys.argv[2].split(','),sys.argv[3].split(',') if len(sys.argv)>3 else None)
