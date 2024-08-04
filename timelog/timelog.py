import argparse
from datetime import datetime, timedelta

def parse_relative_time(time_str):

    """Parse relative time strings like '7d', '2w', '3m'"""
    value = int(time_str[:-1])
    unit = time_str[-1]
    if unit == 'd':
        return timedelta(days=value)
    elif unit == 'w':
        return timedelta(weeks=value)
    elif unit == 'm':
        return timedelta(days=value * 30)  # Approximate
    else:
        raise ValueError("Invalid time unit. Use 'd' for days, 'w' for weeks, or 'm' for months.")


def valid_date(s):
    """Validate date strings"""
    try:
        return datetime.strptime(s, "%Y-%m-%d")
    except ValueError:
        msg = "Not a valid date: '{0}'.".format(s)
        raise argparse.ArgumentTypeError(msg)


def parse_command_line_args():
    parser = argparse.ArgumentParser(description="Aggregate activity data with flexible time filtering.")

    parser.add_argument("file", nargs='?', default="timelog.txt", help="Path to the file containing activity data (default: timelog.txt)")

    parser.add_argument("-d", "--today", action="store_true", help="Aggregate data for today")
    parser.add_argument("-w", "--week", action="store_true", help="Aggregate data for this week")
    parser.add_argument("-m", "--month", action="store_true", help="Aggregate data for this month")
    parser.add_argument("-y", "--year", action="store_true", help="Aggregate data for this year")
    parser.add_argument("--last", type=parse_relative_time, metavar="TIME",
                            help="Aggregate data for the last period (e.g., '7d' for 7 days, '2w' for 2 weeks, '3m' for 3 months)")

    # Date range options
    parser.add_argument("--from", dest="from_date", type=valid_date, help="Start date (YYYY-MM-DD)")
    parser.add_argument("--to", dest="to_date", type=valid_date, help="End date (YYYY-MM-DD)")

    # Quick view option
    parser.add_argument("-q", "--quick", action="store_true", help="Show quick summary for today, this week, and this month")

    args = parser.parse_args()
    if args.quick:
        args.today = True
        args.week = True
        args.month = True

    return args


def parse_timelog(filename):
    activities = []
    with open(filename, 'r') as file:
        for line in file:
            parts = line.strip().split()
            if len(parts) >= 3:
                date_str = parts[0]
                time_str = parts[1]
                activity = ' '.join(parts[2:])
                try:
                    timestamp = datetime.strptime(f"{date_str} {time_str}", "%Y-%m-%d %H:%M:%S")
                    activities.append((timestamp, activity))
                except ValueError:
                    print(f"Warning: Skipping invalid line: {line.strip()}")
            else:
                print(f"Warning: Skipping line with insufficient parts: {line.strip()}")
    return activities


def get_activities_in_range(activities, start, end):
    filtered_activities = []

    for i, (timestamp, activity) in enumerate(activities):
        # Skip activities that end before the range starts
        if i < len(activities) - 1 and activities[i+1][0] <= start:
            continue

        # Skip activities that start after the range ends
        if timestamp >= end:
            break

        # Handle activities that start before the range
        if timestamp < start:
            duration = (activities[i+1][0] if i < len(activities) - 1 else end) - start
            filtered_activities.append((activity, duration))

        # Handle activities that end after the range
        elif i < len(activities) - 1 and activities[i+1][0] > end:
            duration = end - timestamp
            filtered_activities.append((activity, duration))

        # Handle activities completely within the range
        else:
            duration = (activities[i+1][0] if i < len(activities) - 1 else end) - timestamp
            filtered_activities.append((activity, duration))

    return filtered_activities


def calculate_durations(activities_and_durations):
    # activities.append((datetime.now(), 'Done'))
    durations = {}

    for i in range(len(activities_and_durations)):
        activity, duration = activities_and_durations[i]

        # Add duration to the specific activity
        durations[activity] = durations.get(activity, 0) + duration.total_seconds()

        # Add duration to parent activity if it exists
        for parent_activity in split_hierarchical(activity, '.')[:-1]:
            durations[parent_activity] = durations.get(parent_activity, 0) + duration.total_seconds()

    return durations


def split_hierarchical(s, separator):
    parts = s.split(separator)
    return [separator.join(parts[:i+1]) for i in range(len(parts))]


def format_duration(seconds):
    hours, remainder = divmod(int(seconds), 3600)
    minutes, _ = divmod(remainder, 60)

    parts = []
    if hours > 0:
        parts.append(f"{hours} hour{'s' if hours != 1 else ''}")
    if minutes > 0:
        parts.append(f"{minutes} minute{'s' if minutes != 1 else ''}")

    if not parts:
        return "0 minutes"
    elif len(parts) == 1:
        return parts[0]
    else:
        return f"{parts[0]} and {parts[1]}"


def get_date_ranges(args):
    now = datetime.now()
    ranges = []
    day_start_hours = 4  # 4 AM

    if args.today:
        start = now.replace(hour=day_start_hours, minute=0, second=0, microsecond=0)
        ranges.append(("Today", start, now))

    if args.week:
        start = now - timedelta(days=now.weekday())
        start = start.replace(hour=day_start_hours, minute=0, second=0, microsecond=0)
        ranges.append(("This week", start, now))

    if args.month:
        start = now.replace(day=1, hour=day_start_hours, minute=0, second=0, microsecond=0)
        ranges.append(("This month", start, now))

    if args.year:
        start = now.replace(month=1, day=1, hour=day_start_hours, minute=0, second=0, microsecond=0)
        ranges.append(("This year", start, now))

    if args.last:
        start = now - args.last
        ranges.append((f"Last {args.last}", start, now))

    if args.from_date or args.to_date:
        start = args.from_date if args.from_date else datetime.min
        end = args.to_date if args.to_date else now
        ranges.append((f"{start.date()} to {end.date()}", start, end))

    return ranges


def summarize_data(start, end, filename):
    result_lines = []

    activities = parse_timelog(filename)
    durations = calculate_durations(get_activities_in_range(activities, start, end))

    # Filter out 'Done' and sort activities alphabetically
    sorted_activities = sorted([activity for activity in durations.keys() if activity != 'Done'])

    if len(sorted_activities) == 0:
        return "No entries"

    # Calculate max length for alignment
    max_activity_length = max(len(activity) for activity in sorted_activities)

    for activity in sorted_activities:
        result_lines.append(f"{activity:<{max_activity_length}} : {format_duration(durations[activity])}")

    return "\n".join(result_lines)


def main(filename):
    args = parse_command_line_args()
    date_ranges = get_date_ranges(args)

    for i, date_range in enumerate(date_ranges):
        title, start, end = date_range
        print(f"{title}")
        print(f"---------------------------------------------")
        print(f"{summarize_data(start, end, args.file)}")
        print("", end="\n" if i < len(date_ranges) - 1 else "")


if __name__ == "__main__":
    main("timelog.txt")  # Replace with your filename if different
