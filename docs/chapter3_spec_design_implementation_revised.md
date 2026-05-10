# Chapter 3: Specification, Design and Implementation

## 3.1 Introduction

VulnForge is an educational cybersecurity training platform that creates short-lived vulnerable environments for Capture the Flag style exercises. A learner signs in to a web dashboard, stores an SSH public key, selects a vulnerability category and difficulty, launches a challenge, connects to the generated environment as a low-privilege Linux user, exploits the vulnerability, and submits a flag through the platform. Unlike a conventional static CTF platform, the challenge scenario is generated dynamically by a large language model (LLM) and then deployed into a fresh LXC container.

The project therefore has three connected technical roles. First, it is a web application that provides authentication, account settings, a dashboard, active challenge state, flag submission, tutor chat, and challenge history. Secondly, it is an infrastructure orchestration system that creates, configures, verifies, and destroys Proxmox LXC containers. Thirdly, it is a constrained generative-AI pipeline that converts a user's category and difficulty selection into a structured vulnerability specification that can be validated and injected automatically.

This chapter is organised around the distinction between specification, design, and implementation. The specification defines what the system is required to do and the constraints under which it operates. The design explains the architecture and the main viewpoints needed to understand the solution: static architecture, data model, challenge lifecycle, generation pipeline, verification model, tutor behaviour, and history workflow. The implementation section then describes how the design was realised in the codebase, focusing on the parts that are critical to the system or that required notable engineering decisions.

## 3.2 Specification

### 3.2.1 Scope and deployment assumptions

The system is designed for a controlled educational lab setting rather than a public Internet-scale product. A user interacts with VulnForge through a web dashboard and connects to the generated challenge environment through SSH. Each challenge environment is an LXC container hosted on a Proxmox VE hypervisor. The container is intended to be ephemeral: it exists for one challenge attempt and is later removed because the challenge expires, is completed, is manually ended, or is cleaned up by host-side maintenance.

The main operating assumptions are:

- users authenticate through the VulnForge web application before launching challenges;
- each user stores an SSH public key before a challenge can be launched;
- learners connect to the challenge as a non-root Linux user called `student`;
- the `student` user has no ordinary administrative access, so any privilege gain should be caused by the generated vulnerability;
- a user may have at most one active challenge at a time;
- the correct flag and solution summary are stored server-side and are not exposed to the browser while the challenge is active;
- the generated container is reachable through the intended lab network path, but the web application does not implement a full public VPN or network onboarding product;
- evaluation results are discussed separately in the Evaluation chapter; this chapter describes the final system and the design decisions behind it.

This scope is important because it explains what VulnForge does not attempt to solve. It does not implement payment, public cloud scaling, browser-based terminals, end-user Proxmox administration, or a complete managed VPN. The aim is to demonstrate controlled vulnerability generation, isolated deployment, basic safety verification, guided assistance, flag submission, and cleanup for short-lived vulnerable machines.

### 3.2.2 Functional requirements

| ID | Requirement | Final design response |
|---|---|---|
| FR1 | Users must be able to sign up, log in, log out, and remain authenticated across page refreshes. | The application uses email/password authentication, password hashing, server-side session records, and an HTTP-only session cookie. |
| FR2 | Users must be able to store and update an SSH public key. | The settings workflow validates public key format and stores the key against the authenticated user. |
| FR3 | Users must be able to select a vulnerability category and difficulty. | The dashboard exposes challenge categories and three difficulty levels: beginner, intermediate, and advanced. |
| FR4 | The system must dynamically generate a vulnerability scenario. | The generation module builds a category-specific prompt, requests structured JSON from OpenRouter, validates the result with Zod, and then applies policy validation. |
| FR5 | The system must provision a fresh vulnerable environment. | The launch route invokes Ansible to create an unprivileged LXC container through Proxmox. |
| FR6 | The system must inject user access credentials into the environment. | The LXC lifecycle role creates the `student` account and pushes the user's SSH public key to `/home/student/.ssh/authorized_keys`. |
| FR7 | The system must inject generated vulnerable content. | The injection playbook installs required packages, writes generated files, applies ownership and permission modes, executes setup commands, and restarts services. |
| FR8 | The system must verify basic challenge health before the user sees it. | After injection, the launch pipeline runs generated health and flag-protection checks through the verification runner. |
| FR9 | The user must receive enough information to access the challenge. | The successful launch response returns the public challenge object, container IP address, SSH user, and a ready-to-copy `ssh student@<ip>` command. |
| FR10 | The user must be able to submit a flag and receive feedback. | The flag submission route checks ownership, status, expiry, and flag equality, then marks a correct active challenge as completed. |
| FR11 | The system must prevent indefinite resource use. | Challenges have an application-level expiry time and are also intended to be covered by host-side cleanup of VulnForge containers. |
| FR12 | The user must be able to end a challenge manually. | The challenge API marks the challenge as destroyed and triggers container deletion. |
| FR13 | The AI tutor must provide challenge-aware guidance without simply giving away the answer. | The chat route builds a tutor prompt from challenge metadata and the private solution summary, then blocks responses that leak flags or the complete solution. |
| FR14 | Users should be able to review previous attempts. | History pages show previous challenges, statuses, message counts, persisted tutor conversations, and solution summaries for completed challenges. |
| FR15 | The implementation should support later evaluation of generation and orchestration reliability. | The repository includes an evaluation harness with static, deploy, inject, and full verification modes, producing structured result artefacts. |

