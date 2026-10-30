# Kaggle notebook: both final submissions

`snorlaxcode_final_week1_week2.ipynb` is an R notebook. An `.ipynb` file can hold any language: its kernel here is R, and Kaggle
runs it as R. It takes under a minute and writes two files to `/kaggle/working/`:

| File | Model | Same as |
|---|---|---|
| `submission_week1.csv` | Week 1 final `w9_motor2_pre_m0.5` (public 0.12965, private 0.13923) | the submitted values to about 1e-14 relative (last-digit floating-point rounding, so the MD5 differs) |
| `submission_week2.csv` | Week 2 final #31 `motorlevel_l_full` (public 0.16840) | the submitted file, byte for byte (MD5 `90120c60...`) |

It uses the same arithmetic as the quick rebuilds (level B in the main README):
[replicate_final_submission.R](../week1/docs/handover_final/replicate/replicate_final_submission.R) for Week 1 and
[30_final_from_components.R](../week2/R/30_final_from_components.R) for Week 2. It starts from the saved model outputs, because
the full rebuilds take hours (Week 1 about 11, Week 2 several). Each file is checked against:
- the row count;
- no row duplicated, missing or negative;
- the competition's sample submission (row ids);
- the submitted file.

The notebook stops with an error if any check fails.

## Steps

1. **Stage the dataset** (from the repo root): `sh kaggle/make_kaggle_dataset.sh`. This writes `kaggle/dataset/` (git-ignored,
   about 115 MB): the Week 1 frozen inputs, the Week 2 components and loadings, and both submitted final files.
2. **Upload it as a private Kaggle dataset.** In Kaggle, open Datasets, then New Dataset. Upload the 10 data files (not `dataset-metadata.json`) and keep the
   dataset Private. You can also use `kaggle datasets create -p kaggle/dataset` after putting your username in `dataset-metadata.json`.
3. **Create the notebook.** On the Part 2 competition page, open Code and choose New Notebook. In the notebook, use File, then
   Import Notebook, and upload `snorlaxcode_final_week1_week2.ipynb`. Check that the language is R (Settings panel).
4. **Add inputs.** Attach the Part 2 competition data (it has both the `emerging` and the `developed` sample submissions) and the
   dataset from step 2.
5. **Run All.** You should see two lines starting with `OK`, one for each file.
6. **Save Version**, then choose Save & Run All (Commit). Both files are in the version's Output tab.
7. **Submit (optional, uses a daily slot).** Part 2 accepts only `submission_week2.csv`; pick that file in the submit dialog.
   `submission_week1.csv` belongs to the Part 1 competition.
8. **Select the final submissions.** On My Submissions, tick #31. If nothing is ticked, Kaggle picks the best public scores
   itself, and those are the set-aside probing files.
