# Contributors

# AI Usage Policy

> [!IMPORTANT]
>
> AI-generated code is allowed. What is **not** allowed is submitting code you do not understand. You are 100% responsible for every line, however it was produced.
>
> [pi](https://github.com/earendil-works/pi) or [opencode](https://github.com/anomalyco/opencode), backed by [llama.cpp](https://github.com/ggml-org/llama.cpp) local models like [Gemma 4](https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf) or [QWEN 3](https://huggingface.co/Qwen/Qwen3-4B-GGUF), cloud models like DeepSeek V4, will produce a lot of `belles-lettres` / `fluff` / `good intentions` / `Salon Blödsinn`. Check relevance & [TEST.md](./TEST.md) conformance before commiting those.

# Pull requests (for contributors & collaborators)

### Before you start

- Search for existing discussions and PRs first - duplicates will likely be closed without questions.
- Configure a VM for semi-automated tests (check [HEADFUL.md](./HEADFUL.md), [TEST.md](./TEST.md))

### Preparing your PR

- (Optional) ask coding agent for opinion, e.g. `Read the project in the current working directory and suggest improvements without altering any files`
- Test your changes:
  - [test-runner.sh](./test-runner.sh) must pass
