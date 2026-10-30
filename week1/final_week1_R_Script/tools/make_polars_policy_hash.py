# make_polars_policy_hash.py ----------------------------------------------------------------------------------------
# One-off helper (the only non-R step): WENDY 8 / WENDY 9 were built in Python with polars 2.0.0 and split policies by
# polars' own string hash, which R cannot compute:
#   prior.py   4 policy folds of the a-priori claim-count model      fold   = policy_id.hash(13) % 4
#   core.py    10% policy holdout for early stopping (freq and sev)  hold3  = policy_id.hash(3) % 10
# This writes those two numbers for every policy id in the raw data to inputs/polars_policy_hash.parquet, which the R
# stages read instead of hashing. Verified on 25 Oct 2026: with these folds the Python pipeline reproduces the submitted
# N and E on every 2025 row (polars hashes are the same on Windows and Linux).
# Run (needs Python with polars==2.0.0):  python tools/make_polars_policy_hash.py <raw data dir> <out parquet>
import sys, polars as pl
assert pl.__version__ == '2.0.0', pl.__version__
raw, out = sys.argv[1], sys.argv[2]
ids = pl.concat([pl.read_parquet(f'{raw}/{f}.parquet', columns=['policy_id']).with_columns(pl.col('policy_id').cast(pl.Utf8))
                 for f in ['policies_motor', 'policies_buildings', 'policies_contents', 'test_motor', 'test_buildings',
                           'test_contents', 'claims']]).unique().sort('policy_id')
ids = ids.with_columns(fold=(pl.col('policy_id').hash(13) % 4).cast(pl.Int32), hold3=(pl.col('policy_id').hash(3) % 10).cast(pl.Int32))
ids.write_parquet(out)
print('policies', ids.height, ids.group_by('fold').len().sort('fold').to_dicts())
