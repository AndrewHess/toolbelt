# Taskman

This is a simple terminal-based task manager that allows adding, searching, and grouping tasks.
Tasks are stored in plain text, so you can easily edit them if necessary.
Output is paginated so it fits on your terminal window.

## Setup Tasks
If you write to the task file manually, it should be formatted like this:

```text
- Buy eggs @groceries
- Wash the car @chores @due=saturday
- Plan dinner
    Can't contain peanuts
    Might want to try a new recipe
```

In particular:
- Each task is on a separate line starting with `-`.
- To add details to a task, indent the lines that follow it, and don't start them with a `-`.
- You can add any number of tags to each task by writing `@tagname`.

## Tags
Tags in Taskman server two purposes: automatic grouping and easier searching.
Tags that don't contain a `=` are used for grouping; when you run Taskman and run the `list` command, it will automatically group the tasks accordingly.
If a particular task has multiple tags without a `=`, it will show up in each of those sections.
And tasks without a tag will be grouped into an `Unlabeled` category.
Tags with a `=` are purely to make it easier to search your tasks, but you can also search for other tags or search for text without tags.

**Note**: Tags can only contain letters, numbers, and hyphens.

## Usage
Run the script and give it the location of your tasks file:
```bash
./taskman.sh /path/to/tasks.txt
```
From there you'll get a prompt and can type in commands:
- **List tasks**: `list` shows all the tasks.
You can also provide an awk-style search condition to only show tasks that match; for example: `list /@due=saturday/`
- **Add a task**: Use `add <some text>` to add a new task; for example: `add Buy eggs @groceries`
- **Set tags on a task**: Use `set <tagname> <task number 1> <task number 2> ...` to add a tag to one or more items; for example: `set @done 42 100` will append `@done` to tasks 42 and 100.
- **Show command history**: `history` shows the full history of Taskman commands you've run.
- **Quit**: `quit` exits Taskman.

### Tips
- Backwards searching is supported with ctrl+r, just like in bash.
So if you use a long search condition often, you can use ctrl+r to find it quickly.
- For more complex modifications of tasks (e.g., delete a tag), you should edit the tasks file directly.

## Automation
Many tasks need to be done on a recurring basis.
You may want to add automate adding those tasks using cron jobs.
Additionally, if you mark tasks as completed by adding a `@done` tag rather than deleting the tasks, you may want to automate deleting those tasks.
For these situations, the `auto.sh` script is provided.

To add a few tasks every week on Friday at 4:00 AM, add this to your crontab:
```cron
0 4 * * 5 /path/to/auto.sh append_tasks "Wash laundry" "Dry laundry" "Fold laundry"
```

To delete all tasks tagged with `@done` every day at 4:00 AM, add this to your crontab:
```cron
0 4 * * * /path/to/auto.sh delete_done_tasks
```
