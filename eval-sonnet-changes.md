# Chapter 3 — Supervisor Feedback: Suggested Changes

> **Note:** This is formative, advisory help only — not a mark or mark prediction, not an authoritative ruling on the module, and cannot be used to challenge any official decision.

Supervisor feedback had two points: (1) stronger justification of design choices, and (2) expand on each flowchart so a reader could recreate the experiment with minimal additional interpretation.

---

## Point 1 — Justification additions

### 1. Technology stack (§3.3.1, after line 361)

Add after the WAL mode sentence:

> Next.js was chosen as the application framework because its file-based API routing allows the server-side orchestration logic and the React UI to live in a single deployable unit, removing the need for a separate backend service and cross-origin request handling. For a single-host prototype, this significantly reduces deployment complexity. SQLite was chosen over a client-server database such as PostgreSQL because the application runs on one host and has no concurrent writers at production scale. The simpler operational model — no separate database process, no connection pool to configure, and a single file to back up or inspect — was more appropriate for this scope. Drizzle ORM was chosen because it generates type-safe queries directly from the schema definition, and its migration runner integrates with the application startup path, meaning schema changes are applied automatically without a separate migration tool or manual step.

---

### 2. System architecture (§3.2, after line 137)

Add as a third paragraph after the LXC justification:

> A single Next.js application was chosen as the control plane rather than separating the frontend and backend into independent services. For this prototype, a monolithic deployment reduces operational complexity: there is one process to run, one set of environment variables to configure, and no cross-origin request handling between a separate API server and UI. The trade-off is that the TypeScript API routes share a process with the UI, meaning that a crash in one affects the other. This is acceptable here because the deployment target is a controlled single-host lab environment rather than a multi-service production system.

---

### 3. Tutor design (§3.2.6, after line 286)

Add after the sentence ending "...replaced by a block message asking the user to request a smaller hint":

> The two-layer approach is intentional. The system prompt alone relies on the model following its instructions, which cannot be guaranteed across model updates, prompt injection attempts from user messages, or unexpected model behaviour. The application-level filter is a deterministic check that does not depend on the model's compliance at all: even if the model produces a response that contains the flag or the full solution summary, it is never sent to the client. Neither layer alone is sufficient — the system prompt reduces the frequency of leaks during normal use, while the filter is the enforceable safety boundary that holds regardless of model behaviour.

---

### 4. Evaluation harness design (§3.2.7, after the modes table, line 329)

Add after the `evaluation-modes` table:

> The alternative to this separation would be a single end-to-end mode that creates a container, injects the generated specification, and verifies it, reporting only a binary pass or fail for the whole pipeline. The problem with this approach is that a failure anywhere in the pipeline produces the same result, making it impossible to determine whether the failure originated in the model output, the infrastructure, the injection step, or the verification commands. By separating static, deploy, inject, and full modes, each failure is localised to the stage that caused it. For example, a high static failure rate that is independent of a low deploy failure rate indicates a model reliability problem rather than an infrastructure one, and can be addressed by adjusting prompts without touching the container orchestration code at all.

---

### 5. Verification design (§3.2.5, after line 261)

Add after the sentence describing the validation command fields:

> Generated validation commands were chosen over a fixed library of per-category checks because the variation in generated output makes static checks impractical. A fixed check for a privilege escalation challenge might look for a specific SUID binary, but the model may generate a different binary, a misconfigured service, or a vulnerable script in each run. By generating the validation commands alongside the vulnerability specification, each check is tied to the exact file paths, service names, and exploit conditions described in that specific run. The trade-off is that the generated checks are themselves subject to model error, which is why the runner treats them as untrusted input and constrains the contexts in which they can execute.

---

## Point 2 — Flowchart walk-through additions

For each figure, add a paragraph directly after the `\caption{...}` block and before the existing prose that follows it. Adjust if your figure shows additional branches not covered here.

---

### Fig. 3 — Challenge lifecycle (after line 183)

> Figure~\ref{fig:challenge_lifecycle} shows the four reachable states and the transitions between them. A challenge enters the \lstinline|active| state when it is inserted into the database at the end of a successful launch. From \lstinline|active|, three terminal transitions are possible. A correct flag submission before expiry moves the challenge to \lstinline|completed| and triggers container deletion. A user-initiated deletion moves it to \lstinline|destroyed| and triggers asynchronous container deletion, returning control to the UI immediately. An application-side expiry check or the Proxmox TTL reaper moves the challenge to \lstinline|expired|. All three terminal states are final: once a challenge leaves \lstinline|active|, no further status transitions occur. The TTL reaper provides a safety net for the \lstinline|expired| path because the application may not be running continuously to catch every expiry, and for any containers belonging to challenges that were not cleaned up by the application.

---

### Fig. 4 — Launch pipeline (after line 198)

