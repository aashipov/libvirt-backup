# Contributors

# AI Usage Policy

> [!IMPORTANT]
>
> AI-generated code is allowed. What is **not** allowed is submitting code you do not understand. You are 100% responsible for every line, however it was produced.
>
> [Tau](https://github.com/huggingface/tau), [pi](https://github.com/earendil-works/pi), its [pi_agent_rust](https://github.com/Dicklesworthstone/pi_agent_rust) Rust port or [opencode](https://github.com/anomalyco/opencode); backed by [llama.cpp](https://github.com/ggml-org/llama.cpp) or [Ollama](https://ollama.com) -driven local models like [Gemma 4](https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf), [QWEN 3](https://huggingface.co/Qwen/Qwen3-4B-GGUF), [Ministral 3](https://huggingface.co/mistralai/Ministral-3-3B-Instruct-2512-GGUF), cloud models like DeepSeek V4, will produce a lot of `belles-lettres` / `fluff` / `good intentions` / `Salon Blödsinn`. Check relevance & [TEST.md](./TEST.md) conformance before commiting those. 
> [AI-harness](./AI-harness) directory contains Windows/Linux configurations for local llama.cpp and Ollama

# 'Performance' baseline

[HEADFUL.md](./HEADFUL.md) suggests XFS-formatted disk to store VM zstd-compressed qcow2 files. XFS outperforms ext4 in computation & disk intensive tasks like `vscode` compilation (Windows Server 2012R2 or newer). zstd-compressed image displays lower CPU load than its zlib-compressed clone

# Pull requests (for contributors & collaborators)

### Before you start

- Search for existing discussions and PRs first - duplicates will likely be closed without questions.
- Configure a VM for semi-automated tests (check [HEADFUL.md](./HEADFUL.md), [TEST.md](./TEST.md))

### Preparing your PR

- (Optional) ask coding agent for review
- Test your changes:
  - [test-runner.sh](./test-runner.sh) must pass

### Review prompt

Act as an autonomous expert code reviewer. Conduct a thorough, line-by-line and file-by-file review of the project in the current working directory.

**Constraints:**

* **Ignore these directories:** .git, .github
* **Ignore these files:** .gitignore, CONTRIBUTING.md, gui, HEADFUL.md, LICENSE, openbox-rc.xml, SECURITY.md, TEST.md, weston-runner
* **Rules:** You have full read permissions to analyze the code line by line, but you must not modify any files.

**Goal:**
Identify scripting bugs, security flaws (like injection or unquoted variables), performance bottlenecks (like useless uses of cat or inefficient grep/sed/awk pipelines), and edge-case failures.

For every issue found, specify the file name, line numbers, a clear explanation of the Shell best practice violated, and a concrete example of the optimized code.

Dump review report to a file in the current working directory.
