# Chapter 3: Specification, Design and Implementation

## 3.1 Introduction

VulnForge is an educational cybersecurity training platform that creates short-lived vulnerable environments for Capture the Flag style exercises. A student signs in to a web dashboard, stores an SSH public key, selects a vulnerability category and difficulty, launches a challenge, connects to the generated environment as a low-privilege user, exploits the vulnerability, and submits a flag through the platform. Unlike a conventional static CTF platform, the challenge scenario is produced dynamically by a large language model (LLM), then deployed into a fresh LXC container.

The project therefore combines three technical roles. First, it is a web application with authentication, account settings, a dashboard, challenge state, flag submission, tutor chat, and challenge history. Secondly, it is an infrastructure orchestrator that creates, configures, verifies, and destroys Proxmox LXC containers. Thirdly, it is a constrained generative-AI pipeline that converts a user’s category and difficulty choice into a structured vulnerability specification that can be validated and injected automatically.

This section is organised into three parts. The **specification** defines what the system is required to do and the constraints under which it operates. The **design** describes the architecture, data model, challenge lifecycle, generation pipeline, verification model, and tutor workflow. The **implementation** then explains how those design ideas were realised in the codebase, focusing on the most important modules and on the practical problems that shaped the final implementation.

## 3.2 Specification

### 3.2.1 Scope and deployment assumptions

The system is intended for a supervised educational lab setting rather than a public multi-tenant cloud product. Each challenge is deployed into an Ubuntu 24.04 LXC container on a Proxmox VE host. The vulnerable machine is intended to be temporary: it exists for one challenge attempt and is later removed by the application or by a host-side cleanup process.

The main operating assumptions are as follows:

- Users authenticate through the VulnForge web application before launching challenges.
- A user must configure an SSH public key before a challenge can be launched.
- Students access the generated environment as the non-root Linux user `student`.
- The `student` user should not have normal administrative access; any privilege gain should be caused by the generated vulnerability.
- A user may have at most one active challenge at a time.
- The correct flag and the solution summary are stored server-side and are not sent to the browser while the challenge is active.
- Generated challenge containers are reachable through the deployment network, but the web application itself does not implement a full end-user VPN or network-registration system.
- Evaluation results are reported in the following chapter; this section describes the system that was built and the implementation decisions behind it.

This scope is important because it explains what VulnForge is not attempting to solve. It does not implement payment, public cloud scaling, browser-based terminals, live Proxmox administration by end users, or a complete replacement for a managed VPN. Its purpose is to demonstrate dynamic challenge generation, isolated deployment, guided assistance, flag submission, and cleanup.

### 3.2.2 Functional requirements

| ID | Requirement | Final design response |
|---|---|---|
| FR1 | Users must be able to sign up, log in, log out, and remain authenticated across page refreshes. | The application implements email/password authentication, bcrypt password hashing, HTTP-only session cookies, and a `sessions` database table. |
| FR2 | Users must be able to store and update an SSH public key. | The settings route validates the public key format and stores it against the authenticated user. |
| FR3 | Users must be able to select a vulnerability category and difficulty. | The dashboard exposes five challenge categories and three difficulty levels: beginner, intermediate, and advanced. |
| FR4 | The system must dynamically generate a vulnerability scenario. | The OpenRouter generation module builds a category-specific prompt, asks an LLM for structured JSON, and validates the result with Zod and policy checks. |
| FR5 | The system must provision a fresh vulnerable environment. | The launch route invokes Ansible, which creates an unprivileged Ubuntu LXC container through Proxmox. |
| FR6 | The system must inject user access credentials into the environment. | The lifecycle role creates the `student` account and pushes the user’s public key to `/home/student/.ssh/authorized_keys`. |
| FR7 | The system must inject the generated vulnerable content. | The injection playbook installs packages, writes generated files, sets permissions, executes setup commands, and restarts services. |
| FR8 | The system must verify basic challenge health before the user sees it. | After injection, the launch pipeline runs generated health and flag-protection checks through the verification runner. |
| FR9 | The user must receive enough information to access the challenge. | The active challenge response includes the VMID, IP address, hostname, SSH user, and a ready-to-copy `ssh student@<ip>` command. |
| FR10 | The user must be able to submit a flag and receive feedback. | The flag submission route checks ownership, status, expiry, and flag equality, then marks a correct challenge as completed. |
| FR11 | The system must prevent indefinite resource use. | Challenges have a one-hour application TTL and a Proxmox-side cron reaper for containers tagged `vulnforge`. |
| FR12 | The user must be able to end a challenge manually. | The challenge API marks the challenge as destroyed and triggers container deletion. |
| FR13 | The AI tutor must provide challenge-aware guidance without simply giving away the answer. | The chat route builds a prompt using challenge metadata and the private solution summary, then blocks responses that leak flags or the full solution. |
| FR14 | Users should be able to review previous attempts. | Challenge history pages show previous challenges, statuses, message counts, persisted tutor conversations, and the solution summary for completed challenges. |
| FR15 | The system should support later evaluation of generation and orchestration reliability. | The repository includes an evaluation harness with static, deploy, inject, and full verification modes, exporting JSON, CSV, Markdown summaries, and generated-spec artefacts. |

