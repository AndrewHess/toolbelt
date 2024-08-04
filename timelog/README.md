# Timelog

This a hierarchical timelog that to summarize how much time you've spent on various tasks.

## Setup
To use this, you'll write to a text file formatted like this:
```text
2024-01-22 08:09:20 Work
2024-01-22 08:30:00 Work.Meeting
2024-01-22 08:52:17 Work
2024-01-22 12:07:07 Lunch
2024-01-22 12:53:16 Work.SpecialProject
2024-01-22 14:10:42 Work
2024-01-22 17:03:16 Done
```

In particular:
- Each line is a timestamp followed by a task name.
- You can make hierarchical task names by separating them with periods.
When the data gets summarized, you'll see how much time you've spent on `Work.Meeting`, `Work.SpecialProject`, and `Work` category, with `Work` including all the subcategories.
- There's only one special task name: `Done`.
This indicates that time tracking should stop.

## Usage
Run the script and give it the location of your timelog file:
```bash
python3 timelog.py -q /path/to/timelog.txt
```
The `-q` flag specifies to output aggregated data for today, this week, and this month.
Use the `-h` flag to see all the options.

For the above example, running the script would output this for the `today` section:
```text
Today
---------------------------------------------
Lunch               : 46 minutes
Work                : 8 hours and 7 minutes
Work.Meeting        : 22 minutes
Work.SpecialProject : 1 hour and 17 minutes
```

## Tips
- Make an easy way to add a timestamp to your timelog.
In nvim, you can use a mapping like this:
```vim
nnoremap <leader>now :put =strftime('%Y-%m-%d %H:%M:%S')<CR>A 
```
