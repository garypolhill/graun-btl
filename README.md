# graun-btl
Download comments from a discussion on an article on the [Guardian](https://www.theguardian.com/) website

Usage: `./graun-btl.pl [--user-id-prefix <string>] [--comment-id-prefix <string>] {[--discussion-id <string>]|<Guardian Article URL>}`

Use output redirect to save the results to a file. Guardian-assigned user IDs and comment IDs are replaced with new numbers provided by this program in its output.

Command-line options:

  +	--user-id-prefix P: use P as a prefix in front of user ID numbers (default `"GUU"`)
  +	--comment-id-prefix P: use P as a prefix in front of comment ID numbers (default `"GUC"`)
  +	--discussion-id D: use D as a discussion ID rather than extracting it from the article URL
  
Output:
 
| Comment ID | Comment ID Responding To | User ID | Date Time | Recommendations | Highlighted? | Comment Text |
| --- | --- | --- | --- | --- | --- | --- |
| e.g. `GUC001` | `NA` if not a response | e.g. `GUU001` | ISO 8601 format | Number of 'upticks' | `1` if highlighted by editor, `0` if not | Text with any HTML markup |

Comments are extracted in the order returned by the JSON output from [The Guardian's discussion API](http://discussion.theguardian.com/discussion-api/). Since responses to comments are embedded in the entry for their comment, this means sorting by comment ID will get you comments then responses row-by-row -- it also means sorting by date-time order will not get you ascending order of comment IDs.
