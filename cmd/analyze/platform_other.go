//go:build !darwin && !windows

package main

import (
	"context"
	"io/fs"
	"os"
	"os/exec"
	"time"
)

const overviewRoot = "/"

func createOverviewEntries() []dirEntry {
	entries := []dirEntry{}
	home, _ := os.UserHomeDir()
	if home != "" {
		entries = append(entries, dirEntry{Name: "Home", Path: home, IsDir: true, Size: -1})
	}
	entries = append(entries, dirEntry{Name: "Root", Path: "/", IsDir: true, Size: -1})
	return entries
}

func overviewExcludePath(_ string) string {
	return ""
}

func openPath(ctx context.Context, path string) error {
	return exec.CommandContext(ctx, "xdg-open", path).Run()
}

func revealPath(ctx context.Context, path string) error {
	return exec.CommandContext(ctx, "xdg-open", path).Run()
}

func fileManagerName() string {
	return "File Manager"
}

func getActualFileSize(_ string, info fs.FileInfo) int64 {
	return info.Size()
}

func getLastAccessTimeFromInfo(info fs.FileInfo) time.Time {
	return info.ModTime()
}
