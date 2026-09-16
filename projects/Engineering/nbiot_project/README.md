# NB-IoT Cross-Layer Adaptive Packet Configuration — Complete Pipeline

This is a complete, runnable rebuild of the inherited project: every file needed
for `RUN_ALL` to execute end-to-end and produce real figures/tables is now
present. Files that already worked correctly are carried over unchanged; files
that were missing have been written from scratch; files that had bugs are
fixed with the change clearly documented in a comment inside the file itself.

## How to run

```matlab
>> RUN_ALL
```

This calls, in order: `scripts/validate_setup.m` → `scripts/generate_dataset.m`
→ `scripts/train_rl_agent.m` → `scripts/evaluate_baselines.m` →
`scripts/generate_figures.m` → `scripts/generate_report_tables.m` →
`scripts/statistical_analysis.m` → `scripts/compare_with_literature.m`.

Outputs land in:
- `dataset_nb_iot.csv` — 2,000-sample sweep for the model-curve figures
- `trainedAgent.mat` — trained `DQNAgentCustom` + `trainingStats` table
- `evalResults.mat` — long-format results table + per-scenario summary
- `statisticalResults.mat` — per-scenario ANOVA / t-test results
- `docs/figures/*.png` / `*.pdf` — thirteen figures (see below)
- `docs/tables/results_*.tex` — six LaTeX fragments: the four original
  per-scenario/headline tables (now with real numbers instead of
  placeholder dashes), plus `results_statistics.tex` and
  `results_literature_comparison.tex` (new — see Task 2 below)

## Task 2 — supervisor's "no baseline comparison" / "results not complete" feedback

Two things were added specifically to answer this:

**1. `scripts/statistical_analysis.m`** — Section 4.5 of the document claims
specific figures ("Energy Reduction Improvement: 37%–92% (p<0.001)",
"Reliability Improvement: 87.7%–98.0% (p<<0.001)") and says `anova1`/`ttest2`
were used to get them, but nothing in the code you were given actually
computed those numbers. This script runs a real one-way ANOVA per scenario
per metric, and a real two-sample t-test of ProposedDQN vs. each of the four
baselines, on the actual per-seed data in `evalResults.mat`. It prints the
real energy-reduction and reliability-improvement ranges to the console and
writes `docs/tables/results_statistics.tex`. Requires the Statistics and
Machine Learning Toolbox for p-values; falls back to just the % changes with
a warning if that toolbox isn't available.

**2. `scripts/compare_with_literature.m`** — this is the direct answer to
*"you have to compare ... with your recent baseline paper."* Conventional
and FixedPacket were already simulated baselines (`baselineConventional.m`,
`baselineFixedPacket.m`); what was missing was benchmarking against the five
papers your supervisor named. I looked up each paper's actual reported
headline metric:

| Study | Reported metric |
|---|---|
| Abbas et al. (2025), GLOBE framework, *IEEE IoT Journal* | 30–75% energy reduction vs. baseline config |
| Al-Sammak et al. (2025), *Energies* 18(4):987 | NB-IoT arm: ~87.3% reduction in energy-consumption spike frequency, ~86.8% fewer transmitted packets |
| Anbazhagan & Mugelan (2024), *Computer Networks* 252:110670 | SAC vs. DQN/PPO: +10.25% energy efficiency, +214.98% throughput, +614.46% fairness (Jain's index) |
| Arslan et al. (2024), *J. Scientific Reports-A* 59:32–57 | DQN duty-cycling extended node uptime to 731 days (~2.7× the best prior comparator) |
| Alipio et al. (2024), *Internet of Things* 28:101378 | Systematic review — no single quantitative headline metric to compare against |

The script computes this study's own ProposedDQN energy-reduction % (vs. the
Conventional baseline, averaged across the three scenarios) and places it
alongside these published figures in `docs/tables/results_literature_comparison.tex`
and a companion bar chart, `docs/figures/energy_reduction_vs_literature.png`.

