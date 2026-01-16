import os
import time
import requests
from dotenv import load_dotenv
import snowflake.connector

# Load environment variables
load_dotenv()

# Configuration
HF_API_KEY = os.getenv('HUGGINGFACE_API_KEY')
HF_API_URL = os.getenv('HUGGINGFACE_API_URL')
SENTIMENT_MODEL = os.getenv('SENTIMENT_MODEL')

def get_snowflake_connection():
    """Connect to Snowflake"""
    return snowflake.connector.connect(
        account=os.getenv('SNOWFLAKE_ACCOUNT'),
        user=os.getenv('SNOWFLAKE_USER'),
        password=os.getenv('SNOWFLAKE_PASSWORD'),
        warehouse=os.getenv('SNOWFLAKE_WAREHOUSE'),
        database=os.getenv('SNOWFLAKE_DATABASE'),
        schema='dev_james_marts',  # Use marts schema where dim_articles lives
        role=os.getenv('SNOWFLAKE_ROLE')
    )

def get_sentiment(text):
    """Call Hugging Face API for sentiment analysis"""
    url = f"{HF_API_URL}/{SENTIMENT_MODEL}"
    headers = {"Authorization": f"Bearer {HF_API_KEY}"}
    
    response = requests.post(url, headers=headers, json={"inputs": text})
    
    if response.status_code == 200:
        results = response.json()[0]
        # Convert to dict keyed by label
        sentiment = {item['label']: item['score'] for item in results}
        return sentiment
    else:
        print(f"API Error {response.status_code}: {response.text}")
        return None

def enrich_articles():
    """Main enrichment process"""
    conn = get_snowflake_connection()
    cursor = conn.cursor()
    
    # Fetch articles without sentiment
    print("Fetching articles to enrich...")
    cursor.execute("""
        SELECT article_id, title
        FROM dim_articles
        WHERE sentiment_enriched_at IS NULL
        LIMIT 100  -- Start with 100 for testing
    """)
    
    articles = cursor.fetchall()
    print(f"Found {len(articles)} articles to enrich")
    
    enriched = 0
    failed = 0
    
    for article_id, title in articles:
        try:
            # Get sentiment
            sentiment = get_sentiment(title)
            
            if sentiment:
                positive = sentiment.get('POSITIVE', 0)
                negative = sentiment.get('NEGATIVE', 0)
                label = 'POSITIVE' if positive > negative else 'NEGATIVE'
                
                # Update Snowflake
                cursor.execute("""
                    UPDATE dim_articles
                    SET sentiment_score_positive = %s,
                        sentiment_score_negative = %s,
                        sentiment_label = %s,
                        sentiment_enriched_at = CURRENT_TIMESTAMP()
                    WHERE article_id = %s
                """, (positive, negative, label, article_id))
                
                enriched += 1
                
                if enriched % 10 == 0:
                    print(f"Progress: {enriched}/{len(articles)} articles enriched")
                    conn.commit()  # Commit in batches
            else:
                failed += 1
            
            # Rate limiting
            time.sleep(1)
            
        except Exception as e:
            print(f"Error processing {article_id}: {e}")
            failed += 1
            continue
    
    # Final commit
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"\n✅ Enrichment complete!")
    print(f"   Enriched: {enriched}")
    print(f"   Failed: {failed}")

if __name__ == "__main__":
    enrich_articles()