### 3.2.3 Non-functional requirements and constraints

| Constraint | Design implication |
|---|---|
| Containment | Generated vulnerabilities should remain inside the intended container. The system uses unprivileged LXC containers, a non-root learner account, prompt constraints forbidding host-level vulnerabilities, and application boundaries that prevent learners from directly invoking Proxmox or Ansible. |
| Ephemerality | Vulnerable machines should be short-lived. The application records an expiry timestamp for each challenge and can mark stale active challenges as expired. Host-side cleanup is treated as a safety net rather than the only cleanup mechanism. |
| Reliability | Challenge launch involves several failure-prone stages: LLM generation, optional full verification, container deployment, vulnerability injection, health verification, and database insertion. The design therefore needs progress feedback, useful error reporting, and cleanup when a stage fails after a container has already been created. |
| LLM safety | The model is untrusted. It may produce malformed JSON, unsafe commands, repeated scenarios, missing packages, broken applications, or flags that are directly readable. The system uses schema validation, policy validation, fallback models, bounded verification contexts, health checks, flag-protection checks, and optional full exploit verification. |
| Usability | Learners should not need to understand Proxmox, Ansible, LXC, or the generation pipeline. The UI reduces the workflow to choosing a category and difficulty, observing progress, copying an SSH command, asking for hints, and submitting a flag. |
| Maintainability | The web UI, database schema, prompt catalogue, infrastructure automation, verification runner, and evaluation scripts change for different reasons. The implementation therefore separates concerns across TypeScript modules, Drizzle repositories, Zod schemas, prompt category modules, API routes, and Ansible playbooks. |
| Network access | The application returns a direct container IP address and SSH command. It assumes a lab network path to the container subnet. Managed VPN onboarding, reverse proxying, or per-user network registration are outside the current application scope unless added later. |
| Prototype hardening | The prototype demonstrates the architecture, but a production deployment would need stricter container credential handling, stronger network controls, deeper isolation, and immediate cleanup after successful completion. |

## 3.3 Design

### 3.3.1 High-level architecture

The final architecture uses a full-stack Next.js application as the central control plane. It is connected to SQLite for persistent state, OpenRouter for LLM calls, Ansible for automation, and Proxmox VE for container lifecycle management.

> **Figure 3.1 to insert: System architecture.** Suggested contents: browser client; Next.js application; SQLite database; OpenRouter; Ansible runner; Proxmox host; generated LXC container; arrows for generation, deployment, injection, verification, SSH access, flag submission, and tutor chat.

The web application is the central authority. It validates user input, checks authentication, stores challenge state, invokes the LLM, launches playbooks, verifies generated challenges, and decides which data may be returned to the client. Learners do not receive Proxmox credentials, Ansible inventory data, API tokens, flags, generated validation commands, or the private solution summary while a challenge is active.

Ansible is used as the infrastructure automation layer rather than embedding Proxmox operations directly into the web application. This keeps the TypeScript code focused on workflow orchestration and leaves container operations visible as playbooks. The trade-off is that the application must parse Ansible output, handle subprocess failures, and clean up containers when playbooks fail part-way through. This trade-off is acceptable because the project depends on repeatable infrastructure operations, and playbooks make host-level actions easier to inspect and debug.

Proxmox LXC containers were chosen because they are lightweight and quicker to create than full virtual machines. This matters because challenge launch already includes LLM generation, package installation, and verification. The limitation is that LXC containers are not as strong an isolation boundary as full VMs because they share the host kernel. For this prototype, the risk is reduced through unprivileged containers, a non-root learner account, short TTLs, restricted generation policies, and the assumption of a controlled lab environment.

