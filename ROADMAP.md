# Kubernetes Roadmap

This document records the long-term direction for the `kubernetes/` repository.

It is not a promise to rebuild everything at once. It is a guide for making small changes in a consistent direction, while keeping the current service baseline deployable.

## Why This Exists

The repository already works, but several operational choices make it harder to maintain than it needs to be:

- cluster access is mediated by SSH-oriented helper scripts instead of a standard Kubernetes access model
- CI still performs some runtime cluster actions directly
- runtime secrets have started moving to Sealed Secrets, but the GitOps path still needs to be committed and hardened
- stateless service resilience defaults are minimal
- Helm chart logic is starting to duplicate

None of these require a large rewrite. They do require a clear target state.

## Target State

The desired steady state is:

- Git is the source of truth for desired cluster state
- Argo CD is the primary reconciler for live state
- CI validates, renders, and promotes changes, but does not act as an imperative deploy operator
- secrets are managed declaratively through a single approved mechanism
- local cluster operations use a standard Kubernetes access path, not a custom SSH transport wrapper
- shared workload conventions live in common chart helpers instead of repeated per-service templates

## Guiding Principles

1. Keep the current service layer deployable during every phase.
2. Prefer one clear path over multiple partially overlapping paths.
3. Reduce imperative cluster mutations over time.
4. Standardize operator experience before adding more automation.
5. Make security and recovery properties more explicit, not more magical.

## Current Friction Points

### 1. Cluster access model

`scripts/kubectl.sh` currently handles SSH key material, tunnel lifecycle, remote kubeconfig fetch, and kubectl execution in one wrapper.

That is convenient in the short term, but it creates long-term problems:

- local operations depend on remote host state
- kubectl context is less transparent than standard kubeconfig usage
- SSH transport and Kubernetes auth are tightly coupled
- future migration away from SSH becomes harder because the custom flow is the default operator interface

### 2. CI-driven runtime mutation

CI currently still performs direct remote `kubectl` actions for namespace bootstrap, ArgoCD refresh, and secret creation.

That weakens the GitOps model by splitting authority across:

- git-managed manifests
- Argo CD reconciliation
- workflow-driven imperative commands

### 3. Secret lifecycle

Secrets are moving from runtime-created objects to declared SealedSecret resources.

The remaining work is to keep that path consistent enough to answer basic questions:

- where a secret comes from
- who is allowed to rotate it
- how a workload is restarted after a secret change
- whether cluster state can be reproduced from declared inputs

### 4. Availability defaults

Important stateless workloads still default to single replicas and do not yet consistently carry disruption protection or spread policy.

### 5. Template duplication

Service and app charts already repeat enough helper logic that future rollout, security, and resource conventions will become harder to keep aligned.

## Phased Plan

The goal is to move in the following order.

### Phase 1. Stabilize the operating model

Primary goal: reduce daily operator friction and make access paths easier to reason about.

Actions:

- document the current access model and its limits clearly
- keep `scripts/kubectl.sh` working, but treat it as transitional infrastructure
- split tunnel management, kubeconfig fetch, and kubectl invocation into clearer layers if the wrapper must remain for a while
- stop adding new features that deepen the SSH-based access pattern

Exit criteria:

- operators can explain the current access path in one short paragraph
- the repository has a clear documented target for replacing the SSH-heavy local workflow

### Phase 2. Make secrets declarative

Primary goal: remove imperative secret creation from the normal deployment path.

Actions:

- use Sealed Secrets as the single secret management path for the repo
- move all application runtime secrets to `manifests/*/secrets.yaml`
- add rollout triggers for secret-driven workload changes
- keep direct secret creation out of CI once the declarative path is proven

Preferred outcome:

- secret values remain outside git in plaintext
- secret definitions and ownership become visible in git
- workload restarts on secret changes become predictable

### Phase 3. Let GitOps own reconciliation

Primary goal: converge on a model where CI prepares changes and Argo CD applies them.

Actions:

- reduce workflow steps that directly mutate cluster state
- narrow the set of exceptions that require imperative bootstrap
- enable `selfHeal` before enabling broader `prune` behavior
- keep special handling explicit for resources that cannot be fully declarative yet

Exit criteria:

- business workload rollout no longer depends on ad hoc remote kubectl actions from CI
- drift handling responsibility is clear

### Phase 4. Improve workload safety defaults

Primary goal: make stateless services safer by default.

Actions:

- move critical services to at least two replicas where appropriate
- add `PodDisruptionBudget` for relevant workloads
- add topology spread or anti-affinity rules where they improve availability
- review whether HPA is justified per workload instead of adding it everywhere by default

### Phase 5. Consolidate chart conventions

Primary goal: reduce repeated Helm logic and make platform defaults easier to enforce.

Actions:

- extract shared helpers or a library chart for common workload patterns
- standardize labels, probes, resources, env injection, and security settings
- keep service-specific behavior only where it is actually specific

### Phase 6. Raise the security baseline

Primary goal: make default workload posture less permissive.

Actions:

- add `securityContext` defaults for application pods and containers
- prefer `runAsNonRoot` and `seccompProfile: RuntimeDefault`
- add `readOnlyRootFilesystem` where workloads support it
- introduce namespace `NetworkPolicy` baselines and explicit allow rules
- review Argo CD project permissions and reduce unnecessary breadth

### Phase 7. Clean up structure and environment strategy

Primary goal: make the repository easier to evolve without confusion.

Actions:

- decide whether this repository remains single-environment or grows explicit overlays
- remove stale generated-path assumptions and placeholder structure
- keep generated render output rules simple and consistent

## Decision Rules

When choosing between two implementation paths, prefer the option that:

- reduces the number of places allowed to mutate live cluster state
- makes the operator workflow more standard to Kubernetes users
- keeps secrets out of ad hoc shell flows
- improves observability and auditability of changes
- avoids introducing a new framework unless it removes a real existing burden

## What Not To Do

Avoid these traps during the cleanup:

- do not replace one custom access wrapper with a more elaborate custom access wrapper
- do not add a second secret mechanism without a clear deprecation path for the first
- do not enable aggressive Argo CD pruning before declarative ownership is clear
- do not add HPA, affinity, and policy objects everywhere without verifying the workload need
- do not turn this repository into a platform framework before the operating model is stable

## Near-Term Priorities

If work must be done incrementally, start here:

1. define the replacement direction for SSH-heavy local kubectl usage
2. move secrets onto one declarative path
3. remove CI secret creation and reduce direct remote kubectl operations
4. improve replica and disruption defaults for critical stateless workloads
5. consolidate repeated Helm helper logic

## Success Signal

This roadmap is working if the repository becomes easier to explain:

- local operators know how they are authenticated and what cluster they are targeting
- CI is mostly validating and promoting, not hand-driving the cluster
- Argo CD is clearly responsible for reconciliation
- secret handling is consistent
- service chart changes do not require repetitive edits across many templates
