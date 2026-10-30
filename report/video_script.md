# Video script v4 (draft): "How we actually built it"

Team SnorlaxCode: Samuel Lim, Wendy Low, Benedict Tan.

**Status: draft for review. Nothing has been rendered yet.**
- Adjustments 1–4 (scenes 1, 2 and 4) are included below, marked **[NEW]** or **[CHANGED]**.
- **[CHANGED] 30 Oct 2026:** scenes 7 and 7b rewritten for the final submission (#31 `motorlevel_l_full`, public 0.16840): we tried probing → decided it is cheating, not real-world → did not use it although it scored higher → went back to the pre-probing model → actuarial motor check. Scene 6's 0.172 line moved into scene 7, because it was a probing result.
- Lines marked ~~struck through~~ were cut in v3 and stay cut.
- Animation notes describe what's on screen *while each line is spoken*.

**Style:** 1950s UPA modernist cartoon (broken ink lines, offset flat colour, cream paper, mustard / teal / orange-red accents, crayon grain). Hard cuts every 1–2 s. Subtitles are burned in with a speaker tag, and there's a soft generated music bed that dips under the voices.

**Target length:** ≤ 5:00. v3 runs 4:58.5. The new scene 4 lines add about 4 s, and the new scenes 6–7b about 13 s more (234 spoken words vs about 201 before, at about 150 words a minute), so about 17 s must be trimmed elsewhere. Suggested cuts: shorter pauses between scenes, the scene 5 line "Part of the reason was that the two markets don't have the same columns." (about 4 s), and in scene 7b "Lower than probing, but" (about 2 s).

---

## Scene 1. Opening (Wendy)

**Animation**
- Title card: *HOW WE ACTUALLY BUILT IT · TEAM SNORLAXCODE*.
- Night room, with the three of you at one desk, laptop open, coffee mugs.
- **[CHANGED]** No downloading screen here any more (it moved to scene 2).
  - On "Samuel / Benedict / Wendy", each name tag pops up above that person as it's said, and each waves.
  - On "In the next five minutes…", a **roadmap poster** unrolls behind the desk: **WEEK 1 → WEEK 2 → WHAT WE LEARNED**.
  - On "…including the parts that went wrong", a small red **"oops"** stamp lands on the road and Benedict stretches.

**Wendy:**
Hi, we're Samuel, Benedict and Wendy.
In the next five minutes we'll walk you through how we built our pricing model with AI, including the parts that went wrong.

---

## Scene 2. Setting up (Benedict)

**Animation**
- **[NEW] Downloading data.** On "We downloaded the data", a laptop screen shows a progress bar, *Downloading data…*, with *motor · buildings · contents · 2021–2024* underneath. It fills to 100% and reads *Data ready.*
- **[NEW] Creating the Claude project.** On "…and set up a project in Claude":
  - A cursor clicks **+ New project**.
  - A project window opens, titled **Project: Hackathon**, with a simple chat-bubble assistant icon in the video's style.
  - *Not the real Claude logo: I can't reproduce real logos or app icons. The voice-over and subtitles name Claude.*
- **[NEW] Writing the instructions and context.** On "Before any modelling, we gave it house rules…", the cursor clicks **Instructions** in the project's side panel, and the text types in as Benedict speaks:
  > **Competition:** predict the expected ultimate claim cost for every row, net of excess and recoveries, excluding declined claims. One CSV: `row_id, prediction`, all ≥ 0.
  > **House rules:** 1. Use R. 2. Test everything on our own data first. 3. Never send anything to Kaggle without asking us.

  The cursor clicks **Save**, and a **"Context added ✓"** tick appears.
- On "Then we told it the goal. We want to win.", the chat box types **Goal: we want to win.**
- On "It took that very seriously.", the reply *"Understood. Mission: WIN."* appears, the screen floods mustard, a trophy rises with light wedges, and Benedict looks surprised.

**Benedict:**
We downloaded the data and set up a project in Claude.
Before any modelling, we gave it house rules: use R, test everything on our own data first, and never send anything to Kaggle without asking us.
Then we told it the goal.
We want to win.
It took that very seriously.

---

## Scene 3. Week 1: the first tries (Samuel)

**Animation** (unchanged from v3)
- Title card: *WEEK 1 · THE DEVELOPED MARKET*.
- Car, house and sofa appear as each line of business is said, with 2021–2024 tiles.
- A wall of small frequency and severity charts fills up. Label: *frequency + severity, every column*.
- House-value chart with a ×1000 spike. The spike is fixed on "thousand", then a duplicate claim is crossed out.
- Whiteboard: a GLM line is drawn, with a "not asked!" note. Then **GBM, one per peril**, with trees appearing one by one, and a *not good enough* gauge.
- AutoML screen, *still running*, while the sky goes from day to dusk to night and the mugs pile up.

**Samuel:**
Week one was the developed market: four years of data for car, house and contents insurance.
Our first instinct was to ask the AI for some quick data exploration.
It gave us a frequency and a severity plot for almost every column.
We read through them all, and that is where we spotted the data problems.
Claude then cleaned the data, fixing house values that were a thousand times too big and removing duplicate claims.
Without being asked, it then fitted a simple GLM.
We asked for gradient boosting instead, with a separate model for each type of claim, or peril, within each line.
It was not good enough.
Next we tried AutoML on every peril.
That didn't do much better, and it took a very long time to run.

---

## Scene 4. Week 1: the breakthrough (Samuel)

**Animation**
- **[CHANGED] Three-way split.**
  - On "So we split the work three ways", three desks appear side by side and nameplates drop in: **SAMUEL · WENDY · BENEDICT**.
  - **Samuel's line:** close-up of Samuel. The IBNR triangle fills in, labelled *late-reported claims*.
  - **Wendy's line:** close-up of Wendy. Her screen has a tab for each peril, and each tab shows two charts side by side, **Frequency** and **Severity**.
  - **Benedict's line:** close-up of Benedict. His two charts slide together and merge into one **Claim cost** chart, labelled *frequency × severity, one model*.
- On "The breakthrough…", a light bulb lights up.
- The Excel sheet **features_by_peril.xlsx** fills in row by row (Peril · Feature · Frequency? · Severity? · Why in real life), then a **THINK LIKE AN ACTUARY** stamp lands.
- Scoreboard flips from **0.122 to 0.127** on the number, then a *biggest step of week 1* banner.
- IBNR triangle completes, with a **chain-ladder: simple · good enough** label.
- Main model and motor model blocks merge, with a car.
- Final boards: **0.12965 FINAL PUBLIC** and **1st PRIVATE BOARD**, then the trophy and all three cheering.

**Samuel:**
**[NEW]** So we split the work three ways.
**[NEW]** I looked at late-reported claims, the IBNR.
**[NEW]** Wendy tested separate frequency and severity models for each peril.
**[NEW]** And Benedict tested a simpler model that handles frequency and severity together.
~~So we split the work. One of us looked at late-reported claims, the IBNR. The other looked at features for each peril.~~ *(replaced by the four lines above)*
The breakthrough came from one prompt.
Instead of "build a better model", we asked the AI to make an Excel sheet.
For every peril, it had to go through every column and write down whether it really drives how often people claim, and separately how much the claims cost, and why.
That made it think like an actuary.
Our score jumped from 0.122 to 0.127, the biggest step of week one.
~~After that came hyperparameter tuning.~~
For IBNR, we tested a few methods and found that plain chain-ladder, the simplest one, worked well enough.
On the last day, we focused on car insurance, our biggest line, and blended in a separate motor model.
We finished week one at 0.12965 on the public board, and first on the private board.

> **To confirm:** Are the four new lines accurate, especially Benedict's model? And should Samuel voice all four, or should Wendy and Benedict each voice their own line?

---

## Scene 5. Week 2: confident, then not (Wendy)

**Animation** (unchanged from v3)
- Title card: *WEEK 2 · A NEW, EMERGING MARKET*.
- Map: a plane flies from the developed city to the emerging city, and Wendy carries a *WEEK 1 MODEL* suitcase.
- *YEAR 1 / YEAR 2* data cards, then rows of new customers with **NEW** tags.
- Three jars, *week 1 model + new market data → credibility mix*, pouring together on "credibility".
- Scoreboard **0.1486**, labelled *FIRST TRY, WEEK 2*, with a *not great* note and Wendy raising an eyebrow.
- Developed vs new-market column lists, with the gaps greyed out.
- Price tags for *the same car repair*: **DEVELOPED 100** vs **EMERGING, about half**, with a banner *car claims 51%–65% · all claims 35%–87%*. Wendy holds a magnifying glass.
- **[NEW]** A second pair of price tags for *the same burst pipe at home*: **DEVELOPED 100** vs **EMERGING, about two-thirds (68)**, with a note *buildings escape of water · 268 new-market claims*.

**Wendy:**
In week two, the insurer moved into a new, emerging market.
We only had two years of data, and most of the 2025 customers were brand new.
We thought, we already have a good model, so it should work here too.
We asked the AI to run the week one model on the developed data and use credibility to mix it with the new market's own experience.
The result was not great: 0.1486.
Part of the reason was that the two markets don't have the same columns.
The bigger surprise was severity.
A claim in the new market costs much less.
Car claims cost about half as much.
It was the same for houses. A burst pipe in a house costs about two-thirds of what it does in the developed market.
So we started studying that.

---

## Scene 6. Week 2: rebuilding it (Wendy)

**Animation** (unchanged from v3)
- Laptop column list with **gender** highlighted as *new market only* and a *used where it is allowed* badge.
- Retune list: the columns the new market doesn't have get struck through.
- **CREDIBILITY** dial turning, with *method 1/2/3* each ticked *tested*.
- Scoreboard **0.156 → 0.166** on the number, with a *biggest step of week 2* banner and Wendy cheering.
- ~~Price-level bars per line adjust, then the board reads **0.172**.~~ **[CHANGED]** moved to scene 7 (it was a probing result).

**Wendy:**
We asked the AI to use gender, which only exists in the new market's data, and where it is allowed.
We also had it retune the week one model using only the columns the new market has.
Then we tried different credibility methods and factors, and tested each one.
Gender and those settings took us from 0.156 to 0.166, our biggest week two jump.
~~Setting the price level of each line got us to about 0.172.~~ *(moved to scene 7: the 0.172 came from probing)*

---

## Scene 7. Week 2: probing, and why we dropped it (Wendy) [CHANGED]

**Animation**
- Wendy shines a flashlight on the foggy **PUBLIC BOARD**.
- Price sliders for motor, buildings and contents move one at a time; the score gauge climbs **0.172 → 0.17445**.
- On "But could a real insurer do this?", the screen freezes. A thought bubble over Wendy: a **2025 calendar** with the claims hidden behind a curtain, and a crystal ball with a red cross.
- On "So we decided it was cheating", a big red **NOT REAL-WORLD · SET ASIDE** stamp lands on the **0.17445** card, and the card slides into a drawer labelled *tried, recorded, not used*.

**Wendy:**
We still had time, so we tried probing the public board.
We nudged the price of each line and peril, and read the right level off the score.
It worked: 0.17445.
But could a real insurer do this? No. Nobody sees next year's claims before setting a price.
So we decided it was cheating, and we didn't use it, even though it scored higher.

---

## Scene 7b. Back to the model, the actuarial way (Wendy) [CHANGED]

**Animation**
- A rewind arrow. Wendy turns to the **PRE-PROBING MODEL** card, **0.16690**.
- A car rolls onto a workbench. Wendy, in a green eyeshade, works down a clipboard **MOTOR CHECK** while each line is spoken:
  - *Risk spread* ✓ *fine as it is*;
  - *Injury claim inflation*: **0% → +4.5% a year**, with an up arrow;
  - *Late-reported injury claims*: a slow envelope arrives and is bigger than the others;
  - *Large claims*: a heavy weight labelled *developed market* is added to the scale;
  - *New customers 77%*: a crowd of **NEW** tags, with a *full new-customer load* sticker.
- The motor price bar rises, labelled **+9.4%**. The house and sofa bars don't move.
- Final board: **FINAL PUBLIC 0.16840**, with the drawer card *0.17445, probed, not used* beside it, and a banner *from our data, not the leaderboard*.

**Wendy:**
So we went back to the model from before probing, at 0.16690, and reviewed car insurance, our biggest line, like a pricing actuary would.
We had assumed no inflation on injury claims, but our own data showed about four and a half percent a year.
Injury claims reported late are bigger, and a young book hasn't seen its large claims yet.
And three quarters of 2025 customers are new, so they got the full new-customer loading.
That raised the car price by about nine percent, and gave our final public score: 0.16840.
Lower than probing, but every number came from our own data, not the leaderboard.

---

## Scene 8. Guardrails and what we learned (Benedict)

**Animation** (unchanged from v3)
- Benedict hands a folder to Samuel.
- Whiteboard checklist ticks: **Local test first · Run log · Fingerprint (MD5)**.
- Samuel stamps the folder **HUMAN CHECKED**, then the **WEEK 1** and **WEEK 2** folders are both stamped **CHECKED**.
- Dusk desk with all three: the cards *AI will happily do the work.* and *Keep guiding it. Keep checking it.*

**Benedict:**
Throughout, we never took the AI's word for it.
Every idea was scored on our own past data first.
Every run was written down.
Every final file has a fingerprint, so anyone can rebuild it exactly.
And one of us checked every file before it went to Kaggle, in both weeks.
~~What we still don't know is how much of the probing gain will hold on the private data.~~
If there's one thing we learned, it's this: AI will happily do the work, but you have to keep guiding it, and keep checking it.

---

## Ending. Thank you

**Animation** (unchanged from v3)
- The same dusk desk: all three stand up from their chairs, bow, then smile and wave.
- **THANK YOU FOR LISTENING** card. **TEAM SNORLAXCODE** is written on the desk front, with *Samuel Lim · Wendy Low · Benedict Tan* underneath.

**All three together:**
Thank you for watching!

> The spoken line says "watching" while the card says "listening". Keep both as they are, or make them match?

---

## Numbers on screen (please check against Kaggle)
- **Week 1:** public 0.122 → 0.127 → 0.12965 (final); private board 1st.
- **Week 2:** public 0.1486 (first try) → 0.156 → 0.166 → probing 0.172 → 0.17445 (**set aside, not used**) → 0.16690 (pre-probing model, #12) → **0.16840 (final, #31, after the motor check)**.
- **Motor check (scene 7b):** injury claim inflation +4.5% a year (was 0%); 77% of 2025 customers new; motor price +9.4%; injury cost ×1.116, new-customer rows ×1.061.
- **Severity:** new-market claims cost 35%–87% of the developed market; car claims 51%–65%.
