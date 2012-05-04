# RTM via LaunchBar

## Usage

+ Get an API key from the [Remember the milk webpage](http://www.rememberthemilk.com/services/api/keys.rtm).
+ Create a file named 'key' like:

```
*YOUR API KEY*
*YOUR SHARED SECRET*
```

+ Place the file to where you think you should.
+ Create an AppleScript like:

```
on handle_string(message)
	do shell script "/Users/yuki/dev/rtm/rtm.rb \"" & message & "\""
end handle_string
```

+ Place the script to `~/Library/Application Support/LaunchBar/Actions`.
+ Done.

First time this script is invoked, it want you to authorize via browser (default: Safari). So the script **ignore** your first task.
