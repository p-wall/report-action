# RSpec Summary Action

This GitHub Action scans a directory and lists files matching a given pattern and generates a github actions summary.

## Usage

### Example Workflow

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bundle exec rspec --format json --out test-results/rspec-1.json
      - name: Generate summary
        id: report
        uses: p-wall/rspec-summary-action@v1
        with:
          pattern: 'test-results/rspec-*.json'
```

## Inputs

| Name       | Description                       | Required | Default |
|------------|-----------------------------------|----------|---------|
| `pattern`  | File pattern (e.g., `test-results/*.json`)     | ✅ Yes   | N/A     |

## Example Summary

![image](https://github.com/user-attachments/assets/e095e0c9-27e8-44f1-ac87-0e9aa88f581a)

