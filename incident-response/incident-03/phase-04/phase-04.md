# Incident Response Playbook: Cloud Workload Compromise & DNS Exfiltration
**Incident ID:** INC-03  
**Date of Simulation:** 2026-06-02  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Finalized – Full kill chain detected and contained

## Executive Summary

A simulated attacker gained initial access using a compromised AWS IAM user (`employee-user`), performed cloud reconnaissance (S3, EC2), attempted to create a malicious email forwarding rule, and established a DNS tunneling channel on an EC2 instance. The hybrid SOC environment (AWS + on‑prem Wazuh) successfully detected:

- CloudTrail API calls from an untrusted source (reconnaissance).
- A failed `CreateInboxRule` API attempt (simulated email exfiltration setup).
- Execution of `dnscat2` (DNS tunneling tool) on the EC2 workload.

A custom Wazuh rule (ID 100200) was created to alert on DNS tunneling tools. The incident was contained by isolating the EC2 instance and revoking the compromised IAM keys.

## Incident Overview

| Attribute | Details |
|-----------|---------|
| **Attack Vector** | Compromised IAM user keys (`employee-user`) |
| **Initial Access** | Reused or leaked access keys (simulated) |
| **Target Environment** | AWS (S3, EC2) + On‑prem Wazuh SIEM |
| **Attacker Goal** | Reconnaissance → Establish DNS exfiltration channel |
| **Detection Method** | CloudTrail management events + Wazuh custom rule on process execution |

## MITRE ATT&CK Mapping

| Tactic | Technique | ID | Phase Observed |
|--------|-----------|-----|----------------|
| Initial Access | Valid Cloud Account (IAM user) | T1078.004 | Phase 1 |
| Discovery | Cloud Infrastructure Discovery | T1530 | Phase 1 |
| Collection | Email Forwarding Rule | T1114.003 | Phase 1 (simulated) |
| Defense Evasion | DNS Tunneling | T1572 | Phase 3 |
| Exfiltration | Exfiltration Over Alternative Protocol | T1048 | Phase 3 (attempted) |

## Detection & Alerting

### CloudTrail Alerts (Phase 1)
- **`ListBuckets`** – IAM user `employee-user` enumerated S3 buckets.
- **`DescribeInstances`** – EC2 instance inventory.
- **`CreateInboxRule`** (failed) – Attempt to set email forwarding (simulated).

### Wazuh Custom Rule (Phase 3)
- **Rule ID:** 100200  
- **Severity:** Level 10  
- **Trigger:** Process names `dnscat`, `iodine`, `iodined`  
- **Description:** DNS tunneling tool executed on `$(agent.name)`

### Expected Wazuh Alert Example
```json
{
  "rule": { "id": 100200, "level": 10 },
  "description": "DNS tunneling tool executed on soc-cloud-victim-03",
  "agent": { "name": "soc-cloud-victim-03" },
  "data": { "process": "dnscat2" }
}
```

## Analysis Steps (for SOC Analyst)

1. **Verify the alert** – Confirm that rule `100200` triggered on agent `soc-cloud-victim-03`.
2. **Correlate with CloudTrail** – Check if `employee-user` showed unusual API activity (e.g., `ListBuckets`, `DescribeInstances`) within the same timeframe.
3. **Review process tree** – On EC2, run `ps aux | grep dnscat` to confirm active tunnel.
4. **Check network connections** – `ss -tunap | grep 53` for outbound DNS traffic from unusual processes.
5. **Examine DNS logs** – Look for high‑volume, long subdomain queries to suspicious domains (if Route53 logging enabled).
6. **Assess IAM permissions** – Determine what `employee-user` could access (S3, EC2 read‑only).

## Containment

### Immediate Actions (within 15 minutes)
1. **Isolate EC2 instance** – Apply a security group denying all outbound traffic except to the SIEM and essential services.
   ```bash
   aws ec2 modify-instance-attribute --instance-id i-03e789924c3b098d5 --groups sg-isolated
2. **Revoke IAM user keys** - Disable `employee-user` access keys in AWS Console.
   ```bash
   aws iam update-access-key --access-key-id AKIA4NYWYJLQ45CIAX2K --status Inactive
   ```
3. **Kill malicious processes** - On EC2: `sudo pkill -f dnscat`
4. **Block DNS tunneling domain** - Add `test.example.com` to corporate DNS blocklist.

### Long-Term Containment
1. **Rotate all IAM credentials** for any user that interacted with `employee-user`
2. **Enforce MFA** for all IAM users, especially `employee-user`

## Eradication

1. **Remove DNS tunneling tools** – On EC2: `sudo apt remove dnscat2 iodine --purge`
2. **Clean up IAM user** – Delete access keys, remove unnecessary policies (`ReadOnlyAccess` should be replaced with least‑privilege).
3. **Review and delete malicious email rules** – If any were created (simulated), remove them via WorkMail console.
4. **Restore EC2 from clean snapshot** – If persistence is suspected, terminate and rebuild the instance.

## Recovery

1. **Restart EC2 instance** (or launch replacement) with hardened configuration:
   - Install Wazuh agent (already present).
   - Limit outbound DNS to authorized resolvers.
   - Enable auditd for process monitoring.
2. **Re‑enable necessary outbound traffic** (restore original security group rules).
3. **Monitor for 48 hours** – Watch for recurrence of rule `100200` or unusual API calls.
4. **Update IAM policies** – Replace `ReadOnlyAccess` with resource‑specific read permissions.

## Lessons Learned

1. **CloudTrail management events** are sufficient to detect reconnaissance and suspicious API attempts – no need for GuardDuty in a small lab.

2. **Custom Wazuh rules** for process names (e.g., `dnscat`) provide high‑fidelity detection for known tunneling tools. Rule syntax must use `<id>` inside `<mitre>`, not `<technique>`.

3. **Auditd integration** is critical for capturing short‑lived processes. Without it, Wazuh may miss process execution.

4. **Hybrid monitoring** over Tailscale VPN works reliably. Subnet routing eliminates the need for complex port forwarding.

5. **Documentation of constraints** (e.g., WorkMail free tier) is acceptable when a representative log is provided – it shows real‑world adaptation.

6. **Tailscale is a practical alternative** to traditional VPNs for connecting cloud workloads to on‑prem SIEMs.

## Recommendations for Improvement

| Area | Recommendation | Priority |
|------|----------------|----------|
| IAM | Enforce MFA for all users; rotate keys every 90 days | High |
| Monitoring | Enable CloudTrail data events for S3 to detect data exfiltration | Medium |
| DNS | Implement Route53 Resolver Query Logging (or equivalent) to capture tunneling patterns | Medium |
| Alerting | Tune Wazuh rule `100200` to alert on any outbound DNS tool execution (including `dig`, `nslookup` bursts) | Low |
| Recovery | Automate EC2 isolation via AWS Lambda + GuardDuty findings | Low |

## Artifacts & References

### From Phase 1
- [CloudTrail Events](../phase-01/artifacts/cloudtrail-events.png)
- [IAM User Policies](../phase-01/artifacts/iam-user-policies.png)
- [Simulated WorkMail API Failure](../phase-01/artifacts/workmail-api-failure.json)

### From Phase 2
- [Tailscale Status (EC2)](../phase-02/artifacts/tailscale-status-ec2.png)
- [Subnet Route Verified](../phase-02/artifacts/subnet-route-verified.png)
- [Wazuh Agent Active](../phase-02/artifacts/agent-active-cli.png)

### From Phase 3
- [dnscat2 Execution](../phase-03/artifacts/dnscat2-execution.png)
- [Custom Wazuh Rule](../phase-03/artifacts/custom-rule.png)
- [Auditd Process Log](../phase-03/artifacts/process-audit-logs.png)

### Custom Wazuh Rule (ID 100200)
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
