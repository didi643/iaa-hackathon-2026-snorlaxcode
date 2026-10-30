# MOTOR 2 - per-peril frequency x severity, bodily_injury rework

**Run id** `20261023_1359` | **Quick** FALSE | **Runtime** 26 min | **Files** `motor2_only_20261023_1359.csv` (own level), `motor2_only_20261023_1359_samlevel.csv` (SAM 4 level)

Metrics: `d2` = raw Tweedie D2 (p = 1.5) vs reported cost (the local Kaggle proxy); `d2_cal` = after rescaling to the actual total (ranking only); `d2_dev` = vs IBNR-developed row cost (cost / reported share), used for level decisions because 2024 reported cost is immature. Ranking choices use calibrated D2 or Poisson / Gamma D2; level choices use developed D2. Keep rule: mean gain > 0.0005 and better in >= 2 of 3 folds (level choices: mean gain > 0.0005 and no fold worse, since only folds trained on immature years can separate them).

## Comparison (sorted by calibrated D2)

| model | d2_2022 | d2_2023 | d2_2024 | d2_cal_2022 | d2_cal_2023 | d2_cal_2024 | d2_mean | d2_cal_mean |
|---|---|---|---|---|---|---|---|---|
| MOTOR 2 (final) | 0.0626 | 0.0539 | 0.0534 | 0.0628 | 0.0539 | 0.0593 | 0.0566 | 0.0587 |
| MOTOR 1 configuration (refit here) | 0.0628 | 0.0501 | 0.0377 | 0.0630 | 0.0509 | 0.0592 | 0.0502 | 0.0577 |
| iteration-1 GLM replay | 0.0553 | 0.0555 | 0.0444 | 0.0556 | 0.0558 | 0.0498 | 0.0517 | 0.0538 |
| SAM 4 blend (reported) | 0.0596 | 0.0435 | 0.0463 | 0.0595 | 0.0438 | 0.0577 | 0.0498 | 0.0537 |
| single line-level Tweedie XGBoost | 0.0493 | 0.0425 | 0.0320 | 0.0497 | 0.0430 | 0.0542 | 0.0412 | 0.0490 |

## Stage table

`cal_<peril>` / `dev_<peril>` = mean calibrated / developed Tweedie D2 of that peril's cost.

| stage | d2_2022 | d2_2023 | d2_2024 | d2_cal_2022 | d2_cal_2023 | d2_cal_2024 | d2_mean | d2_cal_mean | d2_dev_mean | cal_own_damage | cal_third_party_prop | cal_bodily_injury | cal_theft | cal_glass_hail | dev_own_damage | dev_third_party_prop | dev_bodily_injury | dev_theft | dev_glass_hail |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S0 MOTOR 1 configuration (refit) | 0.0628 | 0.0501 | 0.0377 | 0.0630 | 0.0509 | 0.0592 | 0.0502 | 0.0577 | 0.0565 | 0.1724 | 0.0628 | 0.0638 | 0.0789 | 0.1399 | 0.1705 | 0.0622 | 0.0553 | 0.0766 | 0.1388 |
| S1 + bodily_injury frequency pooling | 0.0634 | 0.0501 | 0.0404 | 0.0635 | 0.0505 | 0.0596 | 0.0513 | 0.0579 | 0.0570 | 0.1724 | 0.0628 | 0.0652 | 0.0789 | 0.1399 | 0.1705 | 0.0622 | 0.0582 | 0.0766 | 0.1388 |
| S2 + XGBoost frequency config / weight re-chosen | 0.0631 | 0.0498 | 0.0403 | 0.0633 | 0.0501 | 0.0593 | 0.0510 | 0.0576 | 0.0568 | 0.1718 | 0.0628 | 0.0652 | 0.0771 | 0.1388 | 0.1700 | 0.0622 | 0.0582 | 0.0745 | 0.1376 |
| S3 + severity features / credibility re-chosen | 0.0631 | 0.0498 | 0.0403 | 0.0633 | 0.0501 | 0.0593 | 0.0510 | 0.0576 | 0.0568 | 0.1718 | 0.0628 | 0.0652 | 0.0771 | 0.1388 | 0.1700 | 0.0622 | 0.0582 | 0.0745 | 0.1376 |
| S4 + level choices on developed actuals | 0.0631 | 0.0513 | 0.0544 | 0.0633 | 0.0513 | 0.0601 | 0.0563 | 0.0582 | 0.0587 | 0.1718 | 0.0628 | 0.0652 | 0.0771 | 0.1388 | 0.1699 | 0.0622 | 0.0658 | 0.0745 | 0.1376 |
| S5 + blend with line Tweedie / iteration-1 GLM | 0.0626 | 0.0539 | 0.0534 | 0.0628 | 0.0539 | 0.0593 | 0.0566 | 0.0587 | 0.0592 | 0.1718 | 0.0628 | 0.0652 | 0.0771 | 0.1388 | 0.1699 | 0.0622 | 0.0658 | 0.0745 | 0.1376 |

