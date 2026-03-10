# Brainstorm: Article 3 — First Inference on RISC-V

## Panel
- **Claude** (proposer) — Anthropic Claude Opus 4.6
- **Gemini** (reviewer 1) — Google Gemini
- **Copilot** (reviewer 2) — OpenAI GPT-5.2

## Original Proposal
Technical blog post documenting the first LLM inference on RISC-V via vLLM/transformers. War story approach: vLLM fails three times (circular import, multiprocessing, C extension wall), transformers works at 0.93 tok/s with SmolLM2-135M.

## Gemini's Review

### Strengths
- War story narrative is highly effective for technical audiences
- Gap identification (vLLM._C structural absence) is the right insight
- Comparative hardware (F3 vs K3) provides performance spectrum
- Acknowledging llama.cpp is mandatory

### Weaknesses
- **Float32 trap**: 0.93 tok/s is a "failure state" without mentioning quantization
- **Memory bandwidth**: LLM inference is bandwidth-bound, not compute-bound; need RAM specs
- **vLLM value prop unclear**: PagedAttention matters for serving, not single-stream on an SBC
- **RVV not being used**: PyTorch likely uses generic kernels, not vector extensions

### Alternatives Suggested
- ONNX Runtime / OpenVINO (growing RISC-V support)
- TinyGrad (aggressive RISC-V support)
- IPEX-style kernel bypass for vLLM

### Verdict: Revise — add quantization data, frame 0.93 as "FP32 baseline floor"

## Copilot's Review

### Strengths
- "Three strikes" ladder is relatable debugging narrative
- vLLM RISC-V feature gating is valuable ecosystem signal
- One hard data point + concrete blocker gives factual spine

### Red Flags
- **0.93 tok/s credibility risk**: readers will question methodology
- **"vLLM failed" as takeaway**: need to quantify what works vs what's blocked
- **K3 optimism**: clock speed ≠ linear speedup; bandwidth/cache dominate
- **Multiprocessing rabbit hole**: spawn/fork + OpenMP + Gloo can deadlock

### Missing Pieces
- Reproducibility pack (exact versions, settings, env vars)
- Metrics beyond tok/s (time-to-first-token, RSS, power)
- Fair baseline (quantized models, BF16 availability)
- vLLM C extension wall scope (impossible vs needs-work?)

### Simpler Alternative
"Transformers baseline + llama.cpp reality check + vLLM gap analysis" — keep story short, make data unassailable.

### Verdict: Revise — need K3 numbers, llama.cpp numbers, and defensible methodology

## Consensus (both reviewers agree)

1. **0.93 tok/s needs context** — must be framed as unoptimized FP32 baseline, not final result
2. **llama.cpp comparison is mandatory** — without it, article exists in a vacuum
3. **Quantization must be mentioned** — FP32 is worst case, readers need to see the optimization path
4. **K3 benchmarks needed** — F3 alone isn't enough, need hardware comparison
5. **Benchmarking methodology must be rigorous** — or comments will focus on measurement flaws
6. **vLLM failure needs scoping** — explain exactly what's needed to fix it, whether it's realistic

## Synthesis: Refined Approach

