# Feature Specification: Azure Temporal Self-Hosted Infrastructure

**Feature Branch**: `003-azure-temporal-infra`
**Created**: 2026-03-30
**Status**: Draft
**Input**: User description: "i need the azure infrastructure necessary to host temporal. here is the self hosting documentation: https://docs.temporal.io/self-hosted-guide please follow all best practices and ask me to clarify key decision points such as back end database technology and which container orchestration engine to use"

## Clarifications

### Session 2026-03-30

- Q: Does this repo deploy Temporal itself, or only provision the underlying Azure infrastructure? → A: Infrastructure provisioning only — no Temporal service deployment, Helm chart installation, namespace initialization, or application workload deployment.
- Q: What PostgreSQL Flexible Server compute tier should be provisioned? → A: General Purpose (2–4 vCores, D-series) — balanced cost/performance, suitable for dev through moderate production.
- Q: How will AKS workloads access PostgreSQL credentials stored in Key Vault? → A: External Secrets Operator (ESO) CRD; AKS must have Workload Identity enabled so ESO can authenticate to Key Vault.
- Q: How many nodes in the initial AKS node pool? → A: 1 node (dev/cost-optimized); staging and production will use higher counts.
- Q: Does the infrastructure require private networking (VNet, private endpoints, VPN Gateway)? → A: No — public endpoints are acceptable for AKS API server and PostgreSQL. No VNet, private endpoints, private DNS zones, or VPN Gateway are required.
- Q: What should the PostgreSQL firewall rule strategy be? → A: Allow AKS outbound IPs only — look up the AKS cluster's outbound public IP(s) via Terraform data source at apply time and whitelist only those.
- Q: Should the AKS public API server be access-restricted? → A: Yes — restrict via `authorized_ip_ranges` input variable; operator provides their CIDR(s) at deploy time.
- Q: Should Key Vault have network-level access restrictions? → A: No — fully open public endpoint; RBAC-only access control (no firewall rules).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provision AKS Cluster for Temporal (Priority: P1)

An infrastructure operator provisions an AKS cluster sized and configured to host Temporal. The cluster uses a public API server endpoint and is ready to accept a Temporal Helm chart deployment by an external process.

**Why this priority**: AKS is the compute platform all Temporal services will run on. Without it, nothing else can be deployed.

**Independent Test**: Can be fully tested by confirming the AKS cluster is in a Running state, nodes are healthy, and the cluster API server is reachable.

**Acceptance Scenarios**:

1. **Given** `terragrunt apply` completes, **When** the AKS cluster state is checked, **Then** all nodes are in Ready state and the API server is accessible.
2. **Given** the AKS cluster exists, **When** a `kubectl get nodes` is run, **Then** the expected node pool nodes are returned.

---

### User Story 2 - Provision PostgreSQL Database for Temporal (Priority: P1)

An infrastructure operator provisions an Azure Database for PostgreSQL Flexible Server instance sized and configured to serve as both the Temporal persistence store and the Advanced Visibility store.

**Why this priority**: Temporal requires a pre-existing, accessible database before Helm chart installation can succeed. The database is a hard dependency of the deployment step.

**Independent Test**: Can be fully tested by confirming the PostgreSQL server is in a Running state and reachable on port 5432.

**Acceptance Scenarios**:

1. **Given** `terragrunt apply` completes, **When** the PostgreSQL server state is checked, **Then** the server is in Running state and accessible on port 5432.
2. **Given** the database server exists, **When** a connection is attempted on port 5432, **Then** the connection succeeds (credentials stored in Key Vault and produced as Terraform outputs).

---

### User Story 3 - Infrastructure Lifecycle Management (Priority: P2)

An infrastructure operator can safely create, update, or destroy all provisioned Azure resources using Terragrunt without manual intervention.

**Why this priority**: All resources must be fully codified in IaC to prevent configuration drift, enable environment parity, and support teardown/rebuild workflows.

**Independent Test**: Can be tested by running `terragrunt plan` after a clean `apply` and confirming zero planned changes.

**Acceptance Scenarios**:

1. **Given** the infrastructure is deployed, **When** a `terragrunt plan` is run with no config changes, **Then** zero changes are shown (idempotent).
2. **Given** a configuration value is changed (e.g., node pool count), **When** `terragrunt apply` is run, **Then** only the expected resources are modified.

---

### Edge Cases