## Decisions

| peril | decision | choice | detail |
|---|---|---|---|
| bodily_injury | frequency: own GLM / pooled with TPP / 50-50 | mix | Poisson D2 own 0.0479/0.0455/0.0421; pooled 0.0493/0.0462/0.0429; mix 0.0496/0.0466/0.0431 |
| own_damage | XGBoost frequency config x weight (total calibrated D2) | x1 0 | GLM 0.0631/0.0501/0.0592; x1 w=0.5 0.0634/0.0505/0.0594; x1 w=1.0 0.0636/0.0507/0.0596; x2 w=0.5 0.0634/0.0505/0.0594; x2 w=1.0 0.0635/0.0507/0.0595 |
| third_party_prop | XGBoost frequency config x weight (total calibrated D2) | x1 0 | GLM 0.0631/0.0501/0.0592; x1 w=0.5 0.0634/0.0495/0.0594; x1 w=1.0 0.0633/0.0484/0.0594; x2 w=0.5 0.0635/0.0494/0.0594; x2 w=1.0 0.0635/0.0483/0.0594 |
| bodily_injury | XGBoost frequency config x weight (total calibrated D2) | x1 0 | GLM 0.0631/0.0501/0.0592; x1 w=0.5 0.0634/0.0452/0.0597; x1 w=1.0 0.0609/0.0379/0.0589; x2 w=0.5 0.0634/0.0460/0.0597; x2 w=1.0 0.0613/0.0399/0.0590 |
| theft | XGBoost frequency config x weight (total calibrated D2) | x1 0 | GLM 0.0631/0.0500/0.0590; x1 w=0.5 0.0631/0.0501/0.0592; x1 w=1.0 0.0629/0.0502/0.0592; x2 w=0.5 0.0631/0.0502/0.0592; x2 w=1.0 0.0628/0.0502/0.0593 |
| glass_hail | XGBoost frequency config x weight (total calibrated D2) | x1 0 | GLM 0.0631/0.0500/0.0590; x1 w=0.5 0.0631/0.0500/0.0590; x1 w=1.0 0.0632/0.0500/0.0590; x2 w=0.5 0.0632/0.0500/0.0590; x2 w=1.0 0.0632/0.0500/0.0590 |
| own_damage | severity features / Z | base 1 | Gamma D2 base 0.0372/0.0457/0.0488, extended 0.0365/0.0438/0.0486; Z grid 0.00:0.0000 0.25:0.0189 0.50:0.0326 0.75:0.0410 1.00:0.0439 |
| third_party_prop | severity features / Z | base 0.5 | Gamma D2 base -0.0017/0.0033/-0.0006, extended -0.0030/0.0019/-0.0016; Z grid 0.00:0.0000 0.25:0.0007 0.50:0.0011 0.75:0.0009 1.00:0.0003 |
| bodily_injury | severity features / Z | base 0 | Gamma D2 base -0.0069/-0.0086/-0.0068, extended -0.0069/-0.0148/-0.0130; Z grid 0.00:0.0000 0.25:-0.0009 0.50:-0.0025 0.75:-0.0047 1.00:-0.0075 |
| theft | severity features / Z | base 1 | Gamma D2 base 0.0258/0.0328/0.0401, extended 0.0258/0.0327/0.0349; Z grid 0.00:0.0000 0.25:0.0147 0.50:0.0251 0.75:0.0312 1.00:0.0329 |
| glass_hail | severity features / Z | base 0.75 | Gamma D2 base 0.0085/0.0098/0.0064, extended -0.0009/0.0090/0.0044; Z grid 0.00:0.0000 0.25:0.0042 0.50:0.0070 0.75:0.0084 1.00:0.0082 |
| own_damage | level: freq trend / sev trend / loading / sev years (total developed D2) | 0 0 raw base | total developed D2 current 0.0628/0.0500/0.0569 -> best 0.0628/0.0514/0.0573 |
| third_party_prop | level: freq trend / sev trend / loading / sev years (total developed D2) | 1 1 raw base | total developed D2 current 0.0628/0.0514/0.0573 -> best 0.0628/0.0508/0.0589 |
| bodily_injury | level: freq trend / sev trend / loading / sev years (total developed D2) | 1 1 raw all | total developed D2 current 0.0628/0.0514/0.0573 -> best 0.0628/0.0514/0.0614 |
| theft | level: freq trend / sev trend / loading / sev years (total developed D2) | 1 1 raw base | total developed D2 current 0.0628/0.0514/0.0614 -> best 0.0628/0.0514/0.0614 |
| glass_hail | level: freq trend / sev trend / loading / sev years (total developed D2) | 1 1 raw base | total developed D2 current 0.0628/0.0514/0.0614 -> best 0.0628/0.0514/0.0614 |
| all | blend weights (line Tweedie, iteration-1 GLM) | 0.1 0.2 | tw=0.0 leg=0.0: 0.0581; tw=0.0 leg=0.1: 0.0584; tw=0.0 leg=0.2: 0.0586; tw=0.0 leg=0.3: 0.0586; tw=0.1 leg=0.0: 0.0582; tw=0.1 leg=0.1: 0.0585; tw=0.1 leg=0.2: 0.0587; tw=0.1 leg=0.3: 0.0586; tw=0.2 leg=0.0: 0.0581; tw=0.2 leg=0.1: 0.0584; tw=0.2 leg=0.2: 0.0585; tw=0.2 leg=0.3: 0.0584 |

