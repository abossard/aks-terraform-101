# 🗄️ SQL Database Azure AD Identity Management

## Overview

This configuration creates and manages Azure AD identities for SQL Database access using both the `azurerm` provider and the specialized `sqlsso` provider for SQL Server Azure AD account management.

## 🆔 Identities Created

### 1. **Current User Admin** (Auto-detected)
- **Purpose**: Primary SQL Server administrator
- **Identity**: Auto-detected from current Azure AD user
- **Permissions**: `sysadmin` role
- **Access**: Full administrative access

### 2. **Application Identity** (Managed Identity)
- **Purpose**: Application-level database access
- **Identity**: `id-sql-app-{env}-{location}-001`
- **Permissions**: `db_datareader`, `db_datawriter`, `db_ddladmin`
- **Access**: Read/write data, modify schema (database-scoped)

## 🔐 Security Features

### **Azure AD Authentication**
- No SQL authentication credentials needed
- Token-based authentication via Azure AD
- Integrated with AKS Workload Identity

### **Least Privilege Access**
- Application identity has only necessary database permissions
- No server-level administrative rights for application
- Scoped to specific database, not entire server

### **Workload Identity Integration**
- Federated identity credential created for Kubernetes
- Service account: `sql-identity-sa` in app namespace
- No secrets or connection strings with passwords

## 📋 Resources Created

### **Managed Identities**
```terraform
azurerm_user_assigned_identity.sql_app_identity
```

### **SQL Server AAD Accounts**
```terraform
sqlsso_mssql_server_aad_account.current_user_admin    # Current user as admin
sqlsso_mssql_server_aad_account.app_identity          # Application identity
```

### **Key Vault Secrets**
```terraform
sql-app-identity-client-id              # Application identity client ID
database-connection-app-identity        # Connection string for app identity
```

### **Workload Identity**
```terraform
azurerm_federated_identity_credential.sql_app_identity
```

## 🚀 Usage

### **1. For Applications in Kubernetes**

Create a service account and use workload identity:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sql-identity-sa
  namespace: aks-app
  annotations:
    azure.workload.identity/client-id: "<sql_app_identity_client_id>"
spec: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: sql-identity-sa
      containers:
      - name: my-app
        env:
        - name: CONNECTION_STRING
          value: "Server=<sql_server_fqdn>;Database=<database_name>;Authentication=Active Directory Managed Identity;User Id=<sql_app_identity_client_id>;"
```

### **2. For Local Development/Testing**

Use the current user's identity (already configured as SQL admin):

```bash
# Get connection details
terraform output sql_server_fqdn
terraform output sql_database_name

# Connect using Azure CLI authentication
az login
sqlcmd -S <sql_server_fqdn> -d <database_name> -G -l 30
```

### **3. Connection Strings**

**Application Identity (from Key Vault)**:
```
Server=<sql_server_fqdn>;Database=<database_name>;Authentication=Active Directory Managed Identity;User Id=<client_id>;
```

**Current User (development)**:
```
Server=<sql_server_fqdn>;Database=<database_name>;Authentication=Active Directory Interactive;
```

## 🔧 Permissions Breakdown

### **Current User Admin**
- **Role**: `sysadmin`
- **Scope**: Server-level
- **Permissions**: Full control over SQL Server instance

### **Application Identity**
- **Role**: `db_datareader` - Read all data from database
- **Role**: `db_datawriter` - Insert, update, delete data
- **Role**: `db_ddladmin` - Create/modify/drop database objects
- **Scope**: Database-level only

## 🛡️ Security Benefits

### **✅ No Passwords**
- All authentication via Azure AD tokens
- No connection strings with embedded passwords
- Automatic token rotation

### **✅ Least Privilege**
- Application gets only necessary permissions
- Database-scoped permissions, not server-level
- Separate identities for different purposes

### **✅ Audit Trail**
- All database access logged with Azure AD identity
- Clear attribution of database operations
- Integrated with Azure AD audit logs

### **✅ Token-Based Security**
- Short-lived access tokens
- Automatic renewal via workload identity
- No long-term secrets to manage

## 📊 Monitoring

### **Key Vault Access**
Monitor access to SQL identity secrets:
- `sql-app-identity-client-id`
- `database-connection-app-identity`

### **SQL Server Audit**
Monitor database access patterns:
- Failed authentication attempts
- Privilege escalation attempts
- Unusual query patterns

## 🔄 Lifecycle Management

### **Identity Rotation**
- Managed identities don't require password rotation
- Tokens automatically refreshed
- No manual intervention needed

### **Permission Updates**
Update permissions via Terraform:
```terraform
# Modify roles in sql-identities.tf
roles = [
  "db_datareader",
  "db_datawriter", 
  "db_ddladmin",
  "db_owner"  # Add new permission
]
```

### **Adding New Identities**
Follow the pattern in `sql-identities.tf` to create additional application identities with specific permissions.

## 🎯 Best Practices

1. **Use application identity for applications** - not the admin account
2. **Monitor Key Vault access** for client ID retrieval
3. **Implement connection pooling** to minimize token requests
4. **Use database-scoped permissions** when possible
5. **Audit SQL access regularly** through Azure AD logs

This setup provides enterprise-grade SQL Database access with Azure AD integration and zero password management! 🔐
