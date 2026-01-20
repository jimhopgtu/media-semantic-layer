"""
Hugging Face Sentiment Enrichment Script

Fetches articles from Snowflake, analyzes sentiment using Hugging Face API,
and updates the article_metadata table with AI-generated quality scores.

This demonstrates AI-in-production data pipeline integration.

Usage:
    python enrich_articles_sentiment.py --batch-size 100 --dry-run
    python enrich_articles_sentiment.py  # Run for real
"""

import os
import sys
import argparse
import time
from datetime import datetime
from typing import List, Dict, Optional
import requests
import snowflake.connector
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
HUGGINGFACE_API_KEY = os.getenv('HUGGINGFACE_API_KEY')
SNOWFLAKE_ACCOUNT = os.getenv('SNOWFLAKE_ACCOUNT')
SNOWFLAKE_USER = os.getenv('SNOWFLAKE_USER')
SNOWFLAKE_PASSWORD = os.getenv('SNOWFLAKE_PASSWORD')
SNOWFLAKE_DATABASE = os.getenv('SNOWFLAKE_DATABASE', 'MEDIA_ANALYTICS')
SNOWFLAKE_WAREHOUSE = os.getenv('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH')
SNOWFLAKE_SCHEMA = os.getenv('SNOWFLAKE_SCHEMA', 'RAW')

# Hugging Face API endpoint - UPDATED to new router URL
HF_API_URL = os.getenv(
    'HUGGINGFACE_API_URL',
    "https://api-inference.huggingface.co/models/distilbert/distilbert-base-uncased-finetuned-sst-2-english"
)

# If user set custom URL, append model name if not already there
if 'HUGGINGFACE_API_URL' in os.environ and 'distilbert' not in HF_API_URL.lower():
    HF_API_URL = f"{HF_API_URL}/distilbert/distilbert-base-uncased-finetuned-sst-2-english"


def get_snowflake_connection():
    """Create Snowflake connection."""
    return snowflake.connector.connect(
        account=SNOWFLAKE_ACCOUNT,
        user=SNOWFLAKE_USER,
        password=SNOWFLAKE_PASSWORD,
        database=SNOWFLAKE_DATABASE,
        warehouse=SNOWFLAKE_WAREHOUSE,
        schema=SNOWFLAKE_SCHEMA
    )


def fetch_unenriched_articles(conn, batch_size: int = 100) -> List[Dict]:
    """
    Fetch articles that haven't been enriched with sentiment yet.
    
    Returns list of dicts with article_id and title.
    """
    cursor = conn.cursor()
    
    query = f"""
    SELECT 
        article_id,
        title,
        category
    FROM article_metadata
    WHERE sentiment_enriched_at IS NULL
       OR sentiment_label IS NULL
    LIMIT {batch_size}
    """
    
    cursor.execute(query)
    
    articles = []
    for row in cursor:
        articles.append({
            'article_id': row[0],
            'title': row[1],
            'category': row[2]
        })
    
    cursor.close()
    return articles


def analyze_sentiment_batch(texts: List[str], api_key: str) -> List[Dict]:
    """
    Call Hugging Face API to analyze sentiment for a batch of texts.
    
    Returns list of sentiment results with scores and labels.
    """
    headers = {"Authorization": f"Bearer {api_key}"}
    
    results = []
    
    for text in texts:
        # Truncate to first 512 characters (model limit)
        truncated_text = text[:512]
        
        try:
            response = requests.post(
                HF_API_URL,
                headers=headers,
                json={"inputs": truncated_text},
                timeout=30
            )
            
            if response.status_code == 200:
                sentiment_output = response.json()
                
                # Parse Hugging Face response
                # Format: [[{'label': 'POSITIVE', 'score': 0.9998}, {'label': 'NEGATIVE', 'score': 0.0002}]]
                if isinstance(sentiment_output, list) and len(sentiment_output) > 0:
                    if isinstance(sentiment_output[0], list):
                        sentiment_data = sentiment_output[0]
                    else:
                        sentiment_data = sentiment_output
                    
                    # Find POSITIVE and NEGATIVE scores
                    positive_score = next((s['score'] for s in sentiment_data if s['label'] == 'POSITIVE'), 0.5)
                    negative_score = next((s['score'] for s in sentiment_data if s['label'] == 'NEGATIVE'), 0.5)
                    
                    # Determine overall label (highest score)
                    label = max(sentiment_data, key=lambda x: x['score'])['label']
                    
                    results.append({
                        'sentiment_score_positive': positive_score,
                        'sentiment_score_negative': negative_score,
                        'sentiment_label': label
                    })
                else:
                    # Fallback to neutral
                    results.append({
                        'sentiment_score_positive': 0.5,
                        'sentiment_score_negative': 0.5,
                        'sentiment_label': 'NEUTRAL'
                    })
            else:
                print(f"  API Error: {response.status_code} - {response.text}")
                # Fallback to neutral
                results.append({
                    'sentiment_score_positive': 0.5,
                    'sentiment_score_negative': 0.5,
                    'sentiment_label': 'NEUTRAL'
                })
            
            # Rate limiting: Wait between requests
            time.sleep(0.5)
            
        except Exception as e:
            print(f"  Error analyzing sentiment: {e}")
            # Fallback to neutral
            results.append({
                'sentiment_score_positive': 0.5,
                'sentiment_score_negative': 0.5,
                'sentiment_label': 'NEUTRAL'
            })
    
    return results


