# huawei-ce-nagios-check
Huawei cloudengine switch check.

Reqs: snmp
Checks global (probablly all hua switches and routers) :
- PSU (Active/Not active)
- Fans (Active/Not active)
- Temperature (Threshold set manually in variable)

Custom check:
- CE12800 : Cards (MPU,SFU,CMU,Line)
- CE6851 : Main unit

Usage:
  check-huawei-switch.sh [HOSTNAME]