- What happens if the AKS node pool runs out of capacity when Temporal services are later deployed? (Node pool SKU and count must be sized above minimum Temporal requirements.)
- What happens if the Terraform state storage account is unavailable during apply? (Apply fails safely; existing Azure resources are unaffected.)
- What happens if the AKS cluster upgrade causes node pool drain while Temporal is running? (Out of scope for this repo — documented as an operational concern for the deployment layer.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The infrastructure MUST provision an AKS cluster with a node pool using the Standard_D2s_v3 SKU (2 vCPUs, 8 GB RAM); the initial node count is 1 for the dev environment, with higher counts defined per environment in Terragrunt inputs.
- **FR-002**: The infrastructure MUST provision an Azure Database for PostgreSQL Flexible Server instance using the General Purpose compute tier (2–4 vCores, D-series SKU), accessible with a public endpoint; firewall rules MUST restrict access to the AKS cluster's outbound public IP(s), looked up dynamically via Terraform data source at apply time.
- **FR-003**: The AKS cluster MUST use a public API server endpoint with `authorized_ip_ranges` configured; access is restricted to operator-provided CIDR(s) supplied as a Terragrunt input variable.
- **FR-004**: The infrastructure MUST provision an Azure Key Vault with a public endpoint and no network-level firewall; access is controlled exclusively via Azure RBAC. The AKS cluster MUST have Workload Identity enabled so that the External Secrets Operator (ESO) can authenticate to Key Vault via a federated identity credential and sync secrets to Kubernetes Secrets.
- **FR-005**: The infrastructure MUST use Terragrunt to manage environment-specific configurations (dev, staging, production) consistent with the existing repository module pattern.
- **FR-006**: All Terraform state for this feature MUST be stored in the existing Azure Blob Storage backend (`homeschooliostfstate`) under a dedicated container.
- **FR-007**: The infrastructure MUST output the AKS cluster name, resource group, PostgreSQL server FQDN, and Key Vault URI as Terragrunt outputs consumable by downstream deployment processes.
- **FR-008**: The PostgreSQL instance MUST be pre-configured with the database(s) and role(s) required by Temporal; credentials MUST be stored in Key Vault before the infrastructure apply completes.

### Key Entities

- **AKS Cluster**: The Azure Kubernetes Service cluster that will host the four Temporal service Deployments; sized for Temporal's compute requirements with a public API server endpoint restricted to operator-provided CIDR(s) via `authorized_ip_ranges`.
- **PostgreSQL Flexible Server**: The managed Azure database instance serving as both the Temporal persistence store and the Advanced Visibility store; accessible via public endpoint with firewall rules restricting access to the AKS cluster's outbound public IP(s), resolved dynamically at apply time.
- **Key Vault**: The Azure Key Vault storing PostgreSQL credentials and any other secrets required by the Temporal deployment layer; public endpoint with no network-level firewall — access controlled exclusively via Azure RBAC (Workload Identity federated credentials for ESO, operator identity for manual management).
- **Terragrunt Root**: The per-environment Terragrunt configuration composing the above entities, consistent with the existing `homeschoolio-infra` module pattern.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A `terragrunt apply` against a clean Azure environment completes without errors and produces all required outputs (AKS cluster name, PostgreSQL FQDN, Key Vault URI).
- **SC-002**: A `terragrunt plan` on an unmodified deployed environment produces zero planned changes (idempotency confirmed).
- **SC-003**: The AKS cluster nodes are in Ready state and the API server is reachable after apply.
- **SC-004**: The PostgreSQL Flexible Server is in Running state and accepts connections on port 5432.
- **SC-005**: PostgreSQL credentials are present in Key Vault and readable by the AKS cluster managed identity.

## Assumptions

- Temporal Server version 1.20 or later will be used by the deployment layer, enabling PostgreSQL-based Advanced Visibility; this repo does not install Temporal but must provision compatible database versions (PostgreSQL 13–16).
- The deployment targets the `dev` environment initially; staging and production follow the same Terragrunt module pattern.
- Application workloads (Temporal SDK workers) will be deployed into the same AKS cluster by a separate process outside this repo.
- The existing `homeschoolio-shared-rg-tfstate` resource group and `homeschooliostfstate` storage account are available for remote state storage.
- This feature covers Azure infrastructure provisioning only; Temporal Helm chart installation, namespace initialization, and worker application deployment are out of scope.
- No private networking, VNet, private endpoints, private DNS zones, or VPN Gateway are required; public endpoints are acceptable for AKS and PostgreSQL.
- No multi-region clustering is required for the initial deployment.
- History Shard count configuration is the responsibility of the deployment layer, not this infrastructure repo; this repo only ensures the database and compute are ready.
- The External Secrets Operator (ESO) will be installed into AKS by a separate deployment process; this repo provisions the Workload Identity, federated credential, and Key Vault RBAC assignments required for ESO to function.
