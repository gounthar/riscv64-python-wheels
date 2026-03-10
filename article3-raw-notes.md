# Article 3 Raw Notes — First Inference on RISC-V

## Key Events (chronological)

### 1. vLLM Import Broken (circular import)
- `from vllm import LLM` failed with: `ImportError: cannot import name 'SamplingParams' from 'vllm'`
- Root cause: `vllm/v1/sample/logits_processor/builtin.py` line 9: `from vllm import SamplingParams`
- This triggers lazy `__getattr__` in `__init__.py` during the import chain for `LLM`
- Fix: change to `from vllm.sampling_params import SamplingParams` (direct import)
- Same pattern as previous lazy import fixes (PEP 563 / `from __future__ import annotations`)
- **One more circular import trap to add to our collection**

### 2. Transformers Inference — SUCCESS
- Model: HuggingFaceTB/SmolLM2-135M (135M params)
- **50 tokens in 53.9 seconds = 0.93 tok/s**
- Model loaded in 28.7s
- Prompt: "Hello, I am a RISC-V processor and I"
- Output: "have only $0.05 for the license. This is not an issue. I have the licence of course and I just want to learn how to use it."
- **The model talked about RISC-V licensing! Hilarious.**
- Platform: Python 3.13.5, PyTorch 2.10.0, 8 cores, 15.5 GB RAM

### 3. vLLM Inference — FAILED (attempt 1)
- `EngineArgs.__init__() got an unexpected keyword argument 'device'`
- The `device` parameter was added to LLM but not to EngineArgs
- Easy fix: just remove `device` kwarg

### 4. vLLM Inference — FAILED (attempt 2, multiprocessing)
- `RuntimeError: An attempt has been made to start a new process before the current process has finished its bootstrapping phase`
- Script ran outside `if __name__ == '__main__':` guard
- vLLM uses multiprocessing spawn method

### 5. vLLM Inference — FAILED (attempt 3, AssertionError)
- Got MUCH further:
  - Resolved architecture: LlamaForCausalLM
  - Detected RISC-V CPU, disabled chunked prefill and prefix caching
  - Allocated 7.76 GiB KV cache
  - Initialized Gloo distributed backend (rank 0, world_size 1)
  - **Failed at `cpu_model_runner.py:39`**: `assert isinstance(device_tensor, torch.Tensor)`
- The `_postprocess_tensors` method assumes C extension tensors from `vllm._C`
- `WARNING: Failed to import from vllm._C: ModuleNotFoundError`
- This is the Phase 2 wall: vLLM's CPU model runner REQUIRES the C extensions
- Without `vllm._C`, the input batch tensors aren't initialized correctly

### 6. TinyLlama 1.1B Test (pending)
- Running in background on F3
- Expected: slower tok/s due to 8x larger model
- If RAM allows, good benchmark comparison

## Architecture Insights

### vLLM on RISC-V — What Works
- Import chain (after circular import fixes): OK
- Model architecture resolution (LlamaForCausalLM): OK
- RISC-V CPU detection: OK (disables chunked prefill, prefix caching)
- Gloo distributed backend: OK
- KV cache allocation: OK

### vLLM on RISC-V — What Doesn't
- `vllm._C` (C++ extensions): NOT BUILT — requires cmake + C++ compilation with riscv64 support
- CPU model runner: FAILS without `vllm._C` (AssertionError in _postprocess_tensors)
- Result: vLLM cannot actually run inference without the C extensions

### The Gap
- Phase 1 (pure Python): Gets us to import, but not to inference
- Phase 2 (C++ extensions): Required for inference, needs:
  1. cmake CPU extension build working on riscv64
  2. RVV kernels (optional for basic functionality, required for performance)
  3. The attention kernels from PR #20292

### Workaround
- transformers + PyTorch works for basic inference
- Performance is ~1 tok/s for 135M model on the F3
- This is the baseline. vLLM with proper C extensions would (should) be faster.

## Performance Data

| Model | Framework | Params | tok/s | Load time | Notes |
|-------|-----------|--------|-------|-----------|-------|
| SmolLM2-135M | transformers | 135M | 0.93 | 28.7s | float32 |
| TinyLlama-1.1B | transformers | 1.1B | TBD | TBD | float32 |

## Interesting Log Lines for Article

```
INFO: Chunked prefill is not supported for RISC-V CPUs; disabling it for V1 backend.
INFO: Prefix caching is not supported for RISC-V CPUs; disabling it for V1 backend.
WARNING: VLLM_CPU_KVCACHE_SPACE not set. Using 7.76 GiB for KV cache.
WARNING: Failed to import from vllm._C: ModuleNotFoundError("No module named 'vllm._C'")
INFO: Resolved architecture: LlamaForCausalLM
INFO: world_size=1 rank=0 local_rank=0 distributed_init_method=tcp://192.168.1.36:37761 backend=gloo
```

## The Story Arc

1. Fix another circular import (builtin.py SamplingParams) — "we've been here before"
2. Try vLLM inference — fail at `device` arg (quick fix)
3. Try again — fail at multiprocessing spawn (need `__main__` guard)
4. Try again — fail at C extensions (the real wall)
5. Fall back to transformers — IT WORKS! 0.93 tok/s
6. Try bigger model (TinyLlama 1.1B) — how slow is it?
7. Reflect: vLLM needs C extensions, that's Phase 2
8. What about the K3? (2.5 GHz, higher IPC — should be faster)
9. What about llama.cpp? (the elephant in the room)

## K3 Angle (user mentioned)
- SpacemiT K3: 8+8 cores, 2.5 GHz, RVV vlen=256/1024
- Cloud access available
- Could show F3 vs K3 performance comparison
- Higher clock + better microarch = maybe 3-5x faster?
- If K3 gets 3-5 tok/s with TinyLlama, that's actually usable for some use cases

## PEP 503 Index Status (user asked)
- Need to verify: https://gounthar.github.io/riscv64-python-wheels/simple/
- May be missing the 6 new packages (numpy, grpcio, orjson, multidict, frozenlist, propcache)
- The aggregate workflow may not have run since we added them
