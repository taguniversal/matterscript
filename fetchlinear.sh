#/bin/sh
curl -s https://api.linear.app/graphql -H "Content-Type: application/json" -H "Authorization: $LINEAR_API_KEY" -d '{"query": "query { issues(filter: { project: { name: { eq: \"MatterScript\" } } }, first: 200) { nodes { identifier title } } }"}' | grep -i "TAG-87\|Conditional Iteration"
