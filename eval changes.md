# Evaluation and Methodology Changes

Important note: this is formative and advisory only. It is not a mark, not a mark prediction, not an authoritative ruling on the module, and cannot be used to argue for or against any official mark or decision. Official decisions come from the live guide, PATS, and relevant staff.

Your supervisor's advice maps mainly to Chapter 3, especially the Design, Implementation, and Evaluation harness design parts. I would not treat it as a request to add a brand new methodology chapter unless your report structure requires that. Instead, strengthen the existing Chapter 3 so it reads more like a reproducible method, not just a system description.

## Main issue to fix

At the moment, Chapter 3 describes many components, but some sections say what you did more clearly than why that design was chosen and how another reader could reproduce it.

The changes should therefore do two things:

1. Add explicit design rationale.
2. Expand each diagram with enough procedural detail that the reader can follow the experiment or system workflow without guessing.

## Where to make the changes

### 1. Start of Chapter 3

Current opening:

```latex
This chapter describes how VulnForge was designed, and implemented...
```

Add a paragraph after this explaining the methodology logic:

```latex
The methodology follows an iterative build and evaluation approach. Each major design choice was made to support the central research question: whether generated vulnerable environments can be created, deployed, validated, used, and removed reliably in a controlled educational setting. For this reason, the chapter does not only describe the final architecture; it also explains why particular technologies and boundaries were selected, and how the resulting system can be reproduced.
```

This directly responds to stronger justification.

### 2. Specification section

Add one short paragraph before the functional requirements table explaining why requirements are framed this way.

```latex
The requirements were derived from the minimum lifecycle needed for a usable generated challenge. A challenge must be selectable, generated, deployed, accessed, verified, completed, recorded, and cleaned up. Requirements that did not directly support this lifecycle, such as competitive scoring or large scale class administration, were excluded to keep the prototype focused on feasibility and evaluation.
```

This helps justify scope.

### 3. Design section

Add a short design rationale paragraph after the architecture introduction.

```latex
This architecture was chosen to keep untrusted generation, user interaction, and infrastructure control separated. The web application acts as the only control plane, the LLM produces structured data rather than executing actions, Ansible performs repeatable infrastructure operations, and Proxmox provides isolated container lifecycle management. This separation makes the system easier to test because each stage can fail independently and be recorded during evaluation.
```

This justifies the overall architecture.

## Expand each flowchart or diagram

Your supervisor specifically mentions flowcharts. Add a consistent paragraph after each major diagram using this pattern:

```text
Figure X should be read as follows...
Inputs are...
The main stages are...
The outputs are...
Failure handling is...
This design was chosen because...
```

You do not need huge expansions. One strong paragraph per diagram is enough.

## Specific diagram changes

### A. System architecture diagram

After the system architecture figure, add:

```latex
Figure~\ref{fig:system-architecture} shows the deployment boundary used throughout the project. The learner interacts only with the web application and the assigned container. The web application is responsible for authentication, state management, generation requests, orchestration calls, and flag submission. OpenRouter is used only through server side calls, while Ansible and Proxmox are not exposed to the learner. This design was chosen to minimise the number of trusted entry points and to make the experiment reproducible: a reader needs the web application, the configured environment variables, Ansible playbooks, and a Proxmox host capable of creating LXC containers.
```

### B. Database schema diagram

After the database schema figure, add:

```latex
Figure~\ref{fig:data-model} defines the persistent state required to reproduce the challenge lifecycle. The users and sessions tables support authentication, while the challenges table records the generated machine, its status, expiry time, category, difficulty, flag, and private solution metadata. The messages table stores tutor interactions against a challenge. This schema was chosen because it separates user identity, active infrastructure state, and learning history, which allows the same challenge lifecycle to be inspected after completion or failure.
```

### C. Challenge lifecycle diagram

After the challenge lifecycle figure, add:

```latex
Figure~\ref{fig:challenge-lifecycle} shows the state transitions for a challenge. A challenge becomes active only after the launch pipeline has generated, deployed, injected, verified, and stored the environment. It becomes completed when the learner submits the correct flag, destroyed when the user manually ends it or cleanup succeeds, and expired when the time limit has passed. This state model was chosen so that the database records the user's learning attempt separately from the lower level container lifecycle, which can fail or complete asynchronously.
```

Use the actual label from your file if different.

### D. Launch pipeline diagram

After the launch pipeline figure, add:

```latex
Figure~\ref{fig:launch-pipeline} gives the exact launch procedure used in normal operation. The route first authenticates the user, validates the stored SSH key, checks that there is no active challenge, and validates the requested category and difficulty. It then generates a structured vulnerability specification, deploys a fresh container, injects the generated files and setup commands, runs health and flag protection checks, stores the challenge record, and streams progress updates to the browser. If deployment, injection, or verification fails after a container has been created, the route attempts cleanup before returning an error. This ordering was chosen so that broken generated challenges are not shown to learners and infrastructure is not left running unnecessarily.
```