### What to Keep
- War story narrative (Option A) — both reviewers endorse it
- The "three strikes" vLLM failure ladder
- SmolLM2-135M + TinyLlama results
- vLLM RISC-V detection logs (they're gold)
- The C extension wall as natural cliffhanger

### What to Add

1. **Benchmarking methodology section** (Copilot's insistence)
   - Exact hardware specs (LPDDR4 bandwidth for F3)
   - Software versions (Python, PyTorch, transformers, kernel)
   - Measurement: exclude model load, report TTFT + generation separately
   - Environment: OMP_NUM_THREADS, OPENBLAS settings, CPU governor
   - Multiple runs for variance

2. **llama.cpp comparison** (both reviewers)
   - Build llama.cpp on F3 (should be straightforward)
   - Run same models in GGUF Q4_K_M format
   - Show the "what's possible with proper optimization" baseline
   - This prevents the "RISC-V is a toy" conclusion

3. **Frame FP32 as the floor** (Gemini)
   - Make clear: no quantization, no RVV, no optimization
   - Show optimization roadmap: quantization → RVV kernels → vLLM C extensions
   - Each step expected to bring significant improvement

4. **K3 benchmarks** (both reviewers)
   - Same tests on SpacemiT K3
   - Include memory bandwidth specs
   - Don't promise linear speedup — let the data speak

5. **vLLM gap analysis** (both reviewers)
   - Exact breakdown of what vllm._C provides
   - Whether PR #20292's RVV kernels would fix the AssertionError
   - Estimated effort to get vLLM inference working (is it 1 week or 6 months?)

### What to Drop
- ONNX Runtime / OpenVINO / TinyGrad — too many tools dilutes the story
- Deep multiprocessing debugging section — keep it brief
- Power draw / thermal analysis — nice-to-have, not essential for story

### Revised Article Structure

**Title**: "First Words: LLM Inference on a RISC-V Board" (or "0.93 Tokens Per Second")

1. **The Fix That Wasn't** (~300 words)
   - Another circular import in vLLM. Same pattern, different file.
   - Quick fix, move on. Readers who followed articles 1-2 will appreciate the callback.

2. **Three Strikes** (~600 words)
   - vLLM attempt 1: wrong API → quick fix
   - vLLM attempt 2: multiprocessing spawn → __main__ guard
   - vLLM attempt 3: the wall — vllm._C missing, AssertionError
   - Key logs: RISC-V detection, chunked prefill disabled, KV cache allocated
   - The takeaway: vLLM is 90% there. The last 10% needs C extensions.

3. **The Workaround** (~400 words)
   - Fall back to transformers + PyTorch
   - SmolLM2-135M: X tok/s (provide methodology)
   - TinyLlama-1.1B: Y tok/s
   - The model's output about RISC-V licensing (comic relief)

4. **The Numbers** (~600 words)
   - Benchmarking methodology (hardware, software, settings)
   - Results table: model × hardware × framework × dtype
   - Include llama.cpp GGUF as "optimized baseline"
   - F3 vs K3 comparison
   - Memory usage (peak RSS)
   - Time-to-first-token vs generation speed

5. **Why So Slow?** (~400 words)
   - FP32 is the worst case (no quantization)
   - PyTorch isn't using RVV yet
   - No kernel optimizations (generic matmul)
   - Memory bandwidth is the real constraint
   - The optimization roadmap: what each step would bring

6. **The vLLM Gap** (~300 words)
   - What vllm._C provides (attention kernels, KV cache ops)
   - PR #20292 status (RVV kernels exist, were positively reviewed)
   - What's needed: cmake fix + kernel compilation + testing
   - Estimated scope: days, not months

7. **The Honest Assessment** (~300 words)
   - RISC-V for edge AI: not ready for production, but closer than most think
   - The software stack is the bottleneck, not the hardware
   - llama.cpp proves the hardware can do it
   - vLLM would bring serving infrastructure (API, batching, streaming)

~3000 words total

### Data Collection Plan (before writing)

| Test | Hardware | Framework | Model | Status |
|------|----------|-----------|-------|--------|
| SmolLM2-135M FP32 | F3 | transformers | 135M | DONE (0.93 tok/s) |
| TinyLlama-1.1B FP32 | F3 | transformers | 1.1B | RUNNING |
| Qwen2.5-0.5B FP32 | F3 | transformers | 0.5B | TODO |
| SmolLM2-135M GGUF Q4 | F3 | llama.cpp | 135M | TODO |
| TinyLlama-1.1B GGUF Q4 | F3 | llama.cpp | 1.1B | TODO |
| SmolLM2-135M FP32 | K3 | transformers | 135M | TODO |
| TinyLlama-1.1B FP32 | K3 | transformers | 1.1B | TODO |
| SmolLM2-135M GGUF Q4 | K3 | llama.cpp | 135M | TODO |
| TinyLlama-1.1B GGUF Q4 | K3 | llama.cpp | 1.1B | TODO |
| vLLM SmolLM2-135M | F3 | vLLM | 135M | FAILED (C ext) |

### Addressing Reviewer Concerns

| Concern | Response |
|---------|----------|
| Float32 trap | Frame as "unoptimized baseline" with optimization roadmap |
| llama.cpp comparison | Include as "what's possible" — shows hardware capability |
| 0.93 credibility | Add methodology section, separate TTFT from generation |
| K3 optimism | Let data speak, don't promise linear speedup |
| vLLM value prop | Explain: serving infra, API compat, batching — future, not now |
| RVV not used | State explicitly: PyTorch generic kernels, no vectorization yet |
| Memory bandwidth | Include LPDDR4 specs, explain bandwidth-bound nature of LLM decode |
| Quantization | llama.cpp GGUF shows the quantized path; note bitsandbytes needs CUDA |

## Open Questions

1. **When can we access the K3?** Needed before publishing.
2. **Does llama.cpp build on riscv64?** Almost certainly yes, but needs verification.
3. **Can we get Qwen3 models?** Qwen3-0.6B would be a good modern test case.
4. **Should we profile the bottleneck?** (cProfile on transformers inference) — strong signal but adds work.

## Next Steps

1. Wait for TinyLlama results on F3
2. Build and benchmark llama.cpp on F3
3. Run Qwen2.5-0.5B or Qwen3-0.6B on F3
4. Get K3 access and run same benchmarks
5. Write article with all data
6. Run through style-replicator + humanizer pipeline