### 3.2.3 Non-functional requirements and constraints

**Containment.** The generated vulnerability must remain inside the intended LXC container. The design uses unprivileged containers, a non-root student account, prompt constraints forbidding host-level vulnerabilities, and an application boundary that prevents students from directly invoking Proxmox or Ansible.

**Ephemerality.** Vulnerable machines should be short-lived. The application records an expiry timestamp for each challenge and the Proxmox host runs an independent TTL reaper. This dual-layer approach avoids relying solely on the web application being online.

**Reliability across a multi-stage launch process.** Challenge launch has several stages: LLM generation, optional full verification, container deployment, injection, health verification, and database insertion. Any stage can fail. The design therefore needs clear progress feedback, useful error messages, and cleanup when a stage fails after a container has already been created.

**Safety around LLM output.** The model is untrusted. It may produce malformed JSON, unsafe validation commands, missing packages, broken applications, repeated scenarios, or flags that are directly readable. The system uses a strict schema, server-side policy validation, bounded validation command contexts, fallback models, health checks, flag-protection checks, and optional full exploit verification to reduce this risk.

**Usability.** The user should not need to understand Proxmox, Ansible, LXC internals, or the full generation pipeline. The UI should reduce the process to choosing a category and difficulty, observing progress, copying an SSH command, asking the tutor for help, and submitting a flag.

**Maintainability.** The codebase separates concerns using TypeScript modules, Drizzle repositories, Zod schemas, prompt category modules, API routes, and Ansible playbooks. This separation matters because the web UI, database model, LLM prompts, infrastructure automation, and evaluation scripts all change for different reasons.

**Network access.** The current application returns a direct container IP address and SSH command. Repository notes discuss Tailscale subnet routing and alternatives such as Headscale or reverse proxying, but these are infrastructure assumptions or proposals, not implemented Next.js application features. The final report should therefore avoid claiming that Headscale onboarding or per-user VPN provisioning is part of the application unless it is added later.

**Current hardening caveats.** The code implements the intended non-root student model, but a production deployment should ensure that container root credentials are not disclosed through repository defaults and should consider destroying containers immediately after successful completion rather than waiting for host-side TTL cleanup. These are implementation limitations rather than changes to the core architecture.

## 3.3 Design

### 3.3.1 High-level architecture

The final system is a full-stack Next.js control plane connected to four supporting systems: SQLite for state, OpenRouter for LLM calls, Ansible for automation, and Proxmox VE for container lifecycle management.

![](vulnforge_diagrams_png/01_system_architecture.png){width=100%}


The web application is the central authority. It validates input, checks authentication, stores challenge state, invokes the LLM, launches playbooks, verifies generated challenges, and decides what data may be returned to the client. Students do not receive Proxmox credentials, Ansible inventory data, API tokens, flags, generated validation commands, or the private solution summary while a challenge is active.

Ansible is used as the infrastructure automation layer rather than embedding Proxmox operations directly into the web application. This keeps the TypeScript code focused on workflow orchestration and lets container operations remain visible as playbooks. The trade-off is that the web application must parse Ansible output, handle subprocess errors, and manage cleanup when playbooks fail.

### 3.3.2 Data model

The database contains four main entities: users, sessions, challenges, and messages.

![](vulnforge_diagrams_png/07_database_schema.png){width=95%}


The `challenges` table is the central domain object. It connects a database record to the generated infrastructure by storing the Proxmox VMID, IP address, and hostname. It also stores user-facing challenge metadata such as the title, description, category, difficulty, hint, and attack vector. The `flag` and `solution_summary` fields are private fields used by the flag checker and tutor, so repository methods expose a public challenge object that omits them while the challenge is active.