## Level grid (developed D2 per option)

| peril | ftrend | strend | load | sev | total_dev_d2_mean | peril_dev_d2_mean | total_dev_d2 | chosen |
|---|---|---|---|---|---|---|---|---|
| own_damage | 0 | 0 | raw | base | 0.0572 | 0.1699 | 0.0628/0.0514/0.0573 | TRUE |
| own_damage | 0 | 0 | rob | base | 0.0572 | 0.1699 | 0.0628/0.0514/0.0573 | FALSE |
| own_damage | 0 | 0.5000 | raw | base | 0.0570 | 0.1710 | 0.0628/0.0512/0.0569 | FALSE |
| own_damage | 0 | 0.5000 | rob | base | 0.0570 | 0.1710 | 0.0628/0.0512/0.0569 | FALSE |
| own_damage | 0 | 1 | raw | base | 0.0567 | 0.1714 | 0.0628/0.0509/0.0564 | FALSE |
| own_damage | 0 | 1 | rob | base | 0.0567 | 0.1714 | 0.0628/0.0509/0.0564 | FALSE |
| own_damage | 1 | 0 | raw | base | 0.0571 | 0.1690 | 0.0628/0.0508/0.0577 | FALSE |
| own_damage | 1 | 0 | rob | base | 0.0571 | 0.1690 | 0.0628/0.0508/0.0577 | FALSE |
| own_damage | 1 | 0.5000 | raw | base | 0.0569 | 0.1698 | 0.0628/0.0504/0.0573 | FALSE |
| own_damage | 1 | 0.5000 | rob | base | 0.0569 | 0.1698 | 0.0628/0.0504/0.0573 | FALSE |
| own_damage | 1 | 1 | raw | base | 0.0566 | 0.1700 | 0.0628/0.0500/0.0569 | FALSE |
| own_damage | 1 | 1 | rob | base | 0.0566 | 0.1700 | 0.0628/0.0500/0.0569 | FALSE |
| third_party_prop | 0 | 0 | raw | base | 0.0573 | 0.0615 | 0.0628/0.0505/0.0585 | FALSE |
| third_party_prop | 0 | 0 | rob | base | 0.0573 | 0.0615 | 0.0628/0.0505/0.0585 | FALSE |
| third_party_prop | 0 | 0.5000 | raw | base | 0.0571 | 0.0624 | 0.0628/0.0509/0.0576 | FALSE |
| third_party_prop | 0 | 0.5000 | rob | base | 0.0571 | 0.0624 | 0.0628/0.0509/0.0576 | FALSE |
| third_party_prop | 0 | 1 | raw | base | 0.0569 | 0.0625 | 0.0628/0.0512/0.0566 | FALSE |
| third_party_prop | 0 | 1 | rob | base | 0.0569 | 0.0625 | 0.0628/0.0512/0.0566 | FALSE |
| third_party_prop | 1 | 0 | raw | base | 0.0575 | 0.0611 | 0.0628/0.0508/0.0589 | FALSE |
| third_party_prop | 1 | 0 | rob | base | 0.0575 | 0.0611 | 0.0628/0.0508/0.0589 | FALSE |
| third_party_prop | 1 | 0.5000 | raw | base | 0.0574 | 0.0621 | 0.0628/0.0511/0.0582 | FALSE |
| third_party_prop | 1 | 0.5000 | rob | base | 0.0574 | 0.0621 | 0.0628/0.0511/0.0582 | FALSE |
| third_party_prop | 1 | 1 | raw | base | 0.0572 | 0.0622 | 0.0628/0.0514/0.0573 | FALSE |
| third_party_prop | 1 | 1 | rob | base | 0.0572 | 0.0622 | 0.0628/0.0514/0.0573 | FALSE |
| bodily_injury | 0 | 0 | raw | base | 0.0577 | 0.0626 | 0.0628/0.0505/0.0599 | FALSE |
| bodily_injury | 0 | 0 | rob | base | 0.0580 | 0.0642 | 0.0628/0.0505/0.0607 | FALSE |
| bodily_injury | 0 | 0.5000 | raw | base | 0.0576 | 0.0609 | 0.0628/0.0509/0.0589 | FALSE |
| bodily_injury | 0 | 0.5000 | rob | base | 0.0579 | 0.0630 | 0.0628/0.0509/0.0601 | FALSE |
| bodily_injury | 0 | 1 | raw | base | 0.0573 | 0.0588 | 0.0628/0.0513/0.0577 | FALSE |
| bodily_injury | 0 | 1 | rob | base | 0.0578 | 0.0614 | 0.0628/0.0513/0.0592 | FALSE |
| bodily_injury | 1 | 0 | raw | base | 0.0577 | 0.0622 | 0.0628/0.0506/0.0597 | FALSE |
| bodily_injury | 1 | 0 | rob | base | 0.0580 | 0.0639 | 0.0628/0.0506/0.0606 | FALSE |
| bodily_injury | 1 | 0.5000 | raw | base | 0.0575 | 0.0604 | 0.0628/0.0510/0.0586 | FALSE |
| bodily_injury | 1 | 0.5000 | rob | base | 0.0579 | 0.0626 | 0.0628/0.0510/0.0599 | FALSE |
| bodily_injury | 1 | 1 | raw | base | 0.0572 | 0.0582 | 0.0628/0.0514/0.0573 | FALSE |
| bodily_injury | 1 | 1 | rob | base | 0.0577 | 0.0609 | 0.0628/0.0514/0.0589 | FALSE |
| bodily_injury | 0 | 0 | raw | all | 0.0580 | 0.0639 | 0.0628/0.0505/0.0606 | FALSE |
| bodily_injury | 0 | 0 | rob | all | 0.0581 | 0.0651 | 0.0628/0.0505/0.0611 | FALSE |
| bodily_injury | 0 | 0.5000 | raw | all | 0.0583 | 0.0652 | 0.0628/0.0509/0.0612 | FALSE |
| bodily_injury | 0 | 0.5000 | rob | all | 0.0584 | 0.0659 | 0.0628/0.0509/0.0614 | FALSE |
| bodily_injury | 0 | 1 | raw | all | 0.0585 | 0.0659 | 0.0628/0.0513/0.0614 | FALSE |
| bodily_injury | 0 | 1 | rob | all | 0.0585 | 0.0659 | 0.0628/0.0513/0.0613 | FALSE |
| bodily_injury | 1 | 0 | raw | all | 0.0580 | 0.0636 | 0.0628/0.0506/0.0604 | FALSE |
| bodily_injury | 1 | 0 | rob | all | 0.0582 | 0.0649 | 0.0628/0.0506/0.0611 | FALSE |
| bodily_injury | 1 | 0.5000 | raw | all | 0.0583 | 0.0650 | 0.0628/0.0510/0.0611 | FALSE |
| bodily_injury | 1 | 0.5000 | rob | all | 0.0584 | 0.0658 | 0.0628/0.0510/0.0614 | FALSE |
| bodily_injury | 1 | 1 | raw | all | 0.0585 | 0.0658 | 0.0628/0.0514/0.0614 | TRUE |
| bodily_injury | 1 | 1 | rob | all | 0.0585 | 0.0659 | 0.0628/0.0514/0.0614 | FALSE |
| theft | 0 | 0 | raw | base | 0.0585 | 0.0753 | 0.0628/0.0513/0.0613 | FALSE |
| theft | 0 | 0 | rob | base | 0.0585 | 0.0753 | 0.0628/0.0513/0.0613 | FALSE |
| theft | 0 | 0.5000 | raw | base | 0.0585 | 0.0757 | 0.0628/0.0513/0.0614 | FALSE |
| theft | 0 | 0.5000 | rob | base | 0.0585 | 0.0757 | 0.0628/0.0513/0.0614 | FALSE |
| theft | 0 | 1 | raw | base | 0.0585 | 0.0756 | 0.0628/0.0513/0.0614 | FALSE |
| theft | 0 | 1 | rob | base | 0.0585 | 0.0756 | 0.0628/0.0513/0.0614 | FALSE |
| theft | 1 | 0 | raw | base | 0.0585 | 0.0743 | 0.0628/0.0514/0.0613 | FALSE |
| theft | 1 | 0 | rob | base | 0.0585 | 0.0743 | 0.0628/0.0514/0.0613 | FALSE |
| theft | 1 | 0.5000 | raw | base | 0.0585 | 0.0746 | 0.0628/0.0514/0.0614 | FALSE |
| theft | 1 | 0.5000 | rob | base | 0.0585 | 0.0746 | 0.0628/0.0514/0.0614 | FALSE |
| theft | 1 | 1 | raw | base | 0.0585 | 0.0745 | 0.0628/0.0514/0.0614 | FALSE |
| theft | 1 | 1 | rob | base | 0.0585 | 0.0745 | 0.0628/0.0514/0.0614 | FALSE |
| glass_hail | 0 | 0 | raw | base | 0.0585 | 0.1369 | 0.0628/0.0514/0.0613 | FALSE |
| glass_hail | 0 | 0 | rob | base | 0.0585 | 0.1369 | 0.0628/0.0514/0.0613 | FALSE |
| glass_hail | 0 | 0.5000 | raw | base | 0.0585 | 0.1382 | 0.0628/0.0514/0.0614 | FALSE |
| glass_hail | 0 | 0.5000 | rob | base | 0.0585 | 0.1382 | 0.0628/0.0514/0.0614 | FALSE |
| glass_hail | 0 | 1 | raw | base | 0.0585 | 0.1386 | 0.0628/0.0513/0.0614 | FALSE |
| glass_hail | 0 | 1 | rob | base | 0.0585 | 0.1386 | 0.0628/0.0513/0.0614 | FALSE |
| glass_hail | 1 | 0 | raw | base | 0.0585 | 0.1358 | 0.0628/0.0514/0.0614 | FALSE |
| glass_hail | 1 | 0 | rob | base | 0.0585 | 0.1358 | 0.0628/0.0514/0.0614 | FALSE |
| glass_hail | 1 | 0.5000 | raw | base | 0.0585 | 0.1373 | 0.0628/0.0514/0.0614 | FALSE |
| glass_hail | 1 | 0.5000 | rob | base | 0.0585 | 0.1373 | 0.0628/0.0514/0.0614 | FALSE |
| glass_hail | 1 | 1 | raw | base | 0.0585 | 0.1376 | 0.0628/0.0514/0.0614 | FALSE |
| glass_hail | 1 | 1 | rob | base | 0.0585 | 0.1376 | 0.0628/0.0514/0.0614 | FALSE |