**Important honesty caveat, stated in the table itself**: these are different
studies with different hardware, traffic models, and in some cases different
radio technologies (LoRaWAN + NB-IoT smart meters vs. this study's pure
NB-IoT link-level simulation). This is literature benchmarking — standard
practice for situating a thesis's results in the field — not a controlled,
apples-to-apples experiment. The table and the write-up around it should say
that explicitly, not imply the numbers were produced under identical
conditions.

**Runtime**: training is up to 500 episodes × 200 steps. With the plain-MATLAB
network this is minutes to tens of minutes on typical hardware. For a quick
smoke test, open `scripts/train_rl_agent.m` and lower `NUM_EPISODES` before
running `RUN_ALL`, or run `RUN_SIMULATION.m` first (a 3-line-per-scenario
sanity check with no training).

If you only want to check the plumbing without training: run
`RUN_SIMULATION.m` directly.

## Project layout

```
setup_path.m              adds src/ and scripts/ to the path
RUN_ALL.m                 full pipeline driver
RUN_SIMULATION.m          quick channel/BLER/energy smoke test

scripts/
  validate_setup.m        toolbox/config sanity checks
  generate_dataset.m       2000-sample sweep -> dataset_nb_iot.csv
  train_rl_agent.m         trains the proposed DQN -> trainedAgent.mat
  evaluate_baselines.m     5 policies x 3 scenarios x 10 seeds -> evalResults.mat
  generate_figures.m       13 figures -> docs/figures/ (includes a 3-panel
                            Energy/Reliability/Latency comparison matching
                            the original report's Figure 4.3 layout)
  generate_report_tables.m 4 LaTeX tables -> docs/tables/
  statistical_analysis.m   NEW (Task 2): real ANOVA/t-test -> docs/tables/results_statistics.tex
  compare_with_literature.m NEW (Task 2): benchmarks vs 5 cited papers -> docs/tables/results_literature_comparison.tex

src/
  getDefaultConfig.m       all simulation/RL parameters
  pathLossSNR.m            log-distance link budget (unchanged)
  channelSnapshot.m        FIXED: scenario-aware SNR generation
  markovSNR.m              temporal-correlation fluctuation (unchanged)
  buildDefaultMarkovTransition.m  (unchanged)
  blerModel.m              logistic BLER waterfall model (unchanged)
  energyModel.m            FIXED: capped energy-per-success blow-up
  phyPacketTiming.m        (unchanged)
  phyPacketTimingLTE.m     (unchanged, optional LTE-Toolbox path)
  baselineConventional.m   (unchanged)
  baselineFixedPacket.m    (unchanged)
  baselineSnrAdaptive.m    (unchanged)
  PriorRLAgent.m           tabular Q-learning baseline (unchanged)
  NBIoTRLEnv.m             NEW: the RL environment (was missing)
  QNetwork.m               NEW: dependency-free MLP Q-network
  DQNAgentCustom.m         NEW: DQN training loop (replay + target net)
```

## What was missing and had to be written from scratch

The uploaded files referenced but did not include:
- `NBIoTRLEnv` — the RL environment class (`reset(env)`, `step(env, action)`,
  `env.ActionTable` are all called by `PriorRLAgent.m` and the evaluation
  scripts, but no class definition existed anywhere).
- `train_rl_agent.m` and `validate_setup.m` — only referenced by name in
  `RUN_ALL`, never provided.
- A trained-agent interface (`getAction(agent, {obs})`), implying reliance on
  MATLAB's Reinforcement Learning Toolbox — not something I could confirm is
  licensed on your machine, so this project instead ships `QNetwork.m` +
  `DQNAgentCustom.m`, a small dependency-free DQN (manual forward/backward
  pass, Adam optimiser, experience replay, target network) matching the
  architecture described in report Section 3.2.2 (2 hidden layers, 64 ReLU
  units each). **If you do have the RL/Deep Learning Toolboxes licensed**, you
  can swap in `rlDQNAgent` without touching `NBIoTRLEnv`, `evaluate_baselines.m`,
  or `generate_figures.m` — they only depend on `agent.selectAction(obs, greedy)`
  and `agent.Env.ActionTable`.

