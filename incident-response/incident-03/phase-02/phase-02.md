# Phase 2: Hybrid VPN & SIEM Agent Deployment
**Incident:** Incident-03 – Cloud Workload Compromise & DNS Exfiltration Detection  
**Phase:** 2 of 4  
**Date:** 2026-06-02  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Closed – Tailscale tunnel established, Wazuh agent active on EC2

## Executive Summary

A secure overlay network was established between the AWS EC2 instance (`soc-cloud-victim-03`) and the on‑prem Wazuh manager using Tailscale (zero‑config VPN). Subnet routing allowed the EC2 instance to reach the manager at its private IP `172.16.5.20`. The Wazuh agent was installed on EC2, configured to communicate over the Tailscale tunnel, and successfully connected to the manager. Logs from the EC2 instance are now being collected and forwarded to the central SIEM.

## Severity & Impact

**Severity:** N/A (infrastructure setup)  
**Impact:** Successful hybrid integration enables monitoring of cloud workload for the remainder of the simulation. Detection of attacker actions (DNS tunneling, process execution) is now possible.

## Scenario Objective

Establish a secure, monitored connection between the cloud workload and on‑prem SIEM to enable detection of malicious activity in later phases.

## Environment Overview

| System | Role | Tailscale IP |
|--------|------|---------------|
| Windows (Wazuh manager) | SIEM Manager | `100.75.74.37` |
| EC2 (`soc-cloud-victim-03`) | Attacker foothold / monitored workload | `100.120.147.60` |

Subnet routing enabled on Windows: `172.16.5.0/24` → reachable via Tailscale from EC2.

## Implementation Steps

### Step 1: Tailscale Installation
- Tailscale installed on Windows host and EC2 instance.
- Both machines authenticated to the same Tailscale account.
- Direct connectivity verified: `tailscale ping` latency ~27ms.

### Step 2: Subnet Routing (Windows)
- Windows host configured with `tailscale up --advertise-routes=172.16.5.0/24`.
- Routes approved in Tailscale admin console.
- EC2 instance could then ping `172.16.5.20` (Wazuh manager IP) over the encrypted tunnel.

### Step 3: Wazuh Agent Installation on EC2
- Wazuh agent package (`4.11.0`) downloaded and installed.
- Agent configured to connect to manager at `172.16.5.20` (port 1514/tcp).
- Agent successfully enrolled and became active within 60 seconds.

## MITRE ATT&CK Mapping

Not applicable for infrastructure setup phase.

## Detection & Telemetry

The Wazuh agent on EC2 is now forwarding:

- System logs (`/var/log/syslog`, journald)
- Process execution events (via auditd or default monitoring)
- Authentication logs (SSH, sudo)
- Package management events (dpkg)

Example events captured (see artifacts/`wazuh-events.csv`):

- `sudo` executions
- `dpkg` package installations (ruby, git, gcc, dnscat2 prerequisites)
- PAM login sessions

## Timeline of Events

| Time (UTC) | Event |
|------------|-------|
| 2026-06-02 11:00:00 | Tailscale installed on Windows and EC2 |
| 2026-06-02 11:05:00 | Subnet routing enabled and approved |
| 2026-06-02 11:10:00 | Wazuh agent installed on EC2 |
| 2026-06-02 11:12:00 | Agent connects to manager (TCP 1514) |
| 2026-06-02 11:15:00 | First test events forwarded |

## Artifacts

- [tailscale-status-ec2.png](artifacts/tailscale-status-ec2.png) – Tailscale status on EC2.
- [tailscale-status-windows.png](artifacts/tailscale-status-windows.png) – Tailscale status on Windows.
- [tailscale-ping.png](artifacts/tailscale-ping.png) – Direct latency between nodes.
- [subnet-route-verified.png](artifacts/subnet-route-verified.png) – Ping to Wazuh manager `172.16.5.20` success.
- [agent-active-cli.png](artifacts/agent-active-cli.png) – Wazuh agent service status.
- [agent-logs-sample.png](artifacts/agent-logs-sample.png) – Agent log showing connection.
- [wazuh-events.csv](artifacts/wazuh-events.csv) – Sample events from EC2 agent.

## Key Findings & Lessons Learned

1. **Tailscale subnet routing** eliminates the need for complex port forwarding and works seamlessly across NAT. The Windows host can advertise its local subnet, making `172.16.5.20` reachable from EC2 over an encrypted tunnel.

2. **Hybrid monitoring** is achievable without public IP exposure. The EC2 agent communicates over the Tailscale tunnel, and all traffic remains within the VPN.

3. **Wazuh agent works reliably** across the Tailscale network. The agent’s lightweight protocol (TCP 1514) handles latency well (observed ping ~27ms).

4. **Dashboard API errors** (timeout connecting to indexer) do not affect agent log collection. Agents continue to forward logs, and alerts are still generated.

## Next Phase

Proceed to **Phase 03**: DNS tunneling simulation on EC2, execution of `dnscat2` to generate suspicious DNS patterns, and creation of custom Wazuh detection rules.
