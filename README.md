# graun-btl
Download comments from a discussion on an article on the [Guardian](https://www.theguardian.com/) website

Usage: `./graun-btl.pl [--user-id-prefix <string>] [--comment-id-prefix <string>] [--remove-markup] [--columns <column codes>] [--column-as <column code> <heading>] {[--discussion-id <string>]|<Guardian Article URL>}`

Use output redirect to save the results to a file. Guardian-assigned user IDs and comment IDs are replaced with new numbers provided by this program in its output.

Command-line options:

  +	`--user-id-prefix` _P_: use _P_ as a prefix in front of user ID numbers (default `"GUU"`)
  +	`--comment-id-prefix` _P_: use _P_ as a prefix in front of comment ID numbers (default `"GUC"`)
  +	`--discussion-id` _D_: use _D_ as a discussion ID rather than extracting it from the article URL
  + `--remove-markup`: replace the TXT column with the MD column
	+ `--columns` _L_: print the column codes in comma-separated list _L_; if any	of the codes are not recognized, the entry is used as a column-heading with NA entries. Column codes are:
		+	`CID` -- comment ID
		+	`RCID` -- ID of comment being responded to
		+	`DPTH` -- 'depth' of the comment
		+	`AU` -- commenter's displayed name
		+	`UID` -- pseudonymized user identification number
		+	`DT` -- date-time of comment
		+	`UP` -- number of comment recommendations
		+ `ED` -- comment highlighted by moderator
		+	`TXT` -- comment text with any HTML markup
		+	`MD` -- comment text with HTML tagsremoved
		+	`LVL` -- as RCID, but "Reply to ID" or empty
	+ `--column-as` _C_ _H_: use _H_ as the heading for column code _C_ (which must be a valid column code unlike for `--columns`) instead of the	default. You can repeat this option as often as you want. Defaults:
		+	`CID` -- "Comment ID"
		+	`RCID` -- "Comment ID Responding To"
		+	`DPTH` -- "Depth"
		+	`AU` -- "Author"
		+	`UID` -- "User ID
		+	`DT` -- "Date Time"
		+	`UP` -- "Recommendations"
		+	`ED` -- "Highlighted?"
		+	`TXT` -- "Comment Text"
		+	`MD` -- "Comment Text without Markup"
		+	`LVL` -- "Level"
	+ `--all`: put all columns in the output, as opposed to the default: `"CID,RCID,DPTH,UID,DT,UP,ED,TXT"`

Default output:
 
| Comment ID | Comment ID Responding To | User ID | Date Time | Recommendations | Highlighted? | Comment Text |
| --- | --- | --- | --- | --- | --- | --- |
| e.g. `GUC001` | `NA` if not a response | e.g. `GUU001` | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) format | Number of 'upticks' | `1` if highlighted by moderator, `0` if not | Text with any HTML markup |

Comments are extracted in the order returned by the JSON output from [The Guardian's discussion API](http://discussion.theguardian.com/discussion-api/). Since responses to comments are embedded in the entry for their comment, this means sorting by comment ID will get you comments then responses row-by-row -- it also means sorting by date-time order will not get you ascending order of comment IDs.
