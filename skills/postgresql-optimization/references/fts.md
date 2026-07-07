# Full-Text Search (tsvector / tsquery)

PostgreSQL FTS gives you stemming, ranking, and language config without a separate Elasticsearch cluster. It scales to ~10M docs comfortably; beyond that consider a dedicated search engine.

## Schema and Generated Column (PG 12+)

```sql
CREATE TABLE documents (
    id         SERIAL PRIMARY KEY,
    title      TEXT NOT NULL,
    content    TEXT NOT NULL,
    -- Auto-maintained generated column — preferred over triggers
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')),   'A') ||
        setweight(to_tsvector('english', coalesce(content, '')), 'B')
    ) STORED
);

CREATE INDEX idx_documents_search ON documents USING gin(search_vector);
```

`setweight` lets ranking favor matches in the title (A) over body (B). Weights are A > B > C > D.

## Querying and Ranking

```sql
-- plainto_tsquery: parses user input as a phrase (AND of stemmed terms)
SELECT id, title,
       ts_rank(search_vector, plainto_tsquery('english', 'postgresql tuning')) AS rank,
       ts_headline('english', content, plainto_tsquery('english', 'postgresql tuning')) AS snippet
FROM documents
WHERE search_vector @@ plainto_tsquery('english', 'postgresql tuning')
ORDER BY rank DESC
LIMIT 20;

-- websearch_to_tsquery: supports "quoted phrase", -negation, OR
SELECT * FROM documents
WHERE search_vector @@ websearch_to_tsquery('english', '"json indexing" -mongodb');
```

| Parser | Use for |
|---|---|
| `to_tsquery` | Programmatic queries with full operator syntax (`&`, `|`, `!`, `<->`) |
| `plainto_tsquery` | User input you want AND-ed together |
| `phraseto_tsquery` | Exact phrase |
| `websearch_to_tsquery` | Google-style user input (most app code wants this) |

## Trigram (`pg_trgm`) for Fuzzy Match

FTS handles stemming, not typos. For fuzzy / partial / prefix matching use `pg_trgm`:

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_users_name_trgm ON users USING gin (name gin_trgm_ops);

SELECT name, similarity(name, 'jonh smyth') AS sim
FROM users
WHERE name % 'jonh smyth'   -- similar (default threshold 0.3)
ORDER BY sim DESC LIMIT 10;
```

Combine FTS + trigram when you need both stemming and typo tolerance.

## Anti-Patterns

- **Maintaining `tsvector` with triggers when a generated column works** — generated columns are simpler and can't get out of sync.
- **`to_tsvector(...) @@ to_tsquery(...)` without a stored column** — recomputes the vector for every row, kills the index.
- **Using `ILIKE '%term%'` for search** — sequential scan, no ranking, no stemming. Move to FTS or trigram.
- **Skipping language config** — `to_tsvector('simple', ...)` skips stemming; `'english'` (or your locale) gives much better recall.
