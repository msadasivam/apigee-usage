# Calculating Total API Traffic for an Organization (Apigee Edge & X)

> **Original Work & Article:**  
> This script and documentation are based on and inspired by the original work by **Kurt Kanaskie**:  
> 🔗 [Calculating total API traffic for an organization (Apigee Edge and X)](https://discuss.google.dev/t/calculating-total-api-traffic-for-an-organization-apigee-edge-and-x/99061)

---

## Use Case
As a customer with annual API usage limits, you need to monitor total API usage across the year to compare against entitlements and avoid overage charges.

## Problem
Apigee Edge and Apigee X do not currently offer an out-of-the-box solution to determine overall API traffic usage consolidated across all environments within an organization.

## Solution
Calculate API call volume using the **Apigee Metrics API** across an organization and all of its environments, combining the monthly results to produce the grand total.

### Why Monthly Calls?
The Metrics API time range in **Apigee X** is limited to **92 days** (compared to 365 days in Apigee Edge). Using a monthly time window works seamlessly across both platforms while providing granular monthly details.

---

## How It Works (Pseudo Code)

```text
For an organization:
  1. Get list of environments
  2. For each environment:
       For each month:
         Get API usage stats (sum of message_count)
       Combine to get total usage for the environment
  3. Consolidate to get total usage across all environments in the organization
```

---

## Using `api-usage-org.sh`

The `api-usage-org.sh` script automates these API calls and outputs consolidated usage in JSON format. It supports integer conversion and handles decimal/exponential notation automatically.

### Prerequisites & Syntax

```bash
./api-usage-org.sh [-h|-l|-o|-q|-s|-t|-y]
```

| Option | Description |
| :--- | :--- |
| `-h` | Print help documentation |
| `-l` | Use Legacy Apigee Edge endpoint (`api.enterprise.apigee.com`) |
| `-o <org>` | **Required:** Organization name |
| `-q` | Quiet mode (suppresses progress logs on `stderr`) |
| `-s` | Summary mode (shows total counts without monthly breakdowns) |
| `-t <token>` | **Required:** Bearer access token |
| `-y <year>` | Target year (defaults to the current year) |

---

### Examples

#### Apigee X
```bash
./api-usage-org.sh -o apigeex-org-name -t $(gcloud auth print-access-token) | jq
```

#### Apigee Edge
```bash
./api-usage-org.sh -l -o edge-org-name -t $(get_token) | jq
```

#### Save Output to JSON File
```bash
./api-usage-org.sh -o apigeex-org-name -t $(gcloud auth print-access-token) | jq > usage-report.json
```

---

### Example Output

When run, progress details (`ORG`, `ENVS`, monthly details) are printed to `stderr` unless `-q` is passed. The final consolidated JSON is output to `stdout`:

```bash
$ ./api-usage-org.sh -l -o demo-au06 -t $(get_token) | jq
ORG: demo-au06
ENVS: [ "prod", "dev", "test", "portal" ]
ENV_USAGE: {"name":"prod","months":[45,17,12,29,6,8,4],"total":121}
ENV_USAGE: {"name":"dev","months":[8,24,7,14,3,6,4],"total":66}
ENV_USAGE: {"name":"test","months":[72,78,87,121,73,31,2],"total":464}
ENV_USAGE: {"name":"portal","months":[0,0,0,0,0,0,0],"total":0}
ORG_TOTAL: 651
```

```json
{
  "datetime": "Tue Jul 7 10:28:02 AEST 2026",
  "name": "demo-au06",
  "environments": [
    {
      "name": "prod",
      "months": [45, 17, 12, 29, 6, 8, 4],
      "total": 121
    },
    {
      "name": "dev",
      "months": [8, 24, 7, 14, 3, 6, 4],
      "total": 66
    },
    {
      "name": "test",
      "months": [72, 78, 87, 121, 73, 31, 2],
      "total": 464
    },
    {
      "name": "portal",
      "months": [0, 0, 0, 0, 0, 0, 0],
      "total": 0
    }
  ],
  "total": 651
}
```

---

## Analytics API Limits
Metrics APIs have limits, but they are generally not prohibitive when running monthly queries. For exact quotas and details, refer to:
- [Analytics API limits for Apigee Edge](https://cloud.google.com/apigee/docs/api-platform/analytics/analytics-services-limits)
- [Analytics API limits for Apigee X](https://cloud.google.com/apigee/docs/api-platform/analytics/analytics-services-limits)