### 3.3.2 Data model

The database contains four main entities: users, sessions, challenges, and messages.

> **Figure 3.2 to insert: Database schema.** Suggested contents: `users`, `sessions`, `challenges`, and `messages`; foreign keys from sessions and challenges to users; foreign key from messages to challenges; highlight private `flag` and `solution_summary` fields.

The `challenges` table is the central domain object. It connects a database record to generated infrastructure by storing the Proxmox VMID, IP address, and hostname. It also stores user-facing challenge metadata such as title, description, category, difficulty, hint, and attack vector. The `flag` and `solution_summary` fields are private fields used by the flag checker and tutor. Repository methods expose a public challenge object that omits these fields while the challenge is active.

Challenge state is represented by a `status` field rather than only by the presence or absence of a completion timestamp.

| Status | Meaning | Set by |
|---|---|---|
| `active` | The user can work on the challenge and the container is expected to exist. | Challenge creation. |
| `completed` | The correct flag was submitted before expiry. | Flag submission route. |
| `destroyed` | The user manually ended the challenge. | Challenge delete route. |
| `expired` | The challenge exceeded its TTL. | Active challenge checks, launch cleanup, or expired flag submission handling. |

A partial unique index on `challenges(user_id)` where `status = 'active'` enforces the rule that a user can only have one active challenge. This is stronger than an application-only check because it still works if two launch requests race.

### 3.3.3 Challenge lifecycle

The challenge lifecycle is deliberately simple from the learner's perspective but requires careful implementation because database state and infrastructure state can become inconsistent.

> **Figure 3.3 to insert: Challenge lifecycle.** Suggested contents: `active` as the central state; transitions to `completed`, `destroyed`, and `expired`; triggers from flag submission, manual deletion, and expiry checks; separate note that infrastructure deletion may occur asynchronously.

The application checks challenge status before chat requests, flag submissions, and deletion requests. Chat is interactive only for an active challenge, while history pages allow previous messages to be viewed in read-only mode. Correct flag submission marks the challenge as completed. Manual deletion marks it as destroyed immediately and then triggers container deletion. Expiry is handled by application-side checks and host-side cleanup.

There is a deliberate separation between logical state and infrastructure state. The database may mark a challenge as destroyed before the Ansible destroy playbook has finished. Similarly, a host-side cleanup process may delete a container before the database is next checked. The implementation accepts this eventual consistency because the main requirement is to stop users from interacting with stale challenges and to prevent indefinite resource use. The design favours safe terminal state transitions and independent cleanup over a more complex distributed transaction between SQLite and Proxmox.

### 3.3.4 Launch pipeline

Challenge launch is the most complex workflow in the platform. It is exposed to the browser as a Server-Sent Events stream so that the UI can show progress during long-running operations.

> **Figure 3.4 to insert: Launch pipeline.** Suggested contents: authenticate; validate SSH key; check existing active challenge; generate specification; optional disposable full verification; deploy user container; inject vulnerability; run health verification; re-check active challenge race; insert database row; return public challenge.

The normal launch path is:

1. authenticate the user and validate request input;
2. reject the request if the user has no SSH public key;
3. check for an existing active challenge, expiring stale ones where appropriate;
4. generate a `VulnerabilitySpec` using the selected category, difficulty, server-generated flag, and recent challenge history;
5. optionally run full exploit verification on a disposable verifier container;
6. deploy a fresh user-facing LXC container;
7. inject the generated files, packages, services, and setup commands;
8. run non-destructive health and flag-protection verification;
9. re-check that the user still has no active challenge;
10. insert the challenge into the database and return the public challenge object.

The pipeline has two verification levels. Normal launches run health-mode verification, which executes health checks and flag-protection checks. This catches common failures such as a web server not starting, a generated file missing, or the flag being directly readable by the learner. Full exploit verification can be enabled through configuration. When enabled, the platform deploys a disposable verifier container, injects the generated specification, runs exploit checks, destroys the verifier container, and only then deploys a clean user-facing container.

This split is a design compromise. Full exploit verification gives stronger evidence that the generated challenge is solvable, but it is slower and can mutate the machine. For example, a privilege escalation exploit might change permissions, add files, or alter service state. Running such checks on the user's final container could partially solve or damage the challenge before the user begins. Health-mode verification is therefore used for normal launches, while full verification is reserved for evaluation or deployments where the additional delay is acceptable.