### E. Generation and policy validation diagram

After the generation and policy validation figure, add:

```latex
Figure~\ref{fig:generation-policy} shows how the project constrains LLM output before it reaches the infrastructure layer. The input to the model is the selected category, difficulty, generated flag, category prompt, and recent challenge history for diversity. The expected output is a JSON object matching the vulnerability specification schema. The system then parses the response, validates the schema, applies policy checks, and retries with fallback models where appropriate. This design was chosen because free text generation would be difficult to verify and unsafe to execute directly.
```

Use the actual label from your file if different.

### F. Verification diagram

After the verification figure, add:

```latex
Figure~\ref{fig:verification-system} explains how generated checks are executed without giving the model unrestricted host control. Health checks confirm that the service exists and responds as expected. Flag protection checks confirm that the learner cannot read the flag directly. Exploit checks, used mainly during full evaluation, attempt to recover the flag through the intended vulnerability. The checks run in bounded contexts such as container root, container student, or external HTTP. This design was chosen because successful deployment alone does not prove that a generated challenge is usable or pedagogically valid.
```

### G. Evaluation harness workflow

After the evaluation harness workflow figure, add:

```latex
Figure~\ref{fig:evaluation-harness-design} shows the experimental procedure used to evaluate the platform. For each selected category, difficulty, and repetition count, the harness creates one evaluation run. A run records generation, deployment, injection, verification, and cleanup as separate stages. Each stage records success, failure reason, duration, and relevant artefacts such as the generated specification and verification output. The harness writes results to JSON for detailed inspection, CSV for analysis, and Markdown summaries for report tables. This design was chosen so that failures can be attributed to generation, infrastructure, injection, verification, or cleanup rather than being reported only as a single pass or fail result.
```

Also add a small reproduction parameters paragraph nearby:

```latex
To reproduce the evaluation, a reader would need to specify the evaluation mode, vulnerability categories, difficulty levels, number of runs per combination, concurrency level, model configuration, and output directory. The experiment should also record the Proxmox host configuration, container template, OpenRouter model settings, and whether full exploit verification is enabled.
```

This directly addresses your supervisor's point.

## Design choices that need stronger justification

### 1. Why Proxmox LXC rather than full VMs or Docker

Add in the container deployment implementation section:

```latex
LXC was chosen because the project required fast creation and deletion of isolated Linux environments, while still allowing system level configuration such as users, services, packages, permissions, and process management. Docker would have made application packaging simpler, but would not match the intended vulnerable machine style as closely. Full virtual machines would provide stronger isolation, but would increase launch time and resource usage. For this prototype, unprivileged LXC containers were a practical compromise, with the limitation that they are not equivalent to a production grade isolation boundary.
```

### 2. Why Ansible rather than direct Proxmox API only

Add in the architecture or container deployment section:

```latex
Ansible was used because the deployment and injection steps are procedural, repeatable, and easier to inspect as playbooks than as a large amount of embedded application code. This also made failures easier to debug because each task reports its own output. The trade off is that the web application must invoke an external process and parse failure output.
```

### 3. Why structured JSON and Zod

Strengthen the existing explanation with:

```latex
This design was chosen because the infrastructure layer requires deterministic fields, not prose. Files, package names, permissions, services, setup commands, and validation checks must be processed mechanically. The schema therefore acts as the contract between probabilistic model output and deterministic infrastructure automation.
```

### 4. Why health mode for normal launch and full mode for evaluation

Add:

```latex
This separation also makes the experiment reproducible because the same generated specification can be assessed at different verification depths depending on whether the goal is user launch speed or evaluation confidence.
```

## Practical editing plan

Make the changes in this order:

1. Add a methodology rationale paragraph at the top of Chapter 3.
2. Add short explanatory paragraphs after each major diagram.
3. Add a stronger reproducibility paragraph in Evaluation harness design.
4. Add explicit justifications for Proxmox LXC, Ansible, structured JSON, and verification modes.
5. Remove duplicated diagrams in implementation sections and replace them with references back to the design diagrams.

For example, instead of repeating the tutor diagram in implementation:

```latex
Figure~\ref{fig:tutor-chat-flow} shows the tutor flow used by this implementation.
```

This keeps the report cleaner and avoids duplicated figures.

## Biggest priority

If you only have time for a few edits, prioritise:

1. Launch pipeline
2. Generation and policy validation pipeline
3. Verification contexts and checks
4. Evaluation harness workflow

Those are the diagrams most closely tied to reproducibility.