> Figure~\ref{fig:launch_pipeline} shows the full sequence of steps and the failure branches at each stage. The pipeline begins with generation: the prompt builder constructs a category- and difficulty-specific prompt, calls OpenRouter, and validates the response through Zod schema validation and semantic policy validation. If generation fails or produces an invalid specification, the pipeline stops before any container has been created. If \lstinline|CHALLENGE_FULL_VERIFY_BEFORE_LAUNCH| is enabled, a disposable verifier container is deployed next, exploit checks are run against it, and the verifier is destroyed before the user-facing container is created. For a normal launch, the pipeline moves directly to deploying the user-facing container, injecting the vulnerability specification, and running health and flag-protection checks. If health verification fails after a container has been created, the pipeline destroys the container and returns an error to the client before writing any database record. If verification passes, the route performs a final race-condition check for an existing active challenge, inserts the challenge row, and sends an SSE success event containing the SSH command to the client.

---

### Fig. 5 — Generation and policy pipeline (before the six-point list, after line 239)

Add before the `\begin{enumerate}` at line 241:

> Figure~\ref{fig:generation_policy} shows the order of operations in the generation pipeline. The process begins with the platform generating a server-side flag and selecting a prompt variant for the requested category and difficulty. The prompt builder then queries the database for recent challenges in the same category and appends their titles and solution summaries as an exclusion list. The constructed prompt is sent to OpenRouter with the Zod schema converted to JSON Schema as the required response format. The returned JSON is first parsed, then validated against \lstinline|VulnerabilitySpecSchema|, and then passed through policy validation. If either validation step rejects the response, the platform retries with a fallback model. A specification that passes both steps is returned to the launch pipeline. The six safeguards listed below correspond to design decisions made at specific stages of this sequence.

---

### Fig. 6 — Verification contexts (after the runner context table, after line 278)

> Figure~\ref{fig:verification-system} shows how the runner dispatches and evaluates each check. Each validation command in the specification declares its required context. The runner routes \lstinline|container_root| commands to \lstinline|pct exec| running as root inside the container, \lstinline|container_student| commands to the same path but as the \lstinline|student| user, and \lstinline|external_http| commands to \lstinline|curl| running from the Proxmox host against the container IP. After each command, the runner compares the exit code against the expected value, checks any required stdout or stderr conditions, and checks for any forbidden stdout strings. If \lstinline|must_recover_flag| is set to \lstinline|true|, the runner additionally checks whether the stored flag value appears in the output. The runner collects results for all checks before returning, rather than aborting on the first failure, so the complete set of check results is always available for diagnosis and failure classification.

---

### Fig. 7 — Evaluation harness workflow (after line 306)

> Figure~\ref{fig:evaluation-harness-design} shows the execution path through the harness for a single evaluation task. The harness begins by parsing CLI options and building a flat list of tasks, where each task is a combination of mode, category, and difficulty. Tasks are executed up to a configurable concurrency limit. For each task, \lstinline|runOneEvaluation()| records a structured result object and times each stage independently using \lstinline|timeStage()|. In \lstinline|static| mode, only the generation stage runs: \lstinline|generateVulnerability()| is called, the validated specification is saved to \lstinline|generated-specs/|, and schema and policy outcomes are recorded. In \lstinline|deploy| mode, no generation occurs: a container is created, waited on, and destroyed, recording only infrastructure outcomes. In \lstinline|inject| mode, generation, deploy, injection, and health verification run in sequence. In \lstinline|full| mode, exploit checks are added after health verification. At each stage, a failure is caught, recorded with the failure stage and error text, and the result object is finalised before the next task begins. Cleanup is attempted even when an earlier stage has failed, to avoid leaving orphaned containers. After all tasks complete, the harness writes \lstinline|results.json|, \lstinline|results.csv|, and \lstinline|summary.md| to the configured output directory.

---

### Fig. 8 — Tutor chat flow (after line 489)

> Figure~\ref{fig:tutor-chatbot-flow} shows the decision path through the chat route for a single message. The route first verifies authentication and loads the active challenge for the authenticated user. It checks that the challenge ID supplied in the request matches the active challenge, rejecting requests that reference a different or inactive challenge. The persisted message history for this challenge is loaded, the new user message is appended, and a system prompt is constructed from the challenge title, description, category, difficulty, hint, attack vector, and private solution summary. The combined history and system prompt are sent to OpenRouter. Once a complete response is returned, the leak filter is applied: if the response contains a \lstinline|FLAG{...}| pattern, the exact stored flag value, or a normalised form of the solution summary, the response is discarded and a block message is returned to the client instead. If the response passes the filter, it is streamed to the client and then persisted as a user--assistant message pair in a single database transaction. Persistence occurs only after a complete, filtered response, so partial or blocked responses do not produce a misleading history entry.
