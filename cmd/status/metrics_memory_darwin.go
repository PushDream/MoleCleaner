//go:build darwin

package main

// getWindowsMemoryDetails is a no-op on non-Windows platforms
func getWindowsMemoryDetails() (committed, committedLimit, pagedPool, nonPagedPool uint64) {
	return 0, 0, 0, 0
}