## Peril metrics (final configuration)

| peril | valid_year | raw_d2 | cal_d2 | dev_d2 | poisson_d2 | gamma_d2 | ae_developed |
|---|---|---|---|---|---|---|---|
| own_damage | 2022 | 0.1654 | 0.1673 | 0.1654 | 0.1405 | 0.0372 | 0.8865 |
| own_damage | 2023 | 0.1698 | 0.1709 | 0.1698 | 0.1330 | 0.0457 | 0.9199 |
| own_damage | 2024 | 0.1751 | 0.1771 | 0.1746 | 0.1391 | 0.0488 | 0.8631 |
| third_party_prop | 2022 | 0.0672 | 0.0689 | 0.0672 | 0.0729 | 0.0004 | 0.9028 |
| third_party_prop | 2023 | 0.0621 | 0.0628 | 0.0621 | 0.0686 | 0.0023 | 1.0974 |
| third_party_prop | 2024 | 0.0564 | 0.0566 | 0.0574 | 0.0638 | 0.0005 | 1.0032 |
| bodily_injury | 2022 | 0.0652 | 0.0652 | 0.0652 | 0.0496 | 0 | 1.0000 |
| bodily_injury | 2023 | 0.0690 | 0.0701 | 0.0703 | 0.0466 | 0 | 1.0138 |
| bodily_injury | 2024 | 0.0188 | 0.0603 | 0.0617 | 0.0431 | 0 | 1.1161 |
| theft | 2022 | 0.0720 | 0.0720 | 0.0720 | 0.0376 | 0.0258 | 1.0443 |
| theft | 2023 | 0.0661 | 0.0733 | 0.0660 | 0.0338 | 0.0328 | 0.8105 |
| theft | 2024 | 0.0848 | 0.0860 | 0.0855 | 0.0427 | 0.0401 | 1.0739 |
| glass_hail | 2022 | 0.1301 | 0.1309 | 0.1301 | 0.0728 | 0.0084 | 0.9346 |
| glass_hail | 2023 | 0.1433 | 0.1448 | 0.1432 | 0.0839 | 0.0097 | 0.8790 |
| glass_hail | 2024 | 0.1383 | 0.1407 | 0.1395 | 0.0816 | 0.0071 | 1.1351 |