The launch pipeline also performs cleanup on failure. If injection or verification fails after a container has been created, the container is destroyed and no database challenge is created. This prevents broken or unsafe generated challenges from accumulating on the Proxmox host.

### 3.3.5 Vulnerability generation design

The LLM does not directly control the infrastructure. Instead, it produces a structured `VulnerabilitySpec` object that is treated as data.

> **Figure 3.5 to insert: Generation and policy pipeline.** Suggested contents: category/difficulty input; server-generated flag; category prompt builder; OpenRouter structured JSON response; Zod validation; policy validation; accepted specification or retry/failure.

The specification includes:

- public challenge metadata: title, description, category, difficulty, hint, and attack vector;
- deployment instructions: apt packages, generated files, file owners, file modes, services, and setup commands;
- private learning metadata: solution summary;
- private verification metadata: health checks, flag-protection checks, and exploit checks.

An abbreviated version of the schema boundary is:

```ts
VulnerabilitySpec {
  title: string
  description: string
  category: string
  difficulty: "beginner" | "intermediate" | "advanced"
  hint: string
  apt_packages: AptPackage[]
  files: FileEntry[]
  services: Service[]
  setup_commands: string[]
  solution_summary: string
  attack_vector: string
  validation: ValidationSpec
}
```

The choice to use structured output is central to the design. A free-text response from the LLM would be difficult to validate and dangerous to execute. A typed specification creates a contract between the model and the infrastructure pipeline. The rest of the system consumes files, packages, services, setup commands, and validation checks as structured fields rather than interpreting arbitrary natural language.

The generation design uses several safeguards.

1. **Server-side flag generation.** The platform generates a random `FLAG{...}` value before calling the LLM. The model is instructed to embed this exact value somewhere reachable only through exploitation. This avoids relying on the model to invent a unique valid flag.

2. **Structured output.** The Zod vulnerability schema is converted to JSON Schema and sent to OpenRouter as a structured response format. The returned text is still parsed as JSON and validated again server-side.

3. **Policy validation.** Schema validation checks shape, but policy validation checks semantic risks such as wrong category, wrong difficulty, missing flag, attempts to recreate the `student` user, attempts to modify SSH configuration, unsafe paths, malformed web application content, and unsafe validation commands.

4. **Category-specific prompts.** Each vulnerability category has its own prompt module and variants. This avoids one large unmaintainable prompt file and gives each category clearer constraints.

5. **Diversity mechanisms.** The prompt builder selects random variants and, for web categories, random application themes. It also passes previous challenges in the same category into the prompt as an exclusion list so that the model is instructed not to repeat previous scenarios.

6. **Model fallback and retries.** The OpenRouter integration can retry generation with fallback models when provider errors, empty responses, truncated responses, rate limits, or temporary failures occur.

### 3.3.6 Verification design

Earlier versions of the design could check whether Ansible completed, but Ansible success alone does not prove that a generated challenge is usable. A web service may start but serve the wrong page, generated files may exist but be inaccessible, or the flag may be readable without exploitation. Verification is therefore part of the vulnerability specification.

> **Figure 3.6 to insert: Verification contexts and checks.** Suggested contents: health checks, flag-protection checks, exploit checks; contexts `container_root`, `container_student`, and `external_http`; result evaluation against exit code, stdout/stderr expectations, and flag recovery.

Each validation command contains a name, description, execution context, command string, timeout, expected exit code, stdout/stderr expectations, and a `must_recover_flag` field. The runner supports three contexts.

| Context | Meaning | Typical use |
|---|---|---|
| `container_root` | Run inside the LXC container as root through `pct exec`. | Service checks, file checks, package checks. |
| `container_student` | Run inside the LXC container as the `student` user. | Flag-protection checks from the learner's perspective. |
| `external_http` | Run from the Proxmox host against the container IP, normally using `curl`. | Web application health checks and exploit checks. |

Generated validation commands are treated as untrusted because they are also model output. The policy validator rejects host-control commands such as `pct`, `pvesh`, and `qm`, cloud metadata access, OpenRouter/API key references, SSH commands, and external HTTP checks that do not target the generated target URL or IP. This is a pragmatic compromise: the model can describe how the challenge should be validated, but the platform constrains where and how those checks can run.

### 3.3.7 Tutor design

The tutor is a challenge-aware assistant rather than a general chatbot. When a user sends a message, the chat route loads the authenticated user's active challenge and checks that the supplied challenge ID matches it. It then builds a system prompt containing the challenge title, description, category, difficulty, hint, attack vector, and private solution summary.