Challenge state is represented by a `status` field rather than only by the presence or absence of `completed_at`.

| Status | Meaning | Set by |
|---|---|---|
| `active` | The user can work on the challenge and the container is expected to exist. | Challenge creation. |
| `completed` | The correct flag was submitted before expiry. | Flag submission route. |
| `destroyed` | The user manually ended the challenge. | Challenge delete route. |
| `expired` | The challenge exceeded its TTL. | Active challenge checks, launch cleanup, or expired flag submission handling. |

The `completed_at` column is retained as the timestamp at which the challenge left the active state. This allows the same timestamp field to record when a challenge was solved, destroyed, or expired. A partial unique index on `user_id` where `status = 'active'` enforces the rule that a user can only have one active challenge. This is a stronger protection than an application-only check because it still works if two launch requests race.

### 3.3.3 Challenge lifecycle

The lifecycle is deliberately simple from the user’s perspective but requires careful implementation because the database and infrastructure can become inconsistent if a stage fails.

![](vulnforge_diagrams_png/06_challenge_state_machine.png){width=85%}


The application checks challenge status before chat requests, flag submissions, and deletion requests. Chat is only interactive for the active challenge, while history pages allow past messages to be viewed in read-only mode. Correct flag submission marks the challenge as `completed`. Manual destruction marks it as `destroyed` immediately and then triggers container destruction asynchronously. Expiry is handled by application-side checks and by the host-side TTL reaper.

There is a deliberate separation between **logical state** and **infrastructure state**. The database may mark a challenge as destroyed before the destroy playbook has finished. Similarly, the Proxmox reaper may delete a container before the database is next checked. The implementation accepts this eventual consistency because the main requirement is to prevent the user from continuing to interact with stale challenges and to prevent indefinite resource use.

### 3.3.4 Launch pipeline

Challenge launch is the most complex workflow. It is exposed to the browser as a Server-Sent Events stream so that the UI can show progress across long-running operations.

![](vulnforge_diagrams_png/03_launch_sequence.png){width=85%}


The pipeline has two verification levels. Normal launches run **health-mode verification**, which executes health checks and flag-protection checks. This catches common failures such as a web server not starting, a generated file missing, or the flag being directly readable by the student. Full exploit verification is optional and controlled by `CHALLENGE_FULL_VERIFY_BEFORE_LAUNCH`. When enabled, the platform first deploys a disposable verifier container, injects the generated spec, runs exploit checks, destroys that verifier container, and only then deploys a fresh user-facing container. This avoids giving the user a container that has already been mutated by exploit checks.

The launch pipeline also performs cleanup on failure. If injection or verification fails after a container has been created, the container is destroyed and no database challenge is created. This is important because otherwise broken or unsafe generated challenges could accumulate on the Proxmox host.

### 3.3.5 Vulnerability generation design

![](vulnforge_diagrams_png/02_generation_pipeline.png){width=75%}

The LLM does not directly control the infrastructure. Instead, it produces a structured `VulnerabilitySpec` object that is treated as data. The schema includes:

- public challenge metadata: title, description, category, difficulty, hint, and attack vector;
- deployment instructions: apt packages, files, file owners, file modes, services, and setup commands;
- private learning metadata: solution summary;
- private verification metadata: health checks, flag-protection checks, and exploit checks.

The design uses several safeguards:

1. **Server-side flag generation.** The platform generates the flag as `FLAG{...}` using random bytes before calling the LLM. The model is instructed to embed this exact flag string somewhere that is only reachable through exploitation. This avoids relying on the model to invent a valid unique flag.
2. **Structured output.** The Zod schema is converted to JSON Schema and sent to OpenRouter as a structured response format. The response is still parsed and validated again server-side.
3. **Policy validation.** Schema validation checks structure, but policy validation checks semantic risks such as wrong category, wrong difficulty, missing flag, attempts to recreate the `student` user, non-absolute file paths, attempts to modify SSH configuration, invalid PHP PDO constants, and unsafe validation commands.
4. **Category-specific prompts.** Each vulnerability category has its own prompt module and variants. This prevents one large prompt file from becoming unmaintainable and gives each category clearer requirements.
5. **Diversity mechanisms.** A random category variant is selected for each launch. Web-based categories also receive a random application theme, such as a booking system or inventory portal. The user’s previous challenges in the same category are included as an exclusion list so the model is asked not to repeat previous scenarios.
6. **Model fallback.** The OpenRouter integration supports a primary model and fallback models. Retryable provider failures, empty responses, incomplete responses, rate limits, and temporary server errors can therefore be retried on another model in the chain.