## bodily_injury history

Developed = reported / reported share (3b pattern; SAM 3 ECDF for BI). Case estimates are taken as adequate, so 2023-24 severities may still develop (IBNER); the level choice on developed actuals inherits that assumption.

| policy_year | exposure | reported_claims | developed_claims | open_share | mean_net | median_net | mean_net_capped_200k | max_net | developed_cost_per_exposure | developed_frequency |
|---|---|---|---|---|---|---|---|---|---|---|
| 2021 | 187,991.540 | 2,144 | 2,144.802 | 0.150 | 21,450.796 | 13,409.540 | 20,684.341 | 1,118,867.580 | 244.733 | 0.011 |
| 2022 | 199,698.501 | 2,141 | 2,151.119 | 0.278 | 22,163.495 | 13,178.370 | 21,524.532 | 524,358.770 | 238.742 | 0.011 |
| 2023 | 199,681.852 | 2,049 | 2,167.034 | 0.493 | 23,307.852 | 9,811.820 | 17,211.064 | 11,894,276.930 | 253.014 | 0.011 |
| 2024 | 199,785.630 | 1,178 | 2,078.893 | 0.798 | 17,829.043 | 9,880.845 | 17,205.844 | 602,049.580 | 181.544 | 0.010 |

## Fitted trends and loadings by fold

