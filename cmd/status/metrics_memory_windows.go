//go:build windows

package main

import (
	"context"
	"strconv"
	"strings"
	"time"
)

// getWindowsMemoryDetails collects Windows-specific memory metrics
func getWindowsMemoryDetails() (committed, committedLimit, pagedPool, nonPagedPool uint64) {
	if !commandExists("powershell") {
		return 0, 0, 0, 0
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// Query Windows performance counters for detailed memory info
	psCmd := `
$os = Get-WmiObject -Class Win32_OperatingSystem
$perf = Get-WmiObject -Class Win32_PerfFormattedData_PerfOS_Memory

# Committed bytes (virtual memory in use)
$committed = [uint64]$os.TotalVirtualMemorySize - [uint64]$os.FreeVirtualMemory
$committedLimit = [uint64]$os.TotalVirtualMemorySize

# Pool memory (in bytes)
$pagedPool = [uint64]$perf.PoolPagedBytes
$nonPagedPool = [uint64]$perf.PoolNonpagedBytes

# Output as simple key=value pairs (easier to parse than JSON)
Write-Output "Committed=$committed"
Write-Output "CommittedLimit=$committedLimit"
Write-Output "PagedPool=$pagedPool"
Write-Output "NonPagedPool=$nonPagedPool"
`

	out, err := runCmd(ctx, "powershell", "-NoProfile", "-NonInteractive", "-Command", psCmd)
	if err != nil {
		return 0, 0, 0, 0
	}

	// Parse output
	lines := strings.Split(out, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if key, value, found := strings.Cut(line, "="); found {
			val, _ := strconv.ParseUint(strings.TrimSpace(value), 10, 64)
			switch strings.TrimSpace(key) {
			case "Committed":
				// Convert from KB to bytes
				committed = val * 1024
			case "CommittedLimit":
				// Convert from KB to bytes
				committedLimit = val * 1024
			case "PagedPool":
				pagedPool = val
			case "NonPagedPool":
				nonPagedPool = val
			}
		}
	}

	return committed, committedLimit, pagedPool, nonPagedPool
}