The reward function (report eqn. 3.5) is only described narratively in the
text you shared, not given as a closed-form equation, so `NBIoTRLEnv.step()`
implements an explicit, documented interpretation of it (energy-efficiency
gain minus a reliability penalty minus a latency penalty minus a QoS-violation
penalty, using the existing `cfg.rl.rewardWeights.alpha1/alpha2/alpha3`). If
your supervisor wants a different exact formula, this is the one function to
edit.

## Bugs fixed (see in-file comments for full detail)

1. **`channelSnapshot.m` — scenario differentiation was silently disabled.**
   With `cfg.channel.useMarkov = true` (the default), the original code
   called `markovSNR` *without* passing `envType`, so urban / rural /
   deep_indoor all drew SNR from the same scenario-agnostic 6-level chain —
   discarding the path-loss exponent, penetration loss, and MCL differences
   defined in `cfg.env.*`. Fixed by always computing the scenario-specific
   mean SNR via `pathLossSNR` first, then applying the Markov chain only as a
   zero-mean temporal fluctuation on top of it.

2. **`energyModel.m` — runaway energy at BLER≈1.** The original
   `successProb = max(1-bler, 1e-3)` clamp let `energyJ` blow up to ~1000×ⅹ a
   single attempt's energy whenever BLER was near 1, occasionally exceeding
   the entire device battery budget for a single packet. Fixed by loosening
   the floor to `5e-2` and adding an explicit cap at
   `cfg.energy.maxEnergyPerPacketJ` (defaults to the full battery budget).

3. **Path/portability issues.** All scripts previously relied on relative
   filenames (`'evalResults.mat'`, `'dataset_nb_iot.csv'`) that only resolve
   correctly if MATLAB's current folder happens to be the project root. Every
   script now resolves paths through `projectRoot = setup_path()`.

4. **`generate_figures.m` — `isprop` on a table.** `trainingStats` is a
   MATLAB `table`, not a class instance with `isprop`; column-existence is
   now checked via `ismember(...,Properties.VariableNames)`.

5. **`generate_report_tables.m` — `fwrite` on a string object.** Replaced
   with `fprintf(fid, '%s', fragment)` for cross-version reliability.

6. **`RUN_SIMULATION.m` — `blerModel` called without `cfg`.** Not fatal (the
   function has a default), but inconsistent; now passes `cfg` explicitly.

## Known discrepancy left for you to resolve (not auto-fixed)

Report Table 3.1 states repetition factors "1–32"; `getDefaultConfig.m` (and
the rest of the codebase, including your `PriorRLAgent.m`) uses
`[1 2 4 8 16 32 64 128]`. I kept the code's grid since that's what's actually
exercised end-to-end and it's internally consistent with the action-table
construction in `NBIoTRLEnv`/`PriorRLAgent`; you should update Table 3.1 to
match, or tell me to shrink the grid to `[1 2 4 8 16 32]` if 1–32 is the
intended design and the code is what's wrong.

## On the existing Chapter 4 figures/tables

As covered in the earlier audit: the figures and tables currently in
`Implemetation.docx` (Fig. 4.1–4.7, Tables 4.1–4.2) do not appear to have
been produced by this codebase (mismatched policy names, an SNR range the
current path-loss model cannot produce, a BLER model the current code
explicitly says it replaced, and numbers that don't agree between the table
and its own supporting figure). Once you run `RUN_ALL` with this project,
`docs/figures/` and `docs/tables/` will contain the real, reproducible
replacements — regenerate Chapter 4 from those rather than editing the old
numbers by hand.