> **Figure 3.7 to insert: Tutor chat flow.** Suggested contents: user message; active challenge check; private challenge context; OpenRouter call; leakage filter; token streaming; message persistence.

The tutor's purpose is to provide progressive guidance. It should explain concepts and suggest methods, but it should not reveal the flag or provide the full exploit path in one response. The design uses two layers of protection. First, the tutor system prompt instructs the model not to reveal the flag, the exact flag path, or the complete step-by-step solution. Secondly, the application checks the generated response before streaming it back. If the response contains a `FLAG{...}` pattern, the exact stored flag, or the full normalised solution summary, the response is replaced with a block message asking the user to request a smaller hint.

Messages are persisted after a complete assistant response. This supports continuity during an active challenge and enables read-only review in the history page after the challenge has ended.

### 3.3.8 Challenge history and learning review

The history design extends the platform beyond a single active challenge. The history API returns previous challenges for the authenticated user, with message counts and status information. Active challenges link back to the dashboard. Completed, expired, or destroyed challenges can be viewed in a read-only detail page.

Completed challenges include the solution summary for learning review. Active challenges do not expose it. This creates a distinction between guidance during an attempt and explanation after a successful solve. It also makes the tutor conversation part of the learning record rather than a temporary front-end-only state.

## 3.4 Implementation

### 3.4.1 Technology stack and project structure

The application is implemented with Next.js, React, TypeScript, Drizzle ORM, SQLite, Zod, Pino, Ansible, and Proxmox VE. The main implementation areas are summarised below.

| Area | Key implementation files |
|---|---|
| Authentication and sessions | `app/lib/auth.ts`, `app/api/auth/*`, session repository. |
| User settings and SSH keys | `app/api/user/settings/route.ts`, `app/lib/ssh-key.ts`. |
| Database and repositories | `app/lib/db/schema.ts`, `app/lib/db/repositories/*`, `drizzle/*.sql`. |
| LLM generation and prompts | `app/lib/openrouter.ts`, OpenRouter client and fallback modules, prompt category modules. |
| Container orchestration | `app/lib/ansible-runner.ts`, `deploy.yml`, `destroy.yml`, LXC lifecycle role. |
| Vulnerability injection and verification | `inject-vulnerability.yml`, `verify-vulnerability.yml`, `app/lib/verification-runner.ts`. |
| Challenge APIs and tutor | `app/api/challenges/*`, `app/api/chat/route.ts`, `ChatPanel.tsx`. |
| Evaluation support | `scripts/evaluate.ts` and generated result artefacts. |

Drizzle runs migrations when the database connection is created. SQLite is configured for the prototype because it is simple to run locally and sufficient for a single application instance. The repository pattern keeps raw database access out of most API routes and gives the application a single place to enforce domain behaviour such as active challenge lookup, history retrieval, and terminal status transitions.

### 3.4.2 Authentication, settings, and user state

Authentication is implemented with email/password accounts. Passwords are hashed before storage. A successful login creates a server-side session row and sets an HTTP-only cookie. API routes that require login call `requireAuth()`, which reads the cookie, checks that the session exists and has not expired, and loads the corresponding user.

The settings route allows the user to update their SSH public key and password. SSH key input is validated before storage. The launch route refuses to provision a challenge if the authenticated user has not stored an SSH public key. This moves key configuration failure to the start of the workflow, before any LLM call or container creation occurs.

### 3.4.3 Database repositories and status transitions

Repository modules wrap database access for users, sessions, challenges, and messages. The challenge repository creates new challenges with `status = 'active'`, an expiry time one hour after creation, and no completion timestamp. It also provides methods for finding the active challenge for a user, retrieving all challenges for history, finding previous challenges in a category for diversity prompting, finding expired active challenges, and transitioning a challenge into a terminal state.

The one-active-challenge rule is enforced in three layers:

1. the launch route checks for an existing active challenge at request start;
2. the launch route re-checks immediately before database insertion, after the slow generation and provisioning steps;
3. the database has a partial unique index on active challenges for each user.

The database index is the strongest layer because it handles race conditions that application checks cannot fully prevent. If two launch requests both pass the initial check, only one should be able to insert an active challenge.

### 3.4.4 OpenRouter generation implementation

The generation entry point is `generateVulnerability()` in `app/lib/openrouter.ts`. It performs the following steps:

1. generate a random server-side flag;
2. build a category-specific prompt using the selected category, difficulty, flag, random variant, optional theme, and previous challenge history;
3. convert the Zod vulnerability schema to JSON Schema;
4. call OpenRouter using chat completions with a structured response format;
5. parse the returned text as JSON;
6. validate the parsed object against `VulnerabilitySpecSchema`;
7. run semantic policy validation;
8. return the validated specification and server-generated flag.