This design gives the model freedom to invent scenarios while keeping the boundary to the rest of the system rigid. The infrastructure pipeline does not interpret natural language; it consumes a typed, validated specification.

![](vulnforge_diagrams_png/08_prompt_diversity.png){width=85%}

### 3.3.6 Verification design

![](vulnforge_diagrams_png/05_verification_system.png){width=75%}

Earlier versions of the design could check whether Ansible completed, but Ansible success alone does not prove that a generated challenge is usable. A web service might start but serve the default page, a setup command might leave the flag directly readable, or the intended exploit path might be broken. The updated design adds a verification contract to each generated vulnerability.

Each validation command contains a name, description, context, command string, timeout, expected exit code, expected stdout/stderr conditions, and a `must_recover_flag` field. The verification runner supports three contexts:

| Context | Meaning | Typical use |
|---|---|---|
| `container_root` | Run inside the LXC container as root through `pct exec`. | Service and file checks. |
| `container_student` | Run inside the LXC container as the `student` user. | Flag-protection checks from the learner’s perspective. |
| `external_http` | Run from the Proxmox host against the container IP, normally using `curl`. | Web application health and exploit checks. |

The policy validator treats validation commands as untrusted because they are generated by the model. It rejects host-control commands such as `pct`, `pvesh`, and `qm`; cloud metadata access; OpenRouter/API key references; SSH commands; and external HTTP checks that do not use `curl` against the generated target URL or IP. This is a pragmatic compromise: the model can describe how to validate the generated challenge, but the platform constrains where and how that validation may run.

### 3.3.7 Tutor design

The tutor is a challenge-aware assistant rather than a general chatbot. When a user sends a message, the chat route loads the authenticated user’s active challenge and checks that the supplied challenge ID matches it. It then builds a system prompt containing the challenge title, description, category, difficulty, hint, attack vector, and the private solution summary.

The tutor’s purpose is to provide progressive guidance. It should explain concepts and suggest methods, but it should not reveal the flag or provide the full exploit path in one response. The design uses two levels of protection. First, the tutor system prompt instructs the model not to reveal the flag, exact flag path, or full step-by-step solution. Secondly, the application checks the generated response before streaming it back. If the response contains a `FLAG{...}` pattern, the exact stored flag, or the full normalised solution summary, the response is replaced by a block message asking the user to request a smaller hint.

Messages are persisted after a complete assistant response. This supports continuity during an active challenge and enables read-only review in the history page after a challenge has ended.

### 3.3.8 Challenge history and learning review

The history design extends the platform beyond a single active challenge. The history API returns all challenges for the authenticated user, with message counts and status information. Active challenges link back to the dashboard, while completed, expired, or destroyed challenges can be viewed in a read-only detail page.

Completed challenges include the solution summary for learning review. Active challenges do not expose it. This creates a useful distinction between guidance during an attempt and explanation after a successful solve. It also makes the tutor conversation part of the learning record rather than a temporary front-end-only state.

## 3.4 Implementation

### 3.4.1 Technology stack and project structure

The application is implemented with Next.js, React, TypeScript, Drizzle ORM, SQLite, Zod, Pino, and Ansible. The main implementation areas are:

| Area | Key files |
|---|---|
| Authentication and sessions | `app/lib/auth.ts`, `app/api/auth/*`, `app/lib/db/repositories/session.ts` |
| User settings and SSH keys | `app/api/user/settings/route.ts`, `app/lib/ssh-key.ts`, `app/lib/db/repositories/user.ts` |
| Database schema and repositories | `app/lib/db/schema.ts`, `app/lib/db/index.ts`, `app/lib/db/repositories/*`, `drizzle/*.sql` |
| LLM generation | `app/lib/openrouter.ts`, `app/lib/openrouter-client.ts`, `app/lib/openrouter-model-fallback.ts` |
| Prompt definitions | `app/lib/prompts/system.ts`, `app/lib/prompts/categories.ts`, `app/lib/prompts/categories/*`, `app/lib/prompts/policy.ts` |
| Container orchestration | `app/lib/ansible-runner.ts`, `ansible/playbooks/deploy.yml`, `ansible/playbooks/destroy.yml`, `ansible/playbooks/roles/lxc_lifecycle/tasks/main.yml` |
| Vulnerability injection | `ansible/playbooks/inject-vulnerability.yml` |
| Verification | `app/lib/verification-runner.ts`, `ansible/playbooks/verify-vulnerability.yml` |
| Challenge APIs | `app/api/challenges/*` |
| Tutor chat | `app/api/chat/route.ts`, `app/api/chat/messages/route.ts`, `app/components/ChatPanel.tsx` |
| Evaluation support | `scripts/evaluate.ts`, `docs/evaluation-harness.md`, `docs/comprehensive-evaluation-runbook.md` |

