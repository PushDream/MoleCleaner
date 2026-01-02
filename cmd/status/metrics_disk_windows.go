//go:build windows

package main

import (
	"context"
	"runtime"
	"sort"
	"strings"
	"time"

	"github.com/shirou/gopsutil/v3/disk"
)

var skipDiskMounts = map[string]bool{
	// Windows reserved mounts can be added here if needed
}

func collectDisks() ([]DiskStatus, error) {
	partitions, err := disk.Partitions(false)
	if err != nil {
		return nil, err
	}

	var (
		disks      []DiskStatus
		seenDevice = make(map[string]bool)
	)

	for _, part := range partitions {
		// Skip network drives
		if strings.HasPrefix(part.Device, "\\\\") {
			continue
		}

		// Skip if already seen
		if seenDevice[part.Device] {
			continue
		}

		usage, err := disk.Usage(part.Mountpoint)
		if err != nil || usage.Total == 0 {
			continue
		}

		// Skip small volumes (< 1GB)
		if usage.Total < 1<<30 {
			continue
		}

		disks = append(disks, DiskStatus{
			Mount:       part.Mountpoint,
			Device:      part.Device,
			Used:        usage.Used,
			Total:       usage.Total,
			UsedPercent: usage.UsedPercent,
			Fstype:      part.Fstype,
			External:    false, // Will be determined later
		})
		seenDevice[part.Device] = true
	}

	annotateDiskTypes(disks)

	sort.Slice(disks, func(i, j int) bool {
		return disks[i].Total > disks[j].Total
	})

	if len(disks) > 3 {
		disks = disks[:3]
	}

	return disks, nil
}

func annotateDiskTypes(disks []DiskStatus) {
	if len(disks) == 0 || runtime.GOOS != "windows" || !commandExists("powershell") {
		return
	}

	// Use PowerShell to detect removable drives
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	psCmd := `Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID,DriveType | ConvertTo-Json`
	out, err := runCmd(ctx, "powershell", "-NoProfile", "-NonInteractive", "-Command", psCmd)
	if err != nil {
		return
	}

	// Parse output to identify removable drives (DriveType 2 = Removable, 3 = Local Fixed, etc.)
	removableMap := make(map[string]bool)
	lines := strings.Split(out, "\n")
	var currentDevice string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.Contains(line, "DeviceID") {
			if _, after, found := strings.Cut(line, ":"); found {
				currentDevice = strings.TrimSpace(strings.Trim(after, `",`))
			}
		}
		if strings.Contains(line, "DriveType") && currentDevice != "" {
			if _, after, found := strings.Cut(line, ":"); found {
				driveType := strings.TrimSpace(strings.Trim(after, ","))
				// DriveType 2 = Removable, 5 = CD-ROM, 6 = RAM Disk
				if driveType == "2" || driveType == "5" || driveType == "6" {
					removableMap[currentDevice] = true
				}
			}
			currentDevice = ""
		}
	}

	// Annotate disks
	for i := range disks {
		mountPoint := disks[i].Mount
		// Extract drive letter (e.g., "C:" from "C:\")
		if len(mountPoint) >= 2 {
			driveLetter := mountPoint[:2]
			if removableMap[driveLetter] {
				disks[i].External = true
			}
		}
	}
}

func (c *Collector) collectDiskIO(now time.Time) DiskIOStatus {
	counters, err := disk.IOCounters()
	if err != nil || len(counters) == 0 {
		return DiskIOStatus{}
	}

	var total disk.IOCountersStat
	for _, v := range counters {
		total.ReadBytes += v.ReadBytes
		total.WriteBytes += v.WriteBytes
	}

	if c.lastDiskAt.IsZero() {
		c.prevDiskIO = total
		c.lastDiskAt = now
		return DiskIOStatus{}
	}

	elapsed := now.Sub(c.lastDiskAt).Seconds()
	if elapsed <= 0 {
		elapsed = 1
	}

	readRate := float64(total.ReadBytes-c.prevDiskIO.ReadBytes) / 1024 / 1024 / elapsed
	writeRate := float64(total.WriteBytes-c.prevDiskIO.WriteBytes) / 1024 / 1024 / elapsed

	c.prevDiskIO = total
	c.lastDiskAt = now

	if readRate < 0 {
		readRate = 0
	}
	if writeRate < 0 {
		writeRate = 0
	}

	return DiskIOStatus{ReadRate: readRate, WriteRate: writeRate}
}
