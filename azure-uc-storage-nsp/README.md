# Azure UC external location on NSP-protected storage

Terraform that creates a network-locked ADLS Gen2 account and registers it in
Unity Catalog:

1. **Access Connector for Azure Databricks** (system-assigned managed identity)
2. **ADLS Gen2 storage account + container**: public network access disabled,
   shared-key auth off, TLS 1.2, OAuth by default
3. **NSP association**: the account joins an existing network security
   perimeter profile in Learning (Transition) mode, optionally with an
   `AzureDatabricksServerless` inbound rule
4. **RBAC** for the connector's identity: `Storage Blob Data Contributor`, plus
   the file-events roles (below)
5. **UC storage credential** (managed identity) and **external location**
   (`abfss://<container>@<account>.dfs.core.windows.net/<path>`)

## Prerequisites

**Service principal** (used for both the Azure and Databricks providers):

| Where | Needs |
|---|---|
| Resource group | `Contributor` + `User Access Administrator` (or `Owner`) to create resources and role assignments |
| NSP resource group | Rights to create associations / access rules on the NSP (e.g. `Network Contributor`) |
| Databricks workspace | Added to the workspace (an admin is simplest) |
| UC metastore | `CREATE STORAGE CREDENTIAL` and `CREATE EXTERNAL LOCATION` (metastore admins have both) |

**Environment:**

- The workspace is Unity Catalog-enabled and in the **same region** as the
  storage account and the NSP. The `AzureDatabricksServerless` tag only covers
  storage in the workspace's region; the plan fails early if the NSP region
  doesn't match.
- The NSP profile already allows `AzureDatabricksServerless.<Region>` inbound,
  or you set `nsp_serverless_service_tags` so this config adds the rule.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in
export TF_VAR_client_secret='<sp-secret>'       # keep the secret out of tfvars
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

Verify from a **serverless** notebook or SQL warehouse:

```sql
LIST 'abfss://<container>@<account>.dfs.core.windows.net/';
```

## Design notes

- **Public network access is Disabled, not "Secured by Perimeter".**
  Databricks docs warn that "Secured by Perimeter" breaks serverless access
  (`PERMISSION_DENIED … user delegation key`). Disabled + NSP in Learning mode
  admits serverless through the NSP's service-tag rule.
- **Learning = Transition.** Learning is the API name for the portal's
  Transition mode. Databricks recommends staying there: Enforced also blocks
  every other service the storage firewall allows that isn't in the NSP.
- **Trusted-services bypass (`allow_trusted_azure_services`, default on).**
  Set together with Disabled in one ARM call. It's still enforced in Disabled
  mode even though the portal greys out the checkbox, and in testing it admits
  Databricks serverless/UC traffic. **File events require it**; the config
  refuses to enable file events with the bypass off.
- **File events (`enable_file_events`, default on)** add `Storage Queue Data
  Contributor` and `Storage Account Contributor` on the account, and
  `EventGrid EventSubscription Contributor` on the resource group, so UC can create the
  Event Grid subscription and queue (Automatic mode).
- **Terraform never touches the storage data plane.** With public access
  disabled, the blob endpoint is unreachable from outside the perimeter, so
  the provider runs with `storage.data_plane_available = false` and the
  container is created through ARM.
- **RBAC propagation:** a 120 s `time_sleep` sits between the role assignments
  and the UC resources so the credential and external location validate on the
  first apply.
- **Classic compute isn't covered.** VNet-injected classic clusters can't
  reach a Disabled account through service endpoints. Add a private endpoint
  (`dfs`, zone `privatelink.dfs.core.windows.net`) if classic clusters need
  this location.

## Not included

- Grants on the external location (`READ FILES`, `CREATE EXTERNAL TABLE`, …)
  and workspace bindings. Add `databricks_grants` / `isolation_mode` as needed.
- Private endpoints for classic compute.
