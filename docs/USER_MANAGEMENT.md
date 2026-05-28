# User Management Guide

This guide explains how to manage users for both OpenObserve and Arize Phoenix in your self-hosted observability stack.

---

## OpenObserve

**Endpoint:** `https://openobserve.observability.duckdns.org`

### Initial Administrator
The root user for OpenObserve is defined in your `.env` file during the first startup:
*   **Email:** Value of `OPENOBSERVE_ROOT_EMAIL`
*   **Password:** Value of `OPENOBSERVE_ROOT_PASSWORD`

### Creating New Users
1.  **Log in** to the OpenObserve UI using an account with the **Admin** role.
2.  In the left-hand sidebar, click on the **Administration** (gear icon) and select **IAM**.
3.  Click on the **Users** tab.
4.  Click the **Add User** (or **+**) button at the top right.
5.  **Enter User Details:**
    *   **Email:** The user's login ID.
    *   **Name:** The user's display name.
    *   **Password:** A temporary password for the user.
    *   **Role:** Select a role:
        *   **Admin:** Full access to manage users, organizations, and data.
        *   **Member:** Can query and view data but cannot access administrative settings.
6.  Click **Submit** to create the account.

---

## Arize Phoenix

**Endpoint:** `https://phoenix.observability.duckdns.org`

### Initial Administrator
The default administrator account is created based on your `.env` settings:
*   **Email:** `admin@localhost` (default)
*   **Password:** Value of `PHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD`

### Creating New Users
1.  **Log in** to the Phoenix UI with an **Admin** account.
2.  Click on the **Settings** (gear icon) in the left-hand navigation bar.
3.  Locate the **User Management** section.
4.  Click the **Add User** button.
5.  **Enter User Details:**
    *   **Name:** Full name of the user.
    *   **Email:** The user's login ID.
    *   **Role:** Select a role:
        *   **Admin:** Full control over users, API keys, and settings.
        *   **Member:** Can manage traces, experiments, and datasets.
        *   **Viewer:** Read-only access to existing data.
6.  Click **Add** or **Invite**.

### Password Management Note
If you have **not** configured an SMTP server in Phoenix:
*   Users will not receive invitation emails.
*   The Admin can **Reset Password** for users from the same **Settings > User Management** screen and provide the temporary password to the user manually.

---

## Best Practices
*   **Principle of Least Privilege:** Assign the `Member` or `Viewer` role by default; only grant `Admin` access to those who need to manage the platform itself.
*   **Strong Passwords:** Ensure all users set strong, unique passwords upon their first login.
*   **API Keys:** For automated ingestion or programmatic access, prefer using **API Keys** (found in Settings for both services) instead of sharing user credentials.