Drizzle runs migrations automatically when the database connection is created. SQLite is configured with WAL mode and foreign keys enabled. WAL mode is useful because the application performs concurrent reads and writes during actions such as challenge launch, history loading, and chat persistence.

### 3.4.2 Authentication, settings, and user state

Authentication is implemented with email/password accounts. Passwords are hashed with bcrypt before storage. A successful login creates a session row and sets an HTTP-only cookie named `session_token`. The cookie is marked secure in production and has a seven-day expiry. API routes that require login call `requireAuth()`, which reads the cookie, checks that the session exists and has not expired, and loads the corresponding user.

The settings route allows the user to update their SSH public key and password. SSH key input is validated with a regular expression that accepts common public key types including `ssh-ed25519`, `ssh-rsa`, ECDSA keys, and security-key-backed Ed25519 keys. The launch route refuses to provision a challenge if the authenticated user has not stored an SSH public key. This moves key configuration failure to the start of the workflow, before any LLM call or container creation occurs.

### 3.4.3 Database repositories and status transitions

Repository modules wrap database access for users, sessions, challenges, and messages. This prevents API routes from containing raw SQL and gives the application a single place to enforce domain behaviour.

The challenge repository creates new challenges with `status = 'active'`, an expiry time one hour after creation, and no `completed_at` timestamp. It provides methods for finding the active challenge for a user, retrieving all challenges for history, finding prior challenges in a category for diversity prompting, finding expired active challenges, and transitioning a challenge into a terminal state.

The one-active-challenge rule is enforced in three layers:

1. The launch route checks for an existing active challenge at request start.
2. The launch route re-checks immediately before database insertion, after the slow generation and provisioning steps.
3. The database has a partial unique index on active challenges for each user.

The third layer is the most important because it handles race conditions that application checks cannot fully prevent. If two launch requests pass the first check, only one should be able to create an active challenge.

### 3.4.4 OpenRouter generation implementation

The generation entry point is `generateVulnerability()` in `app/lib/openrouter.ts`. It performs the following steps:

1. Generate a random server-side flag.
2. Build a category-specific prompt using the selected category, difficulty, flag, random variant, optional theme, and previous challenge history.
3. Convert the Zod vulnerability schema to JSON Schema.
4. Send the system prompt and user prompt to OpenRouter using chat completions with a structured response format.
5. Parse the returned text as JSON.
6. Validate the parsed object against `VulnerabilitySpecSchema`.
7. Run semantic policy validation.
8. Return the validated spec and server-generated flag.

The OpenRouter client is deliberately small. It handles `/models` for availability checks and `/chat/completions` for generation and tutor calls. A separate fallback helper builds a model chain from environment variables and built-in defaults, removes duplicates, and retries retryable failures. In the current source code, generation defaults are defined in `app/lib/openrouter.ts`; the README and older docs should be checked for consistency before final submission because some documentation still names earlier default models.

The implementation uses a higher token budget for generation because the generated JSON now includes application files and validation commands. Incomplete responses are treated as retryable because truncated JSON was a practical failure mode during development.

### 3.4.5 Prompt catalogue and diversity implementation

The prompt implementation evolved from a single prompt file into a catalogue of category modules. The current categories are:

- web server misconfiguration;
- privilege escalation;
- SQL injection;
- insecure file permissions;
- web application logic flaws.

Each category defines a user-facing label and description, a list of variants, whether it supports themes, and a prompt template. The prompt builder chooses a variant randomly and, for web categories, chooses an application theme randomly. This means two requests for the same category and difficulty should not always produce the same style of vulnerability.

