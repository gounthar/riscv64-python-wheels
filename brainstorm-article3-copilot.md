## What Works — Strengths worth keeping
- Clear narrative hook: “we finally try inference” after build/wheels groundwork.
- The “three strikes” ladder is relatable and teaches real debugging patterns (API mismatch → multiprocessing → native extensions).
- You already have one hard data point (0.93 tok/s) and a concrete technical blocker (`vllm._C`), which gives the article a factual spine.
- Noting vLLM’s RISC-V feature gating (chunked prefill/prefix caching off) is valuable signal: upstream is aware, not oblivious.

## Red Flags — Risks and hidden costs
- **0.93 tok/s credibility risk**: readers will assume it’s mis-measured (includes model load? warmup? tokenizer time? first-token latency? CPU freq throttling?). If methodology isn’t airtight, you’ll get dunked on.
- **“vLLM failed” may be the takeaway** unless you explicitly quantify *what works today* and *what’s blocked* (and why that’s non-trivial).
- **Hidden production cost**: transformers “works immediately” but may hide nasty realities—RAM pressure, swap death spirals, long cold starts, and poor tail latency on small boards.
- **Multiprocessing + RISC-V**: spawn/fork notes can become a rabbit hole; readers may copy/paste and still deadlock due to OpenMP, Gloo env vars, or thread oversubscription.
- **K3 optimism**: 2.5 GHz ≠ linear speedup. Memory bandwidth, cache, ISA flags, and BLAS backend dominate. You’re setting expectations you might not meet.

## Missing Pieces — What the proposal doesn't address
- Reproducibility pack: exact board, kernel, governor, RAM, swap, storage, temps; Python/PyTorch/transformers versions; command lines; prompt; decoding settings; threads (`OMP_NUM_THREADS`, `MKL/OPENBLAS`, `torch.set_num_threads`).
- Metrics beyond tok/s: **time-to-first-token**, peak RSS, steady-state RSS, power draw/thermals, and whether results are after warmup.
- A fair baseline: int8/4-bit (GGUF/bitsandbytes equivalent), BF16 availability, and whether you’re accidentally running FP32 everywhere.
- vLLM “C extension wall” scope: is it *impossible* on RISC-V today, or “needs toolchain + PyTorch C++ ABI + feature flags”? Spell out the real dependency chain and why it breaks.

## Simpler Alternative — A less complex approach that might work
Write it as: **“Transformers baseline + llama.cpp reality check + vLLM gap analysis”**.
- Do 2–3 tight benchmarks (one small, one 1B-ish) on F3 and K3.
- Include llama.cpp GGUF quantized numbers early to anchor expectations.
- Keep vLLM as a short, surgical section: what initializes, exact crash point, and what upstream work is required—without the full war-story arc.

## Verdict — Proceed as-is, revise, or rethink
**Revise.** Publish only once you have (1) K3 numbers, (2) llama.cpp numbers, and (3) a defensible benchmarking methodology section. Keep the story, but make the data unassailable—otherwise the comments will focus on measurement flaws instead of the real platform gaps.

