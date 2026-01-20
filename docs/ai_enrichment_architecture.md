# AI Sentiment Enrichment - Architecture Documentation

## Overview

This project demonstrates how to integrate AI sentiment analysis into a data pipeline for content quality scoring. While the current implementation uses **simulated sentiment** for demonstration purposes, the architecture is designed for real Hugging Face API integration.

## Current Implementation: Simulated Sentiment

### Location
Sentiment scores are currently generated in `stg_articles.sql` using deterministic hash functions:

```sql
-- Simulated sentiment based on article characteristics
CASE 
    WHEN MOD(HASH(article_id), 3) = 0 THEN 'POSITIVE'
    WHEN MOD(HASH(article_id), 3) = 1 THEN 'NEGATIVE'
    ELSE 'NEUTRAL'
END AS sentiment_label
```

### Why Simulated?

**Pros:**
- ✅ No API costs ($0 vs ~$9/month for Hugging Face Pro)
- ✅ Deterministic (same article = same sentiment every time)
- ✅ No rate limits
- ✅ Works offline
- ✅ Demonstrates the concept perfectly for portfolio

**Cons:**
- ❌ Not real AI analysis
- ❌ Doesn't reflect actual article content quality

For a **portfolio project**, simulated sentiment is perfectly acceptable and actually preferred because:
1. Anyone can clone and run your project without API keys
2. Results are reproducible
3. You can control the distribution of scores for testing

## Production Architecture: Real AI Integration

### How It Would Work in Production

```
┌─────────────────┐
│   New Article   │
│    Published    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ETL Pipeline   │
│  (Fivetran/     │
│   Airbyte)      │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│           Snowflake Landing Table           │
│  article_raw (title, body, metadata)        │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│         Python Enrichment Script            │
│                                              │
│  1. Fetch unenriched articles               │
│  2. Call Hugging Face API                   │
│  3. Store sentiment scores                  │
│                                              │
│  Scheduled via: Airflow, dbt Cloud, cron    │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│        article_metadata (enriched)          │
│                                              │
│  - article_id                                │
│  - title                                     │
│  - sentiment_label                           │
│  - sentiment_score_positive                  │
│  - sentiment_score_negative                  │
│  - sentiment_enriched_at                     │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│           dbt Transformation                 │
│                                              │
│  dim_articles:                               │
│    quality_score = f(sentiment)              │
│                                              │
│  fct_article_events:                         │
│    quality_adjusted_engagement =             │
│      is_engaged * quality_score              │
└─────────────────────────────────────────────┘
```

### Real Implementation Steps

**1. Hugging Face Setup:**
```python
# Use transformers library (local) instead of API
from transformers import pipeline

classifier = pipeline(
    "sentiment-analysis",
    model="distilbert-base-uncased-finetuned-sst-2-english"
)

result = classifier("Warriors Dominates Mavericks in Playoff Showdown")
# [{'label': 'POSITIVE', 'score': 0.9998}]
```

**2. Batch Processing:**
```python
# Process 100 articles at once
titles = [article['title'] for article in articles]
results = classifier(titles, batch_size=32)
```

**3. Airflow DAG:**
```python
from airflow import DAG
from airflow.operators.python import PythonOperator

dag = DAG('enrich_sentiment', schedule_interval='@hourly')

enrich_task = PythonOperator(
    task_id='enrich_articles',
    python_callable=enrich_new_articles,
    dag=dag
)

dbt_task = BashOperator(
    task_id='rebuild_dimensions',
    bash_command='dbt run --select dim_articles+',
    dag=dag
)

enrich_task >> dbt_task
```

## Alternatives to Hugging Face

### 1. OpenAI GPT-4
```python
import openai

response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[{
        "role": "system",
        "content": "Analyze sentiment: POSITIVE, NEGATIVE, or NEUTRAL"
    }, {
        "role": "user",
        "content": article_title
    }]
)
```

**Pros:** More nuanced, better quality
**Cons:** Expensive ($0.03 per 1K tokens), slower

### 2. AWS Comprehend
```python
import boto3

comprehend = boto3.client('comprehend')
response = comprehend.detect_sentiment(
    Text=article_title,
    LanguageCode='en'
)
```

**Pros:** Managed service, scalable
**Cons:** AWS lock-in, costs add up

### 3. Local DistilBERT
```python
# Best for production at scale
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch

model_name = "distilbert-base-uncased-finetuned-sst-2-english"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSequenceClassification.from_pretrained(model_name)

# Run on GPU for speed
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)
```

**Pros:** No API costs, fast, offline
**Cons:** Need ML infrastructure (GPU), DevOps complexity

## Quality Score Calculation

Regardless of whether you use real or simulated sentiment, the quality score calculation in `dim_articles` is:

```sql
CASE 
    WHEN sentiment_label = 'POSITIVE' THEN sentiment_score_positive
    WHEN sentiment_label = 'NEGATIVE' THEN 1 - sentiment_score_negative
    ELSE 0.5
END AS quality_score
```

**Why this formula?**
- POSITIVE articles: Use confidence score directly (0.9 = high quality)
- NEGATIVE articles: Invert the score (0.9 negative = 0.1 quality)
- NEUTRAL: Default to 0.5 (medium quality)

This creates a 0-1 scale where:
- 1.0 = Strong positive sentiment (high quality)
- 0.5 = Neutral (medium quality)
- 0.0 = Strong negative sentiment (low quality/clickbait)

## Interview Talking Points

When discussing this project in interviews:

**"Why simulated sentiment?"**
> "For the portfolio version, I used simulated sentiment to keep the project accessible and reproducible. In production, I'd integrate Hugging Face's DistilBERT model - either via API for simplicity or locally for scale. The architecture supports either approach with minimal changes."

**"How would you productionize this?"**
> "I'd run DistilBERT locally on GPU for cost efficiency at scale. New articles would trigger an Airflow DAG that: (1) enriches with sentiment, (2) runs dbt to update quality scores, (3) invalidates BI cache. The enrichment step takes ~0.1 seconds per article, so we could process 1000 articles/minute."

**"What about model drift?"**
> "Great question. I'd monitor sentiment distribution weekly - if we suddenly see 90% negative when it was 50/50, that's a red flag. I'd also have human review a sample of 100 articles monthly to ensure the model's still accurate for our domain. News headlines might need fine-tuning on media-specific data."

## Files

**Enrichment Script (ready for production):**
- `scripts/enrichment/enrich_articles_sentiment.py`

**dbt Models (uses sentiment):**
- `models/staging/stg_articles.sql` - Generates simulated sentiment
- `models/marts/core/dim_articles.sql` - Calculates quality_score
- `models/marts/core/fct_article_events.sql` - Uses quality_adjusted_engagement
- `models/marts/experiments/experiment_results.sql` - Detects clickbait

## Summary

✅ **Architecture is production-ready** for AI integration
✅ **Simulated sentiment is perfectly fine** for portfolio/demo
✅ **Switching to real AI** requires minimal code changes
✅ **Demonstrates understanding** of ML in data pipelines

The key insight: **Quality-adjusted engagement prevents clickbait**, regardless of whether sentiment comes from AI or simulation. The architectural pattern is what matters for your portfolio!