The prompt builder also queries previous challenges for the user in the same category. It passes recent titles and solution summaries into the prompt as an exclusion list. This is not a mathematical guarantee of uniqueness, but it gives the LLM explicit context about what not to repeat. The evaluation harness can later measure diversity more concretely using generated titles, attack vectors, and file-set hashes.

### 3.4.6 Container deployment implementation

Container deployment is implemented through `deploy.yml` and the `lxc_lifecycle` role. The playbook creates an Ubuntu 24.04 unprivileged LXC container with one core, 1024 MB memory, an 8 GB root filesystem, DHCP networking on `vmbr0`, and the `vulnforge` tag. It then starts the container, creates the `student` user, injects the user’s SSH public key, waits for an IP address, and writes a deployment artefact containing the VMID, hostname, IP, and configuration details.

The TypeScript `deployContainer()` wrapper executes `ansible-playbook` using `execFile()` rather than shell interpolation. Extra variables such as the SSH public key are passed as JSON. This reduces shell-injection risk and avoids quoting problems with SSH keys. The wrapper enables Ansible’s JSON callback, then parses the task output to extract the VMID, hostname, and IP address from the debug message printed by the playbook.

A key implementation issue was SSH key injection. Earlier approaches that interpolated key content into shell commands were fragile because public keys can contain spaces and comments. The final playbook writes the key to a temporary file on the host, uses `pct push` to place it into the container as `authorized_keys`, and then sets ownership and permissions for `/home/student/.ssh`. This is more reliable than building an `echo 'key' > authorized_keys` command.

### 3.4.7 Vulnerability injection implementation

![](vulnforge_diagrams_png/04_file_injection.png){width=75%}

The injection boundary is the `VulnerabilitySpec`. The TypeScript runner writes the spec to a temporary JSON file and passes its path to `inject-vulnerability.yml`. The playbook then:

1. Loads the JSON spec.
2. Updates the apt cache inside the container.
3. Installs the requested packages.
4. Creates a temporary staging directory on the Proxmox host.
5. Writes each generated file into the staging directory.
6. Creates parent directories inside the container.
7. Copies files into the container with `pct push` using the specified modes.
8. Applies file ownership with `chown`.
9. Removes the staging directory.
10. Enables, starts, or restarts services.
11. Runs setup commands inside the container.
12. Performs a final service restart after setup commands.

The use of host-side staging and `pct push` is a critical implementation decision. Generated application files can contain quotes, dollar signs, shell metacharacters, PHP code, SQL, HTML, or JavaScript. Writing them through shell-escaped `echo` commands would be error-prone. By staging file content as files and pushing them into the container, the playbook avoids most shell escaping problems.

The final service restart is another implementation lesson. Some generated setup commands enable sites, create symlinks, modify service configuration, or initialise application state after the first service restart. Without restarting services again, a web server might continue serving its default configuration even though the generated files exist. The second restart ensures that post-setup changes are loaded.

Setup commands are executed as root inside the container. This is powerful and necessary for some scenarios, such as database initialisation or user/group changes, but it also makes the prompt and policy constraints important. The model is instructed to express basic file state through the `files` array where possible and to use setup commands sparingly.

### 3.4.8 Verification implementation

Verification is implemented by `verifyInjectedChallenge()` and `verify-vulnerability.yml`. The TypeScript runner selects checks based on mode:

- `health` mode runs `validation.health_checks` and `validation.flag_protection_checks`;
- `full` mode additionally runs `validation.exploit_checks`.

Before execution, the runner substitutes placeholders such as `{{TARGET_IP}}`, `{{TARGET_URL}}`, `{{VMID}}`, and `{{FLAG}}`. It writes the selected checks to a temporary JSON file and invokes the verification playbook. The playbook executes each command in the requested context and returns results through Ansible JSON output. The runner then evaluates exit codes, required stdout/stderr strings, forbidden stdout strings, and whether the flag was recovered when `must_recover_flag` is true.

Health-mode verification is used during normal user launches. If any health or flag-protection check fails, the launch route destroys the container and returns an error instead of inserting a challenge into the database. Full-mode verification is used by the evaluation harness and can optionally be used before launch on a disposable verifier container. This distinction is important because exploit checks can mutate the machine. For example, a privilege escalation exploit might add a root account, alter `/etc/passwd`, create a web shell, or change database state. Running that against the user’s final container would solve or damage the challenge before the user begins.

