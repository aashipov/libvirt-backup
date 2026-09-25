# Contributors

# AI Usage Policy

> [!IMPORTANT]
>
> AI-generated code is allowed. What is **not** allowed is submitting code you do not understand. You are 100% responsible for every line, however it was produced.
> 
> Local/cloud models will produce a lot of `belles-lettres` / `fluff` / `good intentions` / `Salon Blödsinn`.
> 
> Check relevance & [TEST.md](./TEST.md) conformance before commiting those.

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

Perform a thorough, line-by-line and file-by-file review of the project in the current working directory.

**Constraints:**

* **Ignore these directories:** .git, .github, .zed
* **Ignore these files:** .gitignore, CONTRIBUTING.md, gui, HEADFUL.md, LICENSE, openbox-rc.xml, SECURITY.md, TEST.md, weston-runner
* **Rules:** You have full read permissions to analyze the code line by line, but you must not modify any files.

**Goal:**
Identify scripting bugs, security flaws (like injection or unquoted variables), and edge-case failures.

For every issue found, specify the file name, line numbers, a clear explanation of the Shell best practice violated, and a concrete example of the optimized code.

Dump review report to a 'libvirt-backup_review_report.md' file.