| valid_year | peril | part | trend_fitted | claims | loading_raw | loading_rob |
|---|---|---|---|---|---|---|
| 2022 | own_damage | freq_glm | 0 |  | 1.007 | 1.007 |
| 2022 | own_damage | sev_base | 0 | 11,980 |  |  |
| 2022 | own_damage | sev_ext | 0 | 11,980 |  |  |
| 2022 | third_party_prop | freq_glm | 0 |  | 1.005 | 1.005 |
| 2022 | third_party_prop | sev_base | 0 | 8,179 |  |  |
| 2022 | third_party_prop | sev_ext | 0 | 8,179 |  |  |
| 2022 | bodily_injury | freq_glm | 0 |  | 1.043 | 1.037 |
| 2022 | bodily_injury | freq_pool (BI rel. trend) | 0 |  |  |  |
| 2022 | bodily_injury | sev_base | 0 | 2,144 |  |  |
| 2022 | bodily_injury | sev_ext | 0 | 2,144 |  |  |
| 2022 | bodily_injury | sev_all | 0 | 2,144 |  |  |
| 2022 | theft | freq_glm | 0 |  | 1.009 | 1.009 |
| 2022 | theft | sev_base | 0 | 1,479 |  |  |
| 2022 | theft | sev_ext | 0 | 1,479 |  |  |
| 2022 | glass_hail | freq_glm | 0 |  | 1.008 | 1.008 |
| 2022 | glass_hail | sev_base | 0 | 3,572 |  |  |
| 2022 | glass_hail | sev_ext | 0 | 3,572 |  |  |
| 2023 | own_damage | freq_glm | 0.108 |  | 1.008 | 1.008 |
| 2023 | own_damage | sev_base | 0.077 | 24,851 |  |  |
| 2023 | own_damage | sev_ext | 0.082 | 24,851 |  |  |
| 2023 | third_party_prop | freq_glm | 0.033 |  | 1.005 | 1.005 |
| 2023 | third_party_prop | sev_base | 0.078 | 16,980 |  |  |
| 2023 | third_party_prop | sev_ext | 0.079 | 16,980 |  |  |
| 2023 | bodily_injury | freq_glm | 0.050 |  | 1.037 | 1.035 |
| 2023 | bodily_injury | freq_pool (BI rel. trend) | -0.069 |  |  |  |
| 2023 | bodily_injury | sev_base | 0.052 | 4,285 |  |  |
| 2023 | bodily_injury | sev_ext | 0.055 | 4,285 |  |  |
| 2023 | bodily_injury | sev_all | 0.052 | 4,285 |  |  |
| 2023 | theft | freq_glm | -0.039 |  | 1.008 | 1.008 |
| 2023 | theft | sev_base | 0.010 | 3,015 |  |  |
| 2023 | theft | sev_ext | 0.011 | 3,015 |  |  |
| 2023 | glass_hail | freq_glm | -0.057 |  | 1.005 | 1.005 |
| 2023 | glass_hail | sev_base | 0.112 | 7,511 |  |  |
| 2023 | glass_hail | sev_ext | 0.117 | 7,511 |  |  |
| 2024 | own_damage | freq_glm | -0.036 |  | 1.009 | 1.009 |
| 2024 | own_damage | sev_base | 0.068 | 36,721 |  |  |
| 2024 | own_damage | sev_ext | 0.073 | 36,721 |  |  |
| 2024 | third_party_prop | freq_glm | -0.024 |  | 1.005 | 1.005 |
| 2024 | third_party_prop | sev_base | 0.077 | 25,337 |  |  |
| 2024 | third_party_prop | sev_ext | 0.077 | 25,337 |  |  |
| 2024 | bodily_injury | freq_glm | 0.049 |  | 1.127 | 1.038 |
| 2024 | bodily_injury | freq_pool (BI rel. trend) | -0.006 |  |  |  |
| 2024 | bodily_injury | sev_base | 0.053 | 4,285 |  |  |
| 2024 | bodily_injury | sev_ext | 0.056 | 4,285 |  |  |
| 2024 | bodily_injury | sev_all | -0.083 | 6,334 |  |  |
| 2024 | theft | freq_glm | 0.008 |  | 1.007 | 1.007 |
| 2024 | theft | sev_base | 0.077 | 4,616 |  |  |
| 2024 | theft | sev_ext | 0.075 | 4,616 |  |  |
| 2024 | glass_hail | freq_glm | 0.031 |  | 1.006 | 1.006 |
| 2024 | glass_hail | sev_base | 0.095 | 11,623 |  |  |
| 2024 | glass_hail | sev_ext | 0.096 | 11,623 |  |  |