The OpenRouter client is deliberately small. It handles model listing and chat completions, while a separate fallback helper builds a model chain from environment variables and defaults. The generator retries attempts when output is malformed, fails schema validation, fails policy validation, or is truncated. This retry behaviour is important because large JSON specifications containing files and validation commands can exceed the behaviour expected from a simple single-shot LLM prompt.

### 3.4.5 Prompt catalogue and diversity implementation

The prompt implementation evolved from a single prompt file into a catalogue of category modules. The current categories are web server misconfiguration, privilege escalation, SQL injection, insecure file permissions, and web application logic flaws. Each category defines a user-facing label and description, a list of variants, whether it supports application themes, and a prompt template.

The prompt builder chooses a variant randomly and, for web-based categories, chooses an application theme randomly. It also queries previous challenges for the user in the same category and passes recent titles and solution summaries into the prompt as an exclusion list. This is not a mathematical guarantee of uniqueness, but it gives the model explicit context about what not to repeat. The evaluation harness can measure diversity more concretely using generated titles, attack vectors, file paths, package lists, and file-set hashes.

### 3.4.6 Container deployment implementation

Container deployment is implemented through `deploy.yml` and the LXC lifecycle role. The playbook creates an unprivileged LXC container, starts it, creates the `student` user, injects the user's SSH public key, waits for a DHCP IP address, and writes a deployment artefact containing the VMID, hostname, IP address, and configuration details.

The TypeScript wrapper executes `ansible-playbook` using `execFile()` rather than shell interpolation. Extra variables such as the SSH public key are passed as JSON. This reduces shell-injection risk and avoids quoting problems with SSH keys. The wrapper enables Ansible's JSON output and parses a debug message to extract the VMID, hostname, and IP address.

A key implementation issue was SSH key injection. Public keys contain spaces and can include comments, so interpolating key content into shell commands is fragile. The final lifecycle role writes the key to a temporary file on the host, uses `pct push` to place it into the container as `authorized_keys`, and then sets ownership and permissions for `/home/student/.ssh`.

### 3.4.7 Vulnerability injection implementation

The injection boundary is the `VulnerabilitySpec`. The TypeScript runner writes the validated spec to a temporary JSON file and passes its path to `inject-vulnerability.yml`. The playbook then:

1. validates required inputs such as VMID and spec file path;
2. loads the JSON specification;
3. updates the apt cache inside the container;
4. installs requested packages;
5. creates a temporary staging directory on the Proxmox host;
6. writes each generated file into the staging directory;
7. creates parent directories inside the container;
8. copies files into the container with `pct push`;
9. applies file ownership and permission modes;
10. removes the staging directory;
11. starts, enables, or restarts requested services;
12. runs setup commands inside the container;
13. performs a final service restart after setup commands.

The use of host-side staging and `pct push` is a critical implementation decision. Generated application files can contain quotes, dollar signs, shell metacharacters, PHP, SQL, HTML, or JavaScript. Writing them through shell-escaped `echo` commands would be error-prone. By staging file content as files and pushing them into the container, the playbook avoids most shell escaping problems.

The final service restart is another implementation lesson. Some generated setup commands enable sites, create symlinks, modify service configuration, or initialise application state after the first service management step. Without restarting services again, a web server might continue serving its default configuration even though the generated files exist. The second restart ensures that post-setup changes are loaded.

Setup commands are executed as root inside the container. This is powerful and sometimes necessary for database initialisation, user/group changes, or service configuration. It also makes prompt and policy constraints important. The model is instructed to express ordinary file state through the `files` array where possible and to use setup commands only where file injection is insufficient.

### 3.4.8 Verification implementation

Verification is implemented by `verifyInjectedChallenge()` and `verify-vulnerability.yml`. The TypeScript runner selects checks based on mode:

- health mode runs `validation.health_checks` and `validation.flag_protection_checks`;
- full mode also runs `validation.exploit_checks`.

Before execution, the runner substitutes placeholders such as `{{TARGET_IP}}`, `{{TARGET_URL}}`, `{{VMID}}`, and `{{FLAG}}`. It writes the selected checks to a temporary JSON file and invokes the verification playbook. The playbook executes each command in the requested context and returns command results through Ansible output. The runner then evaluates exit codes, required stdout/stderr strings, forbidden stdout strings, and whether the flag was recovered when `must_recover_flag` is true.

