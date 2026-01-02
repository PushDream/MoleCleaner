# Progress Indicators - User Experience Improvements

## Changes Made

### Before
- Silent execution with no feedback
- User couldn't tell if the script was working or frozen
- No indication of what was being cleaned

### After
Now includes **real-time progress indicators** at multiple levels:

#### 1. **Category Overview**
```
Cleaning 5 categories...
```
Shows total number of cleanup categories upfront

#### 2. **Section Headers**
```
-> Windows User Caches
-> Browser Caches
-> Developer Tools
```
Clear indication of which category is being processed

#### 3. **Scanning Progress**
```
  Scanning Temporary files...
```
Shows when the script is calculating sizes (can take a few seconds for large folders)

#### 4. **Cleaning Progress with Percentage**
```
  Cleaning Temporary files... 45%
```
Real-time percentage updates as files are deleted

#### 5. **Completion Status**
```
  [OK] Temporary files 2.3 GB
```
Shows final result with space freed

#### 6. **Empty Results**
```
  [i] No items found for Temporary files
```
Clear indication when nothing needs cleaning

## Visual Flow Example

```
Mole - Clean Your Windows PC

Dry Run Mode - Preview only, no deletions

[i] Windows 10.0 | Free space: 45.2 GB

Cleaning 5 categories...

-> Windows User Caches
  Scanning Temporary files...
  -> Temporary files 2.3 GB (dry run)
  Scanning Prefetch cache...
  [i] No items found for Prefetch cache
  Scanning Thumbnail cache...
  -> Thumbnail cache 156 MB (dry run)

-> Browser Caches
  Scanning Chrome cache...
  -> Chrome cache 1.2 GB (dry run)
  Scanning Edge cache...
  -> Edge cache 890 MB (dry run)

-> Developer Tools
  Scanning npm cache...
  -> npm cache 3.4 GB (dry run)

-> Application Caches
  Scanning Discord cache...
  -> Discord cache 234 MB (dry run)

-> Recycle Bin
  Checking Recycle Bin...
  -> Recycle Bin 5.6 GB (dry run)

Dry Run Complete - No Changes Made

  Potential space: 14.8 GB
  Items: 245 | Categories: 5
```

## Benefits

1. **User Confidence**: User knows the script is working, not frozen
2. **Time Estimates**: Can see progress and estimate completion time
3. **Transparency**: Clear indication of what's being cleaned
4. **No Surprises**: User sees exactly what will be removed before it happens (in dry-run)
5. **Debugging**: If something fails, user knows exactly where

## Implementation Details

### Progress Updates
- Uses `Write-Host -NoNewline` for in-place updates
- Carriage return (`\r`) to overwrite previous line
- Percentage calculation based on items processed
- Extra spaces to clear previous longer text

### Color Coding
- **Gray**: Scanning/processing
- **Yellow**: Dry-run results
- **Green**: Success/completion
- **Red**: Errors (only shown with -Debug)
- **Cyan**: Information
- **Purple**: Section headers

## Testing

Try these commands to see the progress indicators:

```powershell
# Dry run (safe, shows progress without deleting)
.\mole.ps1 clean -DryRun

# Actual cleanup (shows progress while cleaning)
.\mole.ps1 clean

# Debug mode (shows all errors)
.\mole.ps1 clean -Debug
```

## Future Enhancements

Potential additions:
1. Overall progress bar (e.g., "2/5 categories complete")
2. Estimated time remaining
3. Speed indicator (MB/s)
4. Detailed item count per category
5. Option to skip slow operations
