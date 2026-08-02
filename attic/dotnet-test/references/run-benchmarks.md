# BenchmarkDotNet procedure

Use this reference for .NET micro-benchmarks. Prefer an existing benchmark project and its checked-in configuration; do not invent a new harness when the repository already has one.

## 1. Establish the comparison

- State the performance question and the metric that matters: elapsed time, throughput, allocation, or GC.
- Identify the current implementation as `[Benchmark(Baseline = true)]` and change one variable in the candidate.
- Keep inputs representative and deterministic. Put setup outside the measured method with `[GlobalSetup]`.
- Record SDK/runtime, CPU, OS, power mode, and relevant environment variables when results will be compared later.

## 2. Run from the discovered project

Find the existing benchmark `.csproj`; run it in Release mode without assuming a repository layout:

```bash
dotnet run --project path/to/Benchmarks.csproj -c Release -- --filter "*TargetBenchmark*"
```

Use the benchmark project's own arguments when they differ. BenchmarkDotNet writes results under `BenchmarkDotNet.Artifacts/` relative to its working directory unless configuration overrides that path.

Minimal shape:

```csharp
using BenchmarkDotNet.Attributes;

[MemoryDiagnoser]
public class ParserBenchmarks
{
    [Params(10, 1_000)]
    public int Count { get; set; }

    [GlobalSetup]
    public void Setup() { /* deterministic inputs */ }

    [Benchmark(Baseline = true)]
    public object Current() => ParseCurrent(Count);

    [Benchmark]
    public object Candidate() => ParseCandidate(Count);
}
```

Let BenchmarkDotNet choose warmup and iteration counts by default. Override `[WarmupCount]` or `[IterationCount]` only when the default run is impractical or the report shows instability; record the override with the result.

## 3. Interpret the report

Read columns together:

- **Mean** is the estimated average; compare it with **Error** and **StdDev**, not in isolation.
- **Ratio** is relative to the baseline: `0.50` is about twice as fast; `1.50` is about 50% slower.
- **Allocated** and Gen0/1/2 counts expose GC cost that elapsed time alone hides.
- **Outliers** may be environmental or real tail behavior. Do not delete them merely to improve the headline.
- A **multimodal distribution** means multiple timing populations were observed. Treat a small mean delta as inconclusive until interference or workload phases are explained.

Compare like with like: same commit inputs, runtime, architecture, configuration, and machine conditions. A single run on different hardware is not a regression verdict.

## 4. Failure and stability checks

- "Benchmarks must be run in Release mode" → rerun with `-c Release`.
- "No benchmarks found" → verify `[Benchmark]`, filter syntax, and the project entry point.
- Benchmark throws → run the method normally with the same input, fix correctness first, then benchmark.
- High variance or multimodal warning → close competing workloads, keep power mode stable, rerun, and compare the full distribution.
- Results too short/noisy → allow BenchmarkDotNet's default adaptive run or increase invocation/iteration count with the reason recorded.

## Completion evidence

Return the exact command and project path, environment summary, baseline/candidate Mean + Ratio + Allocated, warnings, artifact path, and whether the result is conclusive. Optimization claims require repeatable improvement without a correctness regression.
