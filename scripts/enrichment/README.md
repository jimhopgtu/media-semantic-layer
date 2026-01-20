# AI Sentiment Enrichment

This script enriches article titles with real sentiment analysis from Hugging Face's DistilBERT model.

## Setup

### 1. Get Hugging Face API Key

1. Go to https://huggingface.co/
2. Sign up for free account
3. Go to Settings → Access Tokens
4. Create a new token (read access is sufficient)
5. Copy the token

### 2. Add to .env File

```bash
# Add this to your .env file in project root
HUGGINGFACE_API_KEY=hf_YourActualTokenHere
```

### 3. Install Dependencies

```bash
pip install requests snowflake-connector-python python-dotenv
```

## Usage

### Test First (Dry Run)

Process 10 articles without updating database:

```bash
cd scripts/enrichment
python enrich_articles_sentiment.py --batch-size 10 --dry-run
```

### Run for Real

Enrich 100 articles:

```bash
python enrich_articles_sentiment.py --batch-size 100
```

Enrich ALL articles (may take a while):

```bash
python enrich_articles_sentiment.py --batch-size 5000
```

## What It Does

1. **Fetches** unenriched articles from Snowflake `article_metadata` table
2. **Analyzes** article titles using Hugging Face DistilBERT sentiment model
3. **Updates** articles with:
   - `sentiment_score_positive` (0-1)
   - `sentiment_score_negative` (0-1)
   - `sentiment_label` (POSITIVE or NEGATIVE)
   - `sentiment_enriched_at` (timestamp)

## After Enrichment

Rebuild dbt models to use real AI sentiment:

```bash
cd ../../dbt_project
dbt run --select dim_articles fct_article_events
dbt run --select mart_article_performance experiment_results
```

Now your `quality_score` and `quality_adjusted_engagement` metrics use **real AI sentiment** instead of simulated values!

## Model Details

**Model:** `distilbert-base-uncased-finetuned-sst-2-english`
- **Type:** Sentiment Analysis
- **Training:** Stanford Sentiment Treebank (SST-2)
- **Output:** POSITIVE or NEGATIVE with confidence scores
- **Speed:** ~0.5 seconds per article
- **Accuracy:** ~91% on SST-2 test set

## Rate Limiting

The script includes:
- 0.5 second delay between API calls
- Automatic retry logic
- Graceful fallback to NEUTRAL on errors

Hugging Face free tier allows ~1000 requests/hour.

## Example Output

```
[1/10] Processing: art_1234
  Title: Warriors Dominates Mavericks in Playoff Showdown...
  Category: sports
  Result: POSITIVE (positive: 0.892, negative: 0.108)

[2/10] Processing: art_5678
  Title: Commentary: Crisis Unfolds in Texas...
  Category: news
  Result: NEGATIVE (positive: 0.145, negative: 0.855)
```

## Quality Score Calculation

After enrichment, `dim_articles` calculates:

```sql
quality_score = CASE 
    WHEN sentiment_label = 'POSITIVE' THEN sentiment_score_positive
    WHEN sentiment_label = 'NEGATIVE' THEN 1 - sentiment_score_negative  
    ELSE 0.5
END
```

This score (0-1) is then used in `quality_adjusted_engagement` to prevent clickbait optimization!

## Troubleshooting

**Error: "HUGGINGFACE_API_KEY not found"**
- Make sure you've added it to your `.env` file
- The `.env` file should be in the project root

**Error: "Model is loading"**
- Hugging Face models "cold start" if not used recently
- Wait 20 seconds and try again
- The model will stay warm for ~15 minutes

**Error: "Rate limit exceeded"**
- Free tier allows ~1000 requests/hour
- Wait an hour or use smaller batch sizes
- Consider upgrading to Hugging Face Pro ($9/month for unlimited)

## Production Considerations

For production at scale, you would:

1. **Use local model** - Download and run DistilBERT locally (no API calls)
2. **Batch processing** - Send multiple texts in one API call
3. **Airflow scheduling** - Run enrichment daily for new articles
4. **Monitoring** - Track enrichment lag and API errors
5. **Caching** - Don't re-analyze articles unless title changes