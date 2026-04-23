# Compliance Controls Matrix — CT104 (Sonarr)
Mapping of existing security controls to CIS Ubuntu 22.04 L2 Benchmark v1.0.0

Status legend: [Pass] = Fully compliant  [Fail] = Not compliant  [Partial] = Partially implemented  [Review] = Needs investigation

| CIS Ref | Control Description | Status | Evidence / Notes |
|---------|---------------------|--------|-------------------|
| **1.6.2.1** | Ensure AppArmor is installed and enforcing | **[Partial]** | `apparmor` module loaded; 131 profiles loaded; 32 profiles in enforce mode, 23 in complain mode; no currently confined processes |
| **1.8** | Ensure automatic security updates are enabled | **[Pass]** | `unattended-upgrades` installed and active; Sonarr APT repo deprecated, removed |
| **2.1.1** | Ensure unnecessary services are disabled / removed | **[Fail]** | `postfix@-.service` running (MTA not required for Sonarr) |
| **2.1.2** | Ensure X Window System is not installed | **[Pass]** | `xserver` packages not found |
| **2.1.3** | Ensure Avahi Server is not installed | **[Pass]** | `avahi-daemon` not found |
| **2.1.4** | Ensure CUPS is not installed | **[Pass]** | `cups` not found |
| **2.1.5** | Ensure DHCP Server is not installed | **[Pass]** | `dhcp` server not found |
| **2.1.6** | Ensure LDAP server is not installed | **[Pass]** | `slapd` not found |
| **2.1.7** | Ensure NFS is not installed | **[Pass]** | NFS packages not found |
| **2.1.8** | Ensure DNS Server is not installed | **[Pass]** | `bind9` full server not installed; only libraries present |
| **2.1.9** | Ensure FTP Server is not installed | **[Pass]** | `vsftpd` not found |
| **2.1.10** | Ensure HTTP server is not installed | **[Pass]** | `apache2` not found |
| **2.1.11** | Ensure IMAP/POP3 server is not installed | **[Pass]** | `dovecot` not found |
| **2.1.12** | Ensure Samba is not installed | **[Pass]** | `samba` not found |
| **2.1.13** | Ensure HTTP Proxy is not installed | **[Pass]** | No proxy packages found |
| **2.1.14** | Ensure SNMP Server is not installed | **[Pass]** | `snmpd` not found |
| **2.1.17** | Ensure NIS Server is not installed | **[Pass]** | `nis` not found |
| **2.1.18** | Ensure telnet server is not installed | **[Pass]** | `telnetd` not found |
| **2.1.19** | Ensure talk server is not installed | **[Pass]** | `talk` not found |
| **2.1.21** | Ensure TFTP server is not installed | **[Pass]** | `tftp` not found |
| **2.1.22** | Ensure NIS Client is not installed | **[Pass]** | `ypbind` not found |
| **2.1.23** | Ensure RSH client is not installed | **[Pass]** | `rsh-client` not found |
| **2.1.24** | Ensure RCP is not installed | **[Pass]** | `rcp` not found |
| **2.1.25** | Ensure rlogin is not installed | **[Pass]** | `rlogin` not found |
| **2.1.26** | Ensure rexec is not installed | **[Pass]** | `rexec` not found |
| **3.1.1** | Ensure IP forwarding is disabled | **[Pass]** | `net.ipv4.ip_forward = 0` |
| **3.1.2** | Ensure packet redirect sending is disabled | **[Fail]** | `send_redirects = 1` (CIS expects 0) |
| **3.1.3** | Ensure source routed packets are not accepted | **[Pass]** | `accept_source_route = 0` |
| **3.1.4** | Ensure ICMP redirects are not accepted | **[Pass]** | `accept_redirects = 0` |
| **3.1.5** | Ensure secure ICMP redirects are not accepted | **[Fail]** | `secure_redirects = 1` (CIS expects 0) |
| **3.1.6** | Ensure suspicious packets are logged | **[Fail]** | `log_martians = 0` (CIS expects 1) |
| **3.1.7** | Ensure broadcast ICMP requests are ignored | **[Pass]** | `icmp_echo_ignore_broadcasts = 1` |
| **3.1.8** | Ensure bogus ICMP responses are ignored | **[Pass]** | `icmp_ignore_bogus_error_responses = 1` |
| **3.1.9** | Ensure Reverse Path Filtering is enabled | **[Pass]** | `rp_filter = 2` (strict mode) |
| **3.1.10** | Ensure TCP SYN Cookies are enabled | **[Pass]** | `tcp_syncookies = 1` |
| **3.2.1** | Ensure IPv6 router advertisements are not accepted | **[Pass]** | `accept_redirects = 0` for all and default |
| **3.5.1.1** | Ensure a software firewall is configured | **[Pass]** | UFW active; default deny incoming; port 22 restricted to Proxmox host; port 8989 restricted to LAN subnet |
| **4.1.1.1** | Ensure auditd is installed | **[Fail]** | `auditd` installed but fails to start — audit kernel subsystem not available on Proxmox host; requires host-level kernel configuration beyond container scope. | 
| **4.1.2** | Ensure logrotate is configured | **[Pass]** | `logrotate` installed; config covers `/var/log/syslog` and `/var/log/auth.log` |
| **5.1.1** | Ensure password expiration is 365 days or less | **[Fail]** | `PASS_MAX_DAYS = 99999` |
| **5.1.2** | Ensure minimum days between password changes is 1 or more | **[Fail]** | `PASS_MIN_DAYS = 0` |
| **5.1.3** | Ensure password expiration warning days is 7 or more | **[Pass]** | `PASS_WARN_AGE = 7` |
| **5.1.4** | Ensure strong password hashing algorithm is used | **[Pass]** | `ENCRYPT_METHOD = SHA512` |
| **5.1.5** | Ensure inactive password lock is 30 days or less | **[Fail]** | `INACTIVE = -1` (disabled) |
| **5.1.6** | Ensure system accounts are secured | **[Pass]** | All system accounts use `nologin`; all locked with `!` |
| **5.1.7** | Ensure no duplicate UIDs exist | **[Pass]** | No duplicate UIDs |
| **5.1.8** | Ensure no duplicate GIDs exist | **[Pass]** | No duplicate GIDs |
| **5.1.9** | Ensure root is the only UID 0 account | **[Pass]** | Only `root` has UID 0 |
| **5.2.1** | Ensure SSH is configured correctly | **[Fail]** | `passwordauthentication = yes`; `maxauthtries = 6` |
| **5.4.2** | Ensure permissions on /etc/passwd are configured | **[Pass]** | `644` |
| **5.4.3** | Ensure permissions on /etc/shadow are configured | **[Pass]** | `640` |
| **5.4.4** | Ensure permissions on /etc/group are configured | **[Pass]** | `644` |
| **5.4.5** | Ensure permissions on /etc/gshadow are configured | **[Pass]** | `640` |
| **5.4.6** | Ensure permissions on /etc/sudoers are configured | **[Pass]** | `440` |
| **5.4.7** | Ensure permissions on /etc/crontab are configured | **[Fail]** | `644` (CIS expects 600) |
| **5.4.8** | Ensure no world-writable files exist | **[Pass]** | No world‑writable files found |
| **5.4.9** | Ensure no world-writable directories exist without sticky bit | **[Pass]** | No directories without sticky bit found |
| **5.5.1** | Ensure root's PATH integrity | **[Fail]** | No empty/dot entries; but `/sbin` and `/bin` are world‑writable (777) |
| **5.6.1** | Ensure default user umask is 027 or more restrictive | **[Fail]** | `umask = 0022` |
| **5.6.2** | Ensure shell timeout is configured | **[Fail]** | `TMOUT` not set |

