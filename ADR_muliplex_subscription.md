# 0010. Multiplex Subscription Licenses — Technical Architecture

| Field | Value |
|---|---|
| **Status** | Proposed |
| **Date** | 2026-03-30 |
| **Version** | 1.0 |
| **Author** | |
| **Scope** | `enterprise-access` · `enterprise-catalog` · `frontend-app-learner-portal-enterprise` |

## Context

The enterprise ecosystem is moving toward support for **multiple concurrent subscriptions per learner**. A learner may hold more than one active subscription at the same time, potentially across:

- different enterprise customers,
- different enterprise catalogs,
- different subscription plans,
- different assignment and activation timelines.

Today, many application flows implicitly assume a single applicable subscription or a single current license. That assumption creates architectural pressure in several areas:

1. **Learner state modeling** becomes ambiguous when more than one subscription is valid.
2. **Downstream consumers** such as the learner portal, catalog services, reporting systems, and enrollment workflows need a reliable way to understand the learner's entitlements.
3. **Tight synchronous coupling** between services increases when one system must repeatedly query another for the full current subscription state.
4. **Schema evolution risk** grows when producers attempt to publish large aggregate payloads representing all subscriptions for a learner.

The requirement is not simply to store more subscriptions. The requirement is to model, publish, and consume subscription state changes in a way that is:

- aligned with Open edX Events principles,
- scalable across multiple consumers,
- resilient to replay and recovery,
- versionable over time,
- safe with respect to PII and event payload design.

## Problem Statement

We need an event model that supports **multiplex subscriptions** while preserving clear event semantics.

For the purposes of this decision, **multiplex subscriptions** means:

> A learner may have multiple independently addressable subscription records, each with its own lifecycle, status, catalog association, and expiration.

The architecture must answer this question:

> Should the producer emit one aggregate event containing a learner's full subscription list, or emit subscription-scoped lifecycle events and allow consumers to build their own projections?

## Decision

We will represent multiplex subscriptions using **subscription-scoped lifecycle events**, not a single aggregate event containing all subscriptions for a learner.

### Chosen model

Each event will represent **one business fact for one subscription**.

Recommended event types include:

- `org.openedx.enterprise.subscription.created.v1`
- `org.openedx.enterprise.subscription.assigned.v1`
- `org.openedx.enterprise.subscription.activated.v1`
- `org.openedx.enterprise.subscription.updated.v1`
- `org.openedx.enterprise.subscription.expired.v1`
- `org.openedx.enterprise.subscription.revoked.v1`

Consumers that require a learner-level or enterprise-level view of all subscriptions will build a **materialized read model** by aggregating these events.

## Architectural Rationale

This decision is preferred for the following reasons.

### 1. One event should represent one domain fact

An event should describe a concrete business occurrence, not a periodically reconstructed view of state. A subscription activation event is a fact. A full list of all current subscriptions is a projection.

This keeps event intent clear and easier to govern.

### 2. Multiplicity is handled naturally

If a learner has three subscriptions, the system does not need a special "multiplex" payload shape. It simply emits facts for three distinct `subscription_uuid` values.

This avoids inventing a special aggregate contract for a common domain concept.

### 3. Consumer projections remain independent

Different consumers need different views:

- learner portal needs a learner-facing entitlement summary,
- enterprise reporting needs historical and operational data,
- catalog services need catalog-scoped entitlement applicability,
- enrollment logic needs a best-fit active subscription.

A producer should publish facts. Consumers should own read models.

### 4. Replay and recovery become straightforward

With event-per-subscription lifecycle modeling, a consumer can replay the stream and reconstruct state. This is harder and less reliable when the producer emits large aggregate snapshots.

### 5. Versioning is easier and safer

Small, fact-based events evolve more safely than monolithic payloads. Optional fields can be added with minimal consumer impact. Breaking changes can be isolated to specific event types.

### 6. Payload size and instability are reduced

A full learner subscription list can grow unpredictably and change shape frequently. Single-subscription events remain bounded, understandable, and easier to validate.

## Event Modeling Guidance

### Topic strategy

A single bounded-context topic may carry multiple related subscription lifecycle events, for example:

- `enterprise.subscription.lifecycle`

This follows the Open edX event design principle that related event types may share a topic when they belong to the same domain boundary.

### Common payload fields

Each lifecycle event should include stable identifiers and sufficient context for downstream consumers.

Recommended fields:

