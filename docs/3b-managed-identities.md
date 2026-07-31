CST8918 - DevOps: Infrastructure as Code
Prof. Robert McKenney

# Lab 12: Terraform CI/CD on Azure with GitHub Actions

## 3b. Managed Identity substitution for Azure AD App Registrations

The Algonquin student Azure tenant blocks `az ad app create` for students
(`Insufficient privileges to complete the operation`), so we could not create Azure AD App
Registrations + Service Principals as described in [`3-azure-credentials.md`](3-azure-credentials.md).

Instead we used **User-Assigned Managed Identities**, which achieve the same OIDC federation with
GitHub Actions but only require Azure RBAC (Contributor/Owner on the resource group), not a
directory-level role.

### Commands used

```bash
export subscriptionId=$(az account show --query id -o tsv)
export tenantId=$(az account show --query tenantId -o tsv)
export resourceGroupName=$(terraform output -raw resource_group_name) # from infra/tf-app

# Read/write identity (contributor) - used by the production deploy workflow
az identity create --name hich0005-githubactions-rw --resource-group $resourceGroupName

az role assignment create \
  --role contributor \
  --assignee-object-id <rw principalId> \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/$subscriptionId/resourceGroups/$resourceGroupName

az identity federated-credential create \
  --name production-deploy \
  --identity-name hich0005-githubactions-rw \
  --resource-group $resourceGroupName \
  --issuer https://token.actions.githubusercontent.com \
  --subject "repo:YoussufAlgonquin@255024064/Lab_A11@1317798799:environment:production" \
  --audiences "api://AzureADTokenExchange"

# Read-only identity (reader) - used by PR / branch push workflows
az identity create --name hich0005-githubactions-r --resource-group $resourceGroupName

az role assignment create \
  --role reader \
  --assignee-object-id <r principalId> \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/$subscriptionId/resourceGroups/$resourceGroupName

az identity federated-credential create \
  --name pull-request \
  --identity-name hich0005-githubactions-r \
  --resource-group $resourceGroupName \
  --issuer https://token.actions.githubusercontent.com \
  --subject "repo:YoussufAlgonquin@255024064/Lab_A11@1317798799:pull_request" \
  --audiences "api://AzureADTokenExchange"

az identity federated-credential create \
  --name branch-main \
  --identity-name hich0005-githubactions-r \
  --resource-group $resourceGroupName \
  --issuer https://token.actions.githubusercontent.com \
  --subject "repo:YoussufAlgonquin@255024064/Lab_A11@1317798799:ref:refs/heads/main" \
  --audiences "api://AzureADTokenExchange"
```

> [!NOTE]
> Running these commands in Git Bash on Windows requires `MSYS_NO_PATHCONV=1` prefixed to the
> `az role assignment create` command, otherwise Git Bash rewrites the leading `/subscriptions/...`
> path into a Windows filesystem path and the request fails with `MissingSubscription`.

> [!NOTE]
> **Two more corrections discovered while first running the workflows on a live PR:**
>
> 1. **Subject format includes immutable owner/repo IDs.** GitHub now defaults new
>    repositories to `repo:{owner}@{owner_id}/{repo}@{repo_id}:...` subject claims (a hardening
>    against repo-rename/transfer OIDC hijacking), not the plain `repo:{owner}/{repo}:...` format
>    the original lab instructions assume. Confirm the exact prefix for your repo with:
>    `gh api repos/<owner>/<repo>/actions/oidc/customization/sub`. All three federated credentials
>    above must use that exact prefix.
> 2. **Branch-push subject is `ref:refs/heads/<branch>`, not `branch:<branch>`.** The lab's
>    `branch-main.json` example (`repo:...:branch:main`) does not match any subject GitHub Actions
>    actually issues. The correct claim for a push to `main` is
>    `repo:...:ref:refs/heads/main`.

### Resulting resources (already created in Azure for this lab)

| Identity | Resource name | Role | Scope | Used for |
|---|---|---|---|---|
| Read/write | `hich0005-githubactions-rw` | Contributor | `hich0005-a12-rg` | `production` environment deploys |
| Read-only | `hich0005-githubactions-r` | Reader | `hich0005-a12-rg` | PR / branch-push plan-only workflows |

Federated credentials attached:

| Identity | Credential name | Subject |
|---|---|---|
| `hich0005-githubactions-rw` | `production-deploy` | `repo:YoussufAlgonquin@255024064/Lab_A11@1317798799:environment:production` |
| `hich0005-githubactions-r` | `pull-request` | `repo:YoussufAlgonquin@255024064/Lab_A11@1317798799:pull_request` |
| `hich0005-githubactions-r` | `branch-main` | `repo:YoussufAlgonquin@255024064/Lab_A11@1317798799:ref:refs/heads/main` |

### GitHub secrets mapping

Use the managed identity's `clientId` exactly where the lab instructions say to use the Azure AD
app's `appId`:

**Repository level:**
- `AZURE_TENANT_ID` = tenant ID
- `AZURE_SUBSCRIPTION_ID` = subscription ID
- `AZURE_CLIENT_ID` = `clientId` of `hich0005-githubactions-r` (reader identity)
- `ARM_ACCESS_KEY` = primary access key of the `tf-backend` storage account

**`production` environment level:**
- `AZURE_CLIENT_ID` = `clientId` of `hich0005-githubactions-rw` (contributor identity) — overrides
  the repository-level value for jobs running in the `production` environment.

Retrieve the client IDs at any time with:

```bash
az identity show --name hich0005-githubactions-r  --resource-group $resourceGroupName --query clientId -o tsv
az identity show --name hich0005-githubactions-rw --resource-group $resourceGroupName --query clientId -o tsv
```