### 3.4.9 Challenge launch API implementation

The launch route is implemented in `app/api/challenges/launch/route.ts`. It is structured around a streaming response. Authentication, SSH key validation, active challenge checks, and request-body validation happen before the stream starts, so ordinary errors can be returned as JSON. Once the long-running work begins, progress and errors are sent as SSE events.

The route sends progress messages for generation, optional verification, deployment, injection, health verification, and finalisation. On success it returns the public challenge object and an SSH command. On failure it attempts to destroy any container that was already created. It also handles a subtle race condition: because generation and provisioning may take a long time, the route re-checks for an active challenge immediately before inserting the new challenge. If another request has already inserted one, the duplicate container is cleaned up.

The route also handles stale active challenges. If an existing active challenge has passed its expiry time, the launch route attempts to destroy the old container and marks the challenge as expired before continuing. This avoids blocking a user from launching a new challenge because a previous expired challenge was not cleaned up yet.

### 3.4.10 Flag submission and manual destruction

Flag submission is implemented in `app/api/challenges/submit-flag/route.ts`. The route validates the request body, checks that the challenge exists and belongs to the authenticated user, verifies that it is still active, checks expiry, and compares the submitted flag with the stored flag. If the flag is correct, the challenge is marked as `completed`.

The delete route in `app/api/challenges/[id]/route.ts` allows a user to end an active challenge manually. It marks the challenge as `destroyed` immediately and then invokes container destruction asynchronously. This makes the UI responsive even if the destroy playbook takes time or fails. The TTL reaper remains a safety net for infrastructure cleanup.

One implementation limitation is that successful flag submission updates the database state but does not immediately destroy the container. The container should still be removed by the host-side TTL reaper, but immediate destroy-on-completion would be a useful resource-saving improvement.

### 3.4.11 Tutor and chat persistence implementation

The chat API accepts a message and challenge ID. It requires authentication, checks that the user has an active challenge, and checks that the request’s challenge ID matches that active challenge. This prevents a user from asking the tutor about another user’s challenge or about an inactive challenge through the interactive endpoint.

The route loads persisted message history, appends the new user message, and sends the conversation to OpenRouter with a system prompt containing the private challenge context. The assistant response is generated, checked for forbidden leakage, streamed back to the client as SSE token events, and then persisted together with the user message. Persistence happens only after a successful response so that failed streams do not create misleading history records.

The UI component `ChatPanel` loads previous messages on mount, streams new responses into an assistant message, and switches to read-only mode on history pages. The message repository inserts user/assistant message pairs inside a transaction, with a small timestamp offset to preserve ordering.

### 3.4.12 Challenge history implementation

Challenge history is implemented with a history API, a list page, a detail API, a read-only challenge detail component, and read-only chat display. The list page shows each challenge’s title, category, difficulty, status, creation time, and message count. Active challenges redirect back to the dashboard. Non-active challenges open a detail view.

The detail API returns the solution summary only for completed challenges. This supports post-solve learning while keeping the active-challenge experience constrained. Expired and destroyed challenges can still show their metadata and tutor conversation, but they do not expose the solution summary by default.

### 3.4.13 Logging implementation

The project uses a Pino-backed logging facade in `app/lib/logger.ts`. Code emits structured event names such as `challenge.launch.start`, `vulnerability.generation.success`, `verification.finish`, `container.deploy.success`, `flag.submit.checked`, and `chat.messages.persisted`. This is more useful than unstructured console output because launch failures can be traced by following event names through the pipeline.

The logging facade sanitises sensitive fields recursively. Field names containing terms such as `secret`, `password`, `token`, `key`, and `flag` are redacted before being passed to Pino. This is important because the system handles API keys, SSH keys, flags, model outputs, and generated exploit data.

### 3.4.14 Evaluation harness implementation

Although evaluation results belong in the Evaluation section, the updated repository now includes implementation support for collecting those results. The script `scripts/evaluate.ts` can be run with four modes:

| Mode | Purpose |
|---|---|
| `static` | Generate and validate specs without Proxmox. |
| `deploy` | Deploy and destroy a blank container to test orchestration. |
| `inject` | Generate, deploy, inject, run health/flag-protection verification, and destroy. |
| `full` | Generate, deploy, inject, run health, flag-protection, and exploit verification, then destroy. |