## Final configuration (fit on 2021-24)

| peril | freq | freq_trend_fitted | freq_trend_on | xgb | xgb_w | sev | Z | sev_trend_fitted | sev_trend_share | loading | loading_value | loading_raw | cap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| own_damage | glm | -0.014 | 0 | - | 0 | base | 1 | 0.084 | 0 | raw | 1.010 | 1.010 | 13,005.319 |
| third_party_prop | glm | -0.037 | 1 | - | 0 | base | 0.500 | 0.077 | 1 | raw | 1.006 | 1.006 | 19,749.538 |
| bodily_injury | mix | 0.049 | 1 | - | 0 | all | 0 | -0.077 | 1 | raw | 1.115 | 1.115 | 187,516.024 |
| theft | glm | -0.001 | 1 | - | 0 | base | 1 | 0.062 | 1 | raw | 1.007 | 1.007 | 38,459.515 |
| glass_hail | glm | -0.008 | 1 | - | 0 | base | 0.750 | 0.080 | 1 | raw | 1.006 | 1.006 | 5,873.072 |

## 2025 predictions

| peril | predicted_total | cost_per_exposure_year |
|---|---|---|
| own_damage | 20,906,111.62 | 104.539140314615 |
| third_party_prop | 34,731,722.18 | 173.672868706499 |
| bodily_injury | 37,576,649.66 | 187.898673999196 |
| theft | 10,539,714.48 | 52.7028991144998 |
| glass_hail | 5,076,242.62 | 25.383296969529 |
| total | 108,830,440.56 | 544.19687910434 |

Own level 544.20 vs SAM 4 607.41 per exposure-year (scale 1.1162). Replication max abs diff 0.

## Flags

- Level options are chosen on three folds whose 2024 developed actuals rest on a 1.74 BI report-lag factor and unaudited case reserves; a lower BI level that wins locally may still be too low for 2025 ultimate (the public test #10 favoured the higher SAM level). Use the SAM-level file unless the public score says otherwise.
- All choices are made and reported on the same folds, so gains below about 0.001 are within noise.
- The iteration-1 GLM replay in the blend has no trend and no claim history; it is rescaled to the per-peril total, so it only contributes ranking.
