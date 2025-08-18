# scripts/mcp_send.sh
#!/usr/bin/env bash
json="$1"
len=$(printf '%s' "$json" | wc -c | tr -d ' ')
printf 'Content-Length: %d\r\n\r\n%s' "$len" "$json"