Health-mode verification is used during normal user launches. If any health or flag-protection check fails, the launch route destroys the container and returns an error instead of inserting a challenge into the database. Full-mode verification is used by the evaluation harness and can optionally be used before launch on a disposable verifier container. This distinction matters because exploit checks can mutate the machine. Running them against the user's final container could solve or damage the challenge before the user begins.

### 3.4.9 Challenge launch API implementation

The launch route is implemented in `app/api/challenges/launch/route.ts`. It is structured around a streaming response. Authentication, SSH key validation, active challenge checks, and request-body validation happen before the stream starts, so ordinary errors can be returned as JSON. Once the long-running work begins, progress and errors are sent as SSE events.

The route sends progress messages for generation, optional full verification, deployment, injection, health verification, and finalisation. On success it returns the public challenge object and SSH command. On failure it attempts to destroy any container that has already been created. It also handles stale active challenges: if an existing active challenge has passed its expiry time, the launch route attempts to destroy the old container and marks the challenge as expired before continuing.

The route handles a subtle race condition. Generation and provisioning can take long enough for another request to create an active challenge in the meantime. The route therefore re-checks for an active challenge immediately before insertion. If a conflict is found, the duplicate container is destroyed and no second active challenge is created. The database partial unique index remains the final safeguard.

### 3.4.10 Flag submission and manual destruction

Flag submission is implemented in `app/api/challenges/submit-flag/route.ts`. The route validates the request body, checks that the challenge exists and belongs to the authenticated user, verifies that it is still active, checks expiry, and compares the submitted flag with the stored flag. If the flag is correct, the challenge is marked as completed.

Manual destruction is implemented in `app/api/challenges/[id]/route.ts`. The delete route checks authentication, ownership, and active status. It marks the challenge as destroyed immediately so that the UI can update without waiting for Ansible, then triggers container destruction. The host-side cleanup process remains a safety net.

One current limitation is that successful flag submission updates the database state but does not immediately destroy the container. The container should still be removed by expiry or host cleanup, but immediate destroy-on-completion would be a useful resource-saving improvement.

### 3.4.11 Tutor and chat persistence implementation

The chat API accepts a message and challenge ID. It requires authentication, checks that the user has an active challenge, and checks that the supplied challenge ID matches it. This prevents a user from asking the interactive tutor about another user's challenge or about an inactive challenge through the active chat endpoint.

The route loads persisted message history, appends the new user message, and sends the conversation to OpenRouter with a system prompt containing private challenge context. The assistant response is generated, checked for forbidden leakage, streamed back to the client as SSE token events, and then persisted together with the user message. Persistence happens only after a successful response so that failed streams do not create misleading history records.

The UI component loads previous messages on mount, streams new responses into an assistant message, and switches to read-only mode on history pages. This makes the tutor conversation part of the user's learning artefact rather than a temporary front-end state.

### 3.4.12 Challenge history implementation

Challenge history is implemented with a history API, a list page, a detail API, and a read-only challenge detail component. The list page shows each challenge's title, category, difficulty, status, creation time, and message count. Active challenges link back to the dashboard. Non-active challenges open a detail view.

The detail API returns the solution summary only for completed challenges. This supports post-solve learning while keeping the active-challenge experience constrained. Expired and destroyed challenges can still show their metadata and tutor conversation, but they do not expose the solution summary by default.

### 3.4.13 Logging implementation

The project uses a Pino-backed logging facade. Code emits structured event names such as `challenge.launch.start`, `vulnerability.generation.success`, `verification.finish`, `container.deploy.success`, `flag.submit.checked`, and `chat.messages.persisted`. This is more useful than unstructured console output because launch failures can be traced by following event names through the pipeline.

The logging facade sanitises sensitive fields recursively. Field names containing terms such as secret, password, token, key, and flag are redacted before being passed to Pino. This is important because the system handles API keys, SSH keys, generated flags, model outputs, and exploit-related data.

### 3.4.14 Evaluation harness implementation

Although evaluation results belong in the Evaluation chapter, the implementation includes support for collecting those results. The script `scripts/evaluate.ts` can be run in four modes.

| Mode | Purpose |
|---|---|
| `static` | Generate and validate specs without Proxmox. |
| `deploy` | Deploy and destroy a blank container to test orchestration. |
| `inject` | Generate, deploy, inject, run health and flag-protection verification, and destroy. |
| `full` | Generate, deploy, inject, run health, flag-protection, and exploit verification, then destroy. |

The harness writes JSON, CSV, Markdown summaries, and private generated-specification artefacts. These outputs support later evaluation of generation reliability, deployment reliability, injection reliability, verification pass rates, exploit recovery, cleanup, timing, and diversity. Generated specifications include flags and exploit details, so they should be treated as sensitive and not published as user-facing artefacts.

The harness does not fully evaluate browser usability or tutor educational quality. Those should be discussed as evaluation limitations or future work unless separate tests are added.

## 3.5 Design evolution and implementation problems

### 3.5.1 From free-text LLM output to structured specifications

A natural first approach would be to ask the model to generate files or commands directly and then execute them. This is unsafe and hard to debug. The implemented approach instead forces the model to return a structured specification. Zod validation, JSON parsing, and policy validation create a contract between the LLM and the rest of the platform. This made it possible to add injection, verification, and evaluation support without redesigning the entire system.

### 3.5.2 From model-generated flags to server-generated flags

The final system generates the flag server-side and prompts the model to embed that exact value. This gives the platform a reliable flag format and a known answer for the flag checker. The trade-off is that the platform must verify that the model actually embedded the flag and did not expose it directly. Schema validation, policy validation, flag-protection checks, and optional full exploit verification address this weakness.

### 3.5.3 From root access to a non-root learner model

If learners connected as root, privilege escalation and file-permission challenges would be meaningless because the user could already read most sensitive files. The container lifecycle role therefore creates a `student` user and injects the user's SSH key into that account. The system prompt also tells the model that the `student` user already exists and must not be recreated. This avoids failures where generated setup commands attempt to add an account that the platform has already created.

### 3.5.4 From synchronous launch to streamed progress

Container provisioning and LLM generation are too slow and unpredictable for a simple request/response user experience. The launch route streams progress using Server-Sent Events. This does not make the backend work faster, but it makes long launches understandable to the user and helps distinguish generation, deployment, injection, verification, and finalisation failures.

### 3.5.5 From Ansible success to challenge verification

Ansible can report success even when the resulting challenge is not educationally valid. For example, all files may be copied but the web server may still serve the default page, or the flag may be readable without exploitation. The verification pipeline was added to close this gap. Normal launches now require non-destructive health and flag-protection checks. Full exploit checks are available through disposable containers and the evaluation harness.

### 3.5.6 From in-memory tutor state to persisted learning history

An in-memory chat is simple but loses the learning process when the page refreshes or the challenge ends. The final system stores messages in a `messages` table linked to the challenge. This supports continuity during the attempt and review after completion. It also makes the tutor conversation part of the learning record rather than a temporary UI feature.

### 3.5.7 From application-only checks to database enforcement

The one-active-challenge rule started as an application check, but application checks alone can race. Two requests can both see no active challenge, both spend time generating and deploying containers, and both attempt to insert a challenge. The final design adds a database partial unique index and a re-check before insertion. This does not eliminate all wasted work in a race, but it prevents the database from ending up with two active challenges for the same user.

### 3.5.8 From shell-escaped file writes to staged file injection

Generated files can contain shell metacharacters, code, HTML, SQL, or other content that is difficult to safely embed inside shell commands. The injection playbook therefore stages generated files on the host and uses `pct push` to copy them into the container. This greatly reduces quoting issues and makes file injection more reliable.

### 3.5.9 From ad-hoc debugging to structured logging

The launch process spans the web server, LLM provider, Ansible, Proxmox, container commands, and database writes. Failures can therefore occur at many layers. Structured logging was added so that each stage emits consistent event names and relevant metadata while redacting sensitive values. This makes evaluation and debugging more systematic.

## 3.6 Summary

The final implementation satisfies the core aim of the project: it can generate an LLM-authored vulnerability specification, provision an isolated LXC container, inject generated artefacts, verify basic health and flag protection, expose the environment to the learner through SSH, support guided tutor interaction, and record the attempt in challenge history. The most important design decision is the use of a structured specification as the boundary between the LLM and the infrastructure. This boundary makes the system extensible because new categories, verification checks, and evaluation modes can be added without giving the model direct control over the host.

The main remaining limitations are also clear. Full exploit verification is optional and slower because it requires a disposable verifier container. The evaluation harness does not fully test browser usability or tutor teaching quality. The deployment networking model is assumed rather than fully automated in the application. Successful flag submission does not immediately destroy the container. A production-grade deployment would also need stronger network isolation, stricter container credential handling, and more comprehensive operational hardening. These limitations should be acknowledged again in the Evaluation and Reflection chapters, where they can be connected to measured results and future work.