def update_article_sentiment(conn, article_id: str, sentiment: Dict, dry_run: bool = False):
    """
    Update article_metadata table with sentiment scores.
    """
    cursor = conn.cursor()
    
    update_query = """
    UPDATE article_metadata
    SET 
        sentiment_score_positive = %s,
        sentiment_score_negative = %s,
        sentiment_label = %s,
        sentiment_enriched_at = CURRENT_TIMESTAMP()
    WHERE article_id = %s
    """
    
    if dry_run:
        print(f"  [DRY RUN] Would update {article_id}: {sentiment['sentiment_label']} "
              f"(pos: {sentiment['sentiment_score_positive']:.3f})")
    else:
        cursor.execute(update_query, (
            sentiment['sentiment_score_positive'],
            sentiment['sentiment_score_negative'],
            sentiment['sentiment_label'],
            article_id
        ))
        conn.commit()
    
    cursor.close()


def main():
    parser = argparse.ArgumentParser(description='Enrich articles with Hugging Face sentiment analysis')
    parser.add_argument('--batch-size', type=int, default=100, help='Number of articles to process')
    parser.add_argument('--dry-run', action='store_true', help='Test without updating database')
    parser.add_argument('--limit', type=int, help='Maximum number of articles to process (for testing)')
    
    args = parser.parse_args()
    
    print("=" * 80)
    print("Hugging Face Sentiment Enrichment Script")
    print("=" * 80)
    print(f"Mode: {'DRY RUN' if args.dry_run else 'PRODUCTION'}")
    print(f"Batch size: {args.batch_size}")
    print(f"API URL: {HF_API_URL}")
    if args.limit:
        print(f"Limit: {args.limit} articles")
    print()
    
    # Validate environment
    if not HUGGINGFACE_API_KEY:
        print("ERROR: HUGGINGFACE_API_KEY not found in environment")
        print("Please set it in your .env file")
        sys.exit(1)
    
    if not all([SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD]):
        print("ERROR: Snowflake credentials not found in environment")
        sys.exit(1)
    
    print("✓ Environment validated")
    print()
    
    # Connect to Snowflake
    print("Connecting to Snowflake...")
    conn = get_snowflake_connection()
    print("✓ Connected to Snowflake")
    print()
    
    # Fetch unenriched articles
    print(f"Fetching up to {args.batch_size} unenriched articles...")
    articles = fetch_unenriched_articles(conn, args.batch_size)
    
    if args.limit and len(articles) > args.limit:
        articles = articles[:args.limit]
    
    print(f"✓ Found {len(articles)} articles to enrich")
    print()
    
    if len(articles) == 0:
        print("No articles to enrich. All done!")
        conn.close()
        return
    
    # Process articles
    print("Analyzing sentiment with Hugging Face API...")
    print()
    
    start_time = time.time()
    
    for i, article in enumerate(articles, 1):
        print(f"[{i}/{len(articles)}] Processing: {article['article_id']}")
        print(f"  Title: {article['title'][:60]}...")
        print(f"  Category: {article['category']}")
        
        # Analyze sentiment
        sentiments = analyze_sentiment_batch([article['title']], HUGGINGFACE_API_KEY)
        sentiment = sentiments[0]
        
        print(f"  Result: {sentiment['sentiment_label']} "
              f"(positive: {sentiment['sentiment_score_positive']:.3f}, "
              f"negative: {sentiment['sentiment_score_negative']:.3f})")
        
        # Update database
        update_article_sentiment(conn, article['article_id'], sentiment, args.dry_run)
        print()
    
    elapsed_time = time.time() - start_time
    
    print("=" * 80)
    print("Summary")
    print("=" * 80)
    print(f"Articles processed: {len(articles)}")
    print(f"Time elapsed: {elapsed_time:.1f} seconds")
    print(f"Average time per article: {elapsed_time/len(articles):.1f} seconds")
    
    if not args.dry_run:
        print()
        print("✓ Articles successfully enriched in Snowflake!")
        print()
        print("Next steps:")
        print("  1. Run: dbt run --select dim_articles")
        print("  2. Quality scores will now be based on real AI sentiment!")
    
    conn.close()


if __name__ == "__main__":
    main()