- `event_id`
- `occurred_at`
- `subscription_uuid`
- `subscription_plan_uuid`
- `enterprise_customer_uuid`
- `enterprise_catalog_uuid`
- `learner_uuid`
- `status`
- `start_date`
- `expiration_date`
- `is_current`
- `change_reason`
- `producer`

Optional fields where appropriate:

- `previous_status`
- `assignment_uuid`
- `metadata`
- `effective_at`

## Example Event Schema

```json
{
  "event_id": "8b43e9d2-5d2c-4a5d-a0d2-3c65f7e31c8a",
  "occurred_at": "2026-03-30T12:00:00Z",
  "subscription_uuid": "sub-123",
  "subscription_plan_uuid": "plan-456",
  "enterprise_customer_uuid": "ent-789",
  "enterprise_catalog_uuid": "cat-321",
  "learner_uuid": "learner-654",
  "status": "activated",
  "start_date": "2026-03-01T00:00:00Z",
  "expiration_date": "2026-12-31T23:59:59Z",
  "is_current": true,
  "change_reason": "learner_activation",
  "producer": "license-manager"
}
```

## Consumer Projection Model

Consumers should build their own projections from the lifecycle stream.

### Example: learner subscription projection

**Key:**

- `learner_uuid`

**Value:**

- active subscriptions,
- expired subscriptions,
- subscriptions grouped by enterprise catalog,
- subscriptions grouped by enterprise customer,
- preferred subscription for enrollment or redemption.

### Example: catalog applicability projection

A consumer can derive whether a course or catalog is covered by finding subscriptions that satisfy all of the following:

- `status == activated`
- `is_current == true`
- `enterprise_catalog_uuid` matches the course/catalog context

## Ordering, Delivery, and Idempotency

Consumers must assume:

- duplicate event delivery is possible,
- out-of-order delivery is possible,
- replay is possible,
- delayed delivery is possible.

Therefore consumers should:

- deduplicate by `event_id`,
- upsert by `subscription_uuid`,
- compare `occurred_at` or an explicit version before overwriting state,
- make projection updates idempotent.

## PII and Security Guidance

Subscription events should avoid direct PII unless explicitly required and approved.

Prefer:

- `learner_uuid`
- `enterprise_customer_uuid`
- `subscription_uuid`

Avoid unless required by policy:

- learner email address,
- learner full name,
- username,
- other unnecessary personal attributes.

If sensitive data becomes necessary, it should follow the stricter Open edX event governance guidance for events containing PII.

## Alternatives Considered

### Alternative A: Publish one aggregate “learner subscriptions changed” event

**Rejected.**

Reasons:

- payload size grows with learner state,
- difficult to evolve safely,
- represents a projection rather than a fact,
- increases coupling between producer and consumers,
- replay semantics are weaker,
- partial updates are harder to reason about.

### Alternative B: Keep synchronous APIs as the primary integration mechanism

**Rejected as the primary model.**

Reasons:

- tight runtime coupling,
- weaker resilience,
- repeated cross-service reads,
- poorer fit for multiple consumers,
- more difficult long-term scaling.

### Alternative C: Publish scheduled snapshots only

**Rejected.**

Reasons:

- low freshness,
- poor support for real-time workflows,
- less useful for audit and replay,
- weak event semantics.

## Consequences

### Positive consequences

- clean support for multiple subscriptions,
- reduced producer-consumer coupling,
- easier schema governance,
- better replay and recovery,
- clearer bounded-context ownership,
- alignment with Open edX event best practices.

### Negative consequences

- consumers must build and maintain projection logic,
- eventual consistency must be accepted,
- more event definitions must be documented and governed.

## Implementation Guidance

1. Introduce lifecycle event definitions for subscription domain changes.
2. Emit events from the source-of-truth service responsible for subscription state.
3. Use an outbox-based production pattern where available.
4. Define versioned schemas for each event type.
5. Build consumer-owned projections for portal, reporting, and catalog applicability.
6. Add idempotency and replay-safe handling in all consumers.

## Recommendation Statement

The recommended architecture is:

> Represent multiplex subscriptions as multiple subscription lifecycle events rather than a single aggregate subscription payload. The producer owns facts; consumers own projections.

This is the most scalable, evolvable, and architecturally sound model for supporting multiple subscriptions in an Open edX ecosystem.

## Follow-up Work

- Define canonical subscription lifecycle vocabulary.
- Identify the authoritative producer service.
- Draft Open edX event schemas for each lifecycle event.
- Define consumer projections for learner portal and enterprise catalog use cases.
- Review payload fields for privacy classification.
