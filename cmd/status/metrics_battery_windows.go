//go:build windows

package main

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

func collectBatteries() (batts []BatteryStatus, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("battery collection failed: %v", r)
		}
	}()

	// Windows: Use PowerShell to query WMI for battery info
	if !commandExists("powershell") {
		return nil, errors.New("PowerShell not available")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	// Query battery status using WMI
	psCmd := `Get-WmiObject -Class Win32_Battery | Select-Object EstimatedChargeRemaining,BatteryStatus,EstimatedRunTime,DesignCapacity,FullChargeCapacity | ConvertTo-Json`
	out, err := runCmd(ctx, "powershell", "-NoProfile", "-NonInteractive", "-Command", psCmd)
	if err != nil {
		return nil, err
	}

	// Parse PowerShell JSON output
	batts = parsePowerShellBattery(out)
	if len(batts) == 0 {
		return nil, errors.New("no battery data found")
	}

	return batts, nil
}

func parsePowerShellBattery(raw string) []BatteryStatus {
	var out []BatteryStatus

	// Simple JSON parsing for battery data
	lines := strings.Split(raw, "\n")
	var percent float64
	var status string
	var timeLeft string
	var health string
	var designCapacity int
	var fullChargeCapacity int
	var capacity int

	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Parse EstimatedChargeRemaining
		if strings.Contains(line, "EstimatedChargeRemaining") {
			if _, after, found := strings.Cut(line, ":"); found {
				valStr := strings.TrimSpace(strings.Trim(after, ","))
				if p, err := strconv.ParseFloat(valStr, 64); err == nil {
					percent = p
				}
			}
		}

		// Parse BatteryStatus (1=Discharging, 2=AC, 3=Fully Charged, etc.)
		if strings.Contains(line, "BatteryStatus") {
			if _, after, found := strings.Cut(line, ":"); found {
				valStr := strings.TrimSpace(strings.Trim(after, ","))
				statusCode, _ := strconv.Atoi(valStr)
				switch statusCode {
				case 1:
					status = "Discharging"
				case 2:
					status = "AC Power"
				case 3:
					status = "Fully Charged"
				case 4:
					status = "Low"
				case 5:
					status = "Critical"
				default:
					status = "Unknown"
				}
			}
		}

		// Parse EstimatedRunTime (in minutes)
		if strings.Contains(line, "EstimatedRunTime") {
			if _, after, found := strings.Cut(line, ":"); found {
				valStr := strings.TrimSpace(strings.Trim(after, ","))
				if minutes, err := strconv.Atoi(valStr); err == nil && minutes > 0 {
					hours := minutes / 60
					mins := minutes % 60
					if hours > 0 {
						timeLeft = fmt.Sprintf("%d:%02d", hours, mins)
					} else {
						timeLeft = fmt.Sprintf("0:%02d", mins)
					}
				}
			}
		}

		// Parse DesignCapacity (original battery capacity in mWh)
		if strings.Contains(line, "DesignCapacity") && !strings.Contains(line, "FullChargeCapacity") {
			if _, after, found := strings.Cut(line, ":"); found {
				valStr := strings.TrimSpace(strings.Trim(after, ","))
				designCapacity, _ = strconv.Atoi(valStr)
			}
		}

		// Parse FullChargeCapacity (current maximum capacity in mWh)
		if strings.Contains(line, "FullChargeCapacity") {
			if _, after, found := strings.Cut(line, ":"); found {
				valStr := strings.TrimSpace(strings.Trim(after, ","))
				fullChargeCapacity, _ = strconv.Atoi(valStr)
			}
		}
	}

	// Calculate battery health capacity percentage
	if designCapacity > 0 && fullChargeCapacity > 0 {
		capacity = int((float64(fullChargeCapacity) / float64(designCapacity)) * 100.0)

		// Set health status based on capacity
		if capacity >= 85 {
			health = "Good"
		} else if capacity >= 70 {
			health = "Fair"
		} else {
			health = "Poor"
		}
	} else {
		health = "Unknown"
	}

	if percent > 0 || status != "" {
		out = append(out, BatteryStatus{
			Percent:    percent,
			Status:     status,
			TimeLeft:   timeLeft,
			Health:     health,
			CycleCount: 0, // Windows doesn't easily expose cycle count via WMI
			Capacity:   capacity,
		})
	}

	return out
}

func collectThermal() ThermalStatus {
	// Windows thermal monitoring via WMI
	var thermal ThermalStatus

	if !commandExists("powershell") {
		return thermal
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// Query CPU temperature (requires OpenHardwareMonitor or similar, fallback to thermal zone)
	psCmd := `Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature | Select-Object -First 1 CurrentTemperature | ConvertTo-Json`
	out, err := runCmd(ctx, "powershell", "-NoProfile", "-NonInteractive", "-Command", psCmd)
	if err == nil && out != "" {
		lines := strings.Split(out, "\n")
		for _, line := range lines {
			if strings.Contains(line, "CurrentTemperature") {
				if _, after, found := strings.Cut(line, ":"); found {
					valStr := strings.TrimSpace(strings.Trim(after, ","))
					if temp, err := strconv.ParseFloat(valStr, 64); err == nil {
						// Convert from tenths of Kelvin to Celsius
						thermal.CPUTemp = (temp / 10.0) - 273.15
					}
				}
			}
		}
	}

	return thermal
}

func collectSensors() ([]SensorReading, error) {
	// Windows doesn't have a standard sensor API accessible without admin rights
	// Return empty for now - could integrate with OpenHardwareMonitor later
	return []SensorReading{}, nil
}
