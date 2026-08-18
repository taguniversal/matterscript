#!/bin/sh
curl -s https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $LINEAR_API_KEY" \
  -d '{
    "query": "query { issues(filter: { project: { name: { eq: \"MatterScript\" } } }, first: 50) { nodes { identifier title state { name } priority description } } }"
  }' | python3 -m json.tool