The harness writes `results.json`, `results.csv`, `summary.md`, and private `generated-specs/*.json` artefacts. These outputs are designed to support later evaluation of generation reliability, deployment reliability, injection reliability, verification pass rates, exploit recovery, cleanup, timing, and diversity. Generated specs include flags and exploit details, so they should be treated as sensitive and not published with the user-facing system.

The harness does not yet test the browser UI or tutor quality. Those remain evaluation limitations or future work unless separate tests are added.

## 3.5 Design evolution and implementation problems

The final design evolved significantly during implementation. The following changes are the most important to discuss because they show how practical constraints shaped the system.

### 3.5.1 From direct LLM text to structured specifications

A natural first approach would be to ask the model to generate files or commands directly and then execute them. This is unsafe and hard to debug. The implemented approach instead forces the model to return a structured specification. Zod validation, JSON parsing, and policy validation create a contract between the LLM and the rest of the platform. This made it possible to add later stages such as injection and verification without changing the whole architecture.

### 3.5.2 From LLM-generated flags to server-generated flags

Earlier design notes describe a model-generated flag and flag location. The final system generates the flag server-side and prompts the model to embed that exact value. This gives the platform a reliable flag format and a known answer for the flag checker. The trade-off is that the platform must verify that the model actually embedded the flag correctly and did not expose it directly. The added validation and optional full verification pipeline address this weakness.

### 3.5.3 From root access to a non-root student model

If students connected as root, privilege escalation and file-permission challenges would be meaningless because the user could already read most sensitive files. The container lifecycle role therefore creates a `student` user and injects the user’s SSH key into that account. The system prompt also tells the LLM that the `student` user already exists and must not be recreated. This fixed a practical failure mode where generated setup commands attempted to run `useradd student` and then failed because the account had already been created by the platform.

### 3.5.4 From synchronous launch to streamed progress

Container provisioning and LLM generation are too slow and unpredictable for a simple request/response user experience. The launch route now streams progress using Server-Sent Events. This does not make the backend work faster, but it makes long launches understandable to the user and helps distinguish between generation, deployment, injection, verification, and finalisation failures.

### 3.5.5 From Ansible success to challenge verification

Ansible can report success even when the resulting challenge is not educationally valid. For example, all files may be copied but the web server may still serve the default page, or the flag may be readable without exploitation. The verification pipeline was added to close this gap. Normal launches now require non-destructive health and flag-protection checks. Full exploit checks are available through disposable containers and the evaluation harness.

### 3.5.6 From in-memory tutor state to persisted learning history

An in-memory chat is simple but loses the learning process when the page refreshes or the challenge ends. The final system stores messages in a `messages` table linked to the challenge. This supports continuity during the attempt and review after the attempt. It also makes the tutor part of the user’s learning artefact rather than a temporary UI feature.

### 3.5.7 From application-only active challenge checks to database enforcement

The one-active-challenge rule started as an application check, but application checks alone can race. Two requests can both see no active challenge, both spend time generating and deploying containers, and both attempt to insert. The final design adds a partial unique database index and a re-check before insertion. This does not eliminate all wasted work in a race, but it prevents the database from ending up with two active challenges for the same user.

### 3.5.8 From ad-hoc debugging to structured logging

The launch process spans the web server, LLM provider, Ansible, Proxmox, container commands, and database writes. Failures can therefore occur at many layers. Structured logging was added so that each stage emits consistent event names and relevant metadata while redacting sensitive values. This makes evaluation and debugging more systematic.

## 3.6 Summary

The final implementation satisfies the core aim of the project: it can generate an LLM-authored vulnerability specification, provision an isolated LXC container, inject the generated artefacts, verify the challenge’s basic health and flag protection, expose the environment to the user through SSH, support guided tutor interaction, and record the attempt in challenge history. The most important design decision is the use of a structured specification as the boundary between the LLM and the infrastructure. This boundary makes the system extensible because new categories, verification checks, and evaluation modes can be added without giving the model direct control over the host.

The main remaining limitations are also clear. Full exploit verification is optional and slower because it requires a disposable verifier container. The evaluation harness does not yet test the browser UI or tutor quality. The deployment networking model is assumed rather than fully automated in the application. Finally, a production-grade deployment should further harden container credentials and consider immediate cleanup after successful completion. These limitations do not undermine the core prototype, but they should be acknowledged in the Evaluation and Reflection sections.
