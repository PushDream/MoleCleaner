//go:build windows

package main

import (
	"context"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

const overviewRoot = "__overview__"

func createOverviewEntries() []dirEntry {
	entries := []dirEntry{}
	addEntry := func(name, path string) {
		if path == "" {
			return
		}
		info, err := os.Stat(path)
		if err != nil || !info.IsDir() {
			return
		}
		entries = append(entries, dirEntry{Name: name, Path: path, IsDir: true, Size: -1})
	}

	home, _ := os.UserHomeDir()
	if home != "" {
		addEntry("User Profile", home)
		addEntry("Desktop", filepath.Join(home, "Desktop"))
		addEntry("Documents", filepath.Join(home, "Documents"))
		addEntry("Downloads", filepath.Join(home, "Downloads"))
	}

	addEntry("AppData Local", os.Getenv("LOCALAPPDATA"))
	addEntry("AppData Roaming", os.Getenv("APPDATA"))
	addEntry("Program Files", os.Getenv("ProgramFiles"))
	addEntry("Program Files (x86)", os.Getenv("ProgramFiles(x86)"))
	addEntry("Windows", os.Getenv("WINDIR"))
	addEntry("Temp", os.Getenv("TEMP"))

	for _, drive := range listWindowsDrives() {
		label := strings.TrimSuffix(drive, "\\")
		addEntry(fmt.Sprintf("Drive %s", label), drive)
	}

	return entries
}

func listWindowsDrives() []string {
	var drives []string
	for letter := 'C'; letter <= 'Z'; letter++ {
		drive := fmt.Sprintf("%c:\\", letter)
		info, err := os.Stat(drive)
		if err == nil && info.IsDir() {
			drives = append(drives, drive)
		}
	}
	return drives
}

func overviewExcludePath(path string) string {
	home, err := os.UserHomeDir()
	if err != nil || home == "" || path != home {
		return ""
	}
	appData := filepath.Join(home, "AppData")
	if _, err := os.Stat(appData); err == nil {
		return appData
	}
	return ""
}

func openPath(ctx context.Context, path string) error {
	return exec.CommandContext(ctx, "cmd", "/c", "start", "", path).Run()
}

func revealPath(ctx context.Context, path string) error {
	return exec.CommandContext(ctx, "explorer.exe", "/select,", path).Run()
}

func fileManagerName() string {
	return "Explorer"
}

func getActualFileSize(_ string, info fs.FileInfo) int64 {
	return info.Size()
}

func getLastAccessTimeFromInfo(info fs.FileInfo) time.Time {
	stat, ok := info.Sys().(*syscall.Win32FileAttributeData)
	if !ok {
		return time.Time{}
	}
	return time.Unix(0, stat.LastAccessTime.Nanoseconds())
}
