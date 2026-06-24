# CloudWatch Logs Insights Queries

Log group: `/devops-capstone/app` (created in `terraform/cloudwatch.tf`,
populated by the CloudWatch agent tailing `/var/log/containers/*.log`
on the node - see `terraform/scripts/bootstrap-k8s.sh`).

## A note on log format before you query

Our app logs clean JSON lines (see `app/src/app.js`), e.g.:
```json
{"timestamp":"2026-06-23T10:15:00.000Z","level":"error","method":"GET","path":"/api/tasks/9999","statusCode":404,"durationMs":3}
```

But the file `/var/log/containers/*.log` that the agent tails wraps each
line in **containerd's CRI log format** first:
```
2026-06-23T10:15:00.123456789Z stdout F {"timestamp":"...","level":"error",...}
```
That leading `<timestamp> stdout F` prefix means the *entire* line isn't
valid JSON, so CloudWatch Logs Insights' automatic JSON-field discovery
(which expects `@message` to parse cleanly as JSON) won't pull out
`level`/`statusCode`/etc. as queryable fields on its own. Rather than add
a log shipper just to strip that envelope, we just match on substrings
with `like` - simpler, and still genuinely useful.

(If you want properly structured fields later, the real fix is a
Fluent Bit DaemonSet with the Kubernetes filter, which strips the CRI
envelope before forwarding - a reasonable "what I'd do for a bigger
system" answer if asked.)

## How to run these

AWS Console → CloudWatch → **Logs → Logs Insights** → select log group
`/devops-capstone/app` → set the time range dropdown (top right) to
**Last 24 hours** → paste a query below → **Run query**.

## Query 1: All errors in the last 24 hours

```
fields @timestamp, @message
| filter @message like /"level":"error"/
| sort @timestamp desc
| limit 100
```

## Query 2: Errors AND warnings (4xx + 5xx), last 24 hours

```
fields @timestamp, @message
| filter @message like /"level":"error"/ or @message like /"level":"warn"/
| sort @timestamp desc
| limit 100
```

## Query 3: Error count per hour (spot a spike)

```
fields @timestamp, @message
| filter @message like /"level":"error"/
| stats count() as errorCount by bin(1h)
```

## Query 4: Slowest requests (find performance issues, not just errors)

```
fields @timestamp, @message
| filter @message like /"durationMs"/
| parse @message /"durationMs":(?<duration>\d+)/
| fields duration * 1 as durationNum
| sort durationNum desc
| limit 20
```

(The `* 1` forces a numeric cast - `parse` extracts strings, and a plain
string sort would put `"100"` before `"99"` lexically, which isn't what
you want for response times.)

## Generating real error logs to query

The app naturally produces errors during normal use - no need to fake
anything:
```bash
curl http://<node-ip>:30082/api/tasks/99999     # 404 - real error log
curl -X POST http://<node-ip>:30082/api/tasks -d '{}' -H "Content-Type: application/json"  # 400 - real warn log
```
Run a handful of these (mixed with normal requests) before taking your
evidence screenshot, so the query has something real to show.