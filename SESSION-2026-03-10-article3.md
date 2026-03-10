# Session 2026-03-10: Article 3 — First Inference on RISC-V

## Summary

Attempted first LLM inference on the BananaPi F3 (SpacemiT K1, riscv64). Got transformers working, vLLM failed at C extension wall. Ran brainstorm with Gemini + GPT-5.2 for article planning.

## Key Results

### Transformers Inference — SUCCESS

| Model | Params | Load Time | Tokens | Time | tok/s | RAM Used |
|-------|--------|-----------|--------|------|-------|----------|
| SmolLM2-135M | 135M | 28.7s | 50 | 53.9s | **0.93** | ~0.5 GB |
| TinyLlama-1.1B-Chat | 1.1B | 200.6s | 100 | 665.4s | **0.15** | ~4.1 GB |

All tests: float32, PyTorch 2.10.0, Python 3.13.5, 8 cores @ 1.6 GHz, 15.5 GB RAM.

### vLLM Inference — FAILED (3 attempts)

1. **Attempt 1**: `EngineArgs.__init__() got an unexpected keyword argument 'device'` — wrong API usage
2. **Attempt 2**: multiprocessing spawn error — missing `if __name__ == '__main__'` guard
3. **Attempt 3**: `AssertionError` in `cpu_model_runner.py:39` — `vllm._C` (C extensions) not built

vLLM got far: detected RISC-V, disabled chunked prefill + prefix caching, allocated 7.76 GiB KV cache, initialized Gloo distributed backend. Failed at model runner initialization because C extensions are required.

### Fixes Applied on F3

1. `vllm/v1/sample/logits_processor/builtin.py` line 9: Changed `from vllm import SamplingParams` → `from vllm.sampling_params import SamplingParams` (circular import fix)

### Discoveries

- **llama-server already running on F3!** Process from Feb 27: `llama-server -m ~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf --host 0.0.0.0 --port 8080 -t 8`
- **llama.cpp v1 (2e7e638) built on F3**: GCC 14.2.0, full suite of tools
- **GGUF model exists**: `/home/poddingue/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf`
- **hf_xet installed** during session (speeds up HF downloads)

## Brainstorm Results

### Panel: Claude + Gemini + GPT-5.2

Both reviewers said **Revise** (not reject). Key consensus:
1. 0.93 tok/s must be framed as "unoptimized FP32 baseline floor"
2. llama.cpp comparison is mandatory
3. K3 benchmarks needed
4. Benchmarking methodology must be rigorous
5. Quantization discussion required

### Recommended Article Structure

"Three Strikes and a Workaround" war story (~3000 words):
1. The Fourth Import Fix (circular import)
2. Three vLLM strikes (API, multiprocessing, C extensions)
3. The Workaround (transformers SUCCESS)
4. The Numbers (benchmarks with methodology)
5. Why So Slow? (FP32, no RVV, no quantization)
6. The vLLM Gap (what's needed for Phase 2)
7. The Honest Assessment (RISC-V for edge AI)

Full synthesis at: `/tmp/brainstorm-synthesis.md`

## Data Collection Plan (TODO for next session)

| Test | Hardware | Framework | Model | Status |
|------|----------|-----------|-------|--------|
| SmolLM2-135M FP32 | F3 | transformers | 135M | ✅ DONE (0.93 tok/s) |
| TinyLlama-1.1B FP32 | F3 | transformers | 1.1B | ✅ DONE (0.15 tok/s) |
| Qwen2.5-0.5B FP32 | F3 | transformers | 0.5B | TODO |
| TinyLlama Q4_K_M | F3 | llama.cpp | 1.1B | TODO (model + binary ready!) |
| SmolLM2-135M Q4 | F3 | llama.cpp | 135M | TODO (download GGUF) |
| All above | K3 | both | both | TODO (need K3 access) |
| vLLM SmolLM2-135M | F3 | vLLM | 135M | ❌ FAILED (C ext wall) |

### Quick Win for Next Session
The llama-server is already running on F3 port 8080 with TinyLlama Q4_K_M! Just need to benchmark it:
```bash
# Already running:
# llama-server -m ~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf --host 0.0.0.0 --port 8080 -t 8

# Benchmark:
~/llama.cpp/build/bin/llama-bench -m ~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf -t 8
```

## User Requests Noted

- Try Qwen3.5 model (check availability — may be Qwen2.5 or Qwen3)
- K3 access available — run same benchmarks for comparison article
- Add hf_xet to setup (done)
- Save all terminal output for article 3 (done — raw notes at /tmp/article3-raw-notes.md)
- Vary "You know that feeling" opener for article 3

## Files Created/Modified

- `/tmp/riscv64-wheels-update/SESSION-2026-03-10-article3.md` — this file
- `/tmp/brainstorm-proposal.md` — Article 3 proposal
- `/tmp/brainstorm-gemini.md` — Gemini review
- `/tmp/brainstorm-copilot.md` — GPT-5.2 review
- `/tmp/brainstorm-synthesis.md` — Full brainstorm synthesis
- `/tmp/article3-raw-notes.md` — Raw notes with all logs and observations
- `/tmp/article3-inference-log-transformers.txt` — SmolLM2 transformers output
- `/tmp/article3-vllm-failure-log.txt` — vLLM attempt 3 failure log
- F3: `~/vllm/vllm/v1/sample/logits_processor/builtin.py` — circular import fix

## hf_xet Compilation (Still Running)

`pip install hf_xet` triggered a massive Rust build on the F3 (maturin + cargo). It's a Rust crate with dependencies: regex-automata, time, chrono, syn, aws-lc-sys. Expected 30-60 min compile.

**Candidate for wheel factory**: Fork `huggingface/hf-xet` and add to riscv64-python-wheels index. Would save all riscv64 users from this lengthy compilation.

## llama.cpp Already on F3

- **Built**: v1 (2e7e638), GCC 14.2.0, riscv64
- **Running**: `llama-server` on port 8080 with TinyLlama Q4_K_M (since Feb 27!)
- **GGUF model**: `~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf`
- **llama-bench**: Available at `~/llama.cpp/build/bin/llama-bench`
- **Quick benchmark for next session**: `~/llama.cpp/build/bin/llama-bench -m ~/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf -t 8`

## PR #8 Status

Pushed reviewer feedback fixes to `fix/stale-wheel-detection` branch. Commit `4735ca5`. Ready for merge.
