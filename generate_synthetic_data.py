"""
Synthetic Media Analytics Data Generator
Generates GA4-style events, article metadata, and writer metadata
matching the data contract specifications.

Usage:
    python generate_synthetic_data.py --output-dir ./data
"""

import json
import random
import csv
from datetime import datetime, timedelta
from typing import List, Dict
import uuid
import argparse
from pathlib import Path

# Configuration matching data contracts
CONFIG = {
    "start_date": "2024-10-01",
    "end_date": "2025-01-07",
    "num_writers": 75,
    "num_articles": 5000,
    "target_events": 500000,  # Aiming for 500K-1M events
    "categories": ["sports", "finance", "lifestyle", "news", "opinion"],
    "event_types": ["page_view", "scroll", "user_engagement", "click", "view_item"],
    "devices": ["desktop", "mobile", "tablet"],
    "browsers": {
        "desktop": ["Chrome", "Firefox", "Edge", "Safari"],
        "mobile": ["Chrome", "Safari"],
        "tablet": ["Safari", "Chrome"]
    },
    "operating_systems": {
        "desktop": ["Windows", "macOS", "Linux"],
        "mobile": ["iOS", "Android"],
        "tablet": ["iOS", "Android"]
    },
    "traffic_sources": [
        ("google", "organic"),
        ("facebook", "social"),
        ("twitter", "social"),
        ("direct", "none"),
        ("newsletter", "email"),
        ("bing", "organic"),
    ]
}


def generate_writers(num_writers: int) -> List[Dict]:
    """Generate writer metadata according to Contract 3"""
    writers = []
    first_names = ["James", "Sarah", "Michael", "Emily", "David", "Jessica", "Robert", "Amanda", 
                   "John", "Lisa", "William", "Jennifer", "Richard", "Maria", "Thomas"]
    last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
                  "Rodriguez", "Martinez", "Hernandez", "Lopez", "Wilson", "Anderson", "Taylor"]
    
    for i in range(num_writers):
        writer_id = f"writer_{i+1:03d}"
        category = random.choice(CONFIG["categories"])
        contract_type = random.choices(
            ["staff", "freelance", "contractor"],
            weights=[0.5, 0.3, 0.2]
        )[0]
        
        # Staff writers have higher article targets
        if contract_type == "staff":
            target = random.randint(15, 50)
        else:
            target = random.randint(5, 20)
        
        # Tenure between 2020 and 2024
        start_year = random.randint(2020, 2024)
        start_month = random.randint(1, 12)
        tenure_start = datetime(start_year, start_month, 1).date()
        
        writers.append({
            "writer_id": writer_id,
            "writer_name": f"{random.choice(first_names)} {random.choice(last_names)}",
            "primary_category": category,
            "tenure_start_date": tenure_start.isoformat(),
            "contract_type": contract_type,
            "target_articles_per_month": target
        })
    
    return writers


def generate_articles(num_articles: int, writers: List[Dict]) -> List[Dict]:
    """Generate article metadata according to Contract 2"""
    articles = []
    
    # Title templates by category
    title_templates = {
        "sports": [
            "{team} Dominates {opponent} in Playoff Showdown",
            "Breaking: {player} Signs Record-Breaking Contract",
            "{sport} Season Preview: Top Contenders and Dark Horses",
            "Analysis: Why {team}'s Strategy Could Win the Championship"
        ],
        "finance": [
            "{company} Stock Soars {percent}% on Earnings Beat",
            "Market Analysis: {sector} Sector Outlook for {year}",
            "Fed Decision: What {rate} Rate Change Means for Investors",
            "{company} CEO Discusses Growth Strategy and Market Position"
        ],
        "lifestyle": [
            "The Ultimate Guide to {topic} in {year}",
            "{number} Ways to Improve Your {area} This {season}",
            "Trending Now: {trend} Takes Over Social Media",
            "Expert Tips: How to Master {skill} in {timeframe}"
        ],
        "news": [
            "Breaking: {event} Unfolds in {location}",
            "{topic} Update: What You Need to Know Today",
            "Analysis: The Impact of {event} on {sector}",
            "{location} Residents React to {event}"
        ],
        "opinion": [
            "Why {topic} Matters More Than Ever in {year}",
            "The Case for {position} in Today's {context}",
            "Unpopular Opinion: {statement}",
            "Commentary: {topic} and Its Implications for {audience}"
        ]
    }
    
    start_date = datetime.strptime(CONFIG["start_date"], "%Y-%m-%d")
    end_date = datetime.strptime(CONFIG["end_date"], "%Y-%m-%d")
    date_range = (end_date - start_date).days
    
    for i in range(num_articles):
        article_id = f"art_{i+1:04d}"
        
        # Select writer and inherit category (70% match, 30% writer diversifies)
        writer = random.choice(writers)
        if random.random() < 0.7:
            category = writer["primary_category"]
        else:
            category = random.choice(CONFIG["categories"])
        
        # Generate title from template
        template = random.choice(title_templates[category])
        title = template.format(
            team=random.choice(["Lakers", "Yankees", "Patriots", "Warriors"]),
            opponent=random.choice(["Celtics", "Red Sox", "Chiefs", "Mavericks"]),
            player=random.choice(["LeBron", "Judge", "Mahomes", "Curry"]),
            sport=random.choice(["NFL", "NBA", "MLB", "NHL"]),
            company=random.choice(["Tesla", "Apple", "Amazon", "Microsoft"]),
            percent=random.randint(5, 25),
            sector=random.choice(["Tech", "Energy", "Healthcare", "Finance"]),
            year=random.choice(["2025", "2026"]),
            rate=random.choice(["Interest", "Inflation", "Growth"]),
            topic=random.choice(["Travel", "Wellness", "Technology", "Housing"]),
            number=random.choice(["5", "7", "10", "15"]),
            area=random.choice(["Health", "Career", "Relationships", "Finances"]),
            season=random.choice(["Spring", "Summer", "Fall", "Winter"]),
            trend=random.choice(["Minimalism", "Plant-Based Eating", "Remote Work", "Mindfulness"]),
            skill=random.choice(["Cooking", "Investing", "Photography", "Coding"]),
            timeframe=random.choice(["30 Days", "3 Months", "This Year"]),
            event=random.choice(["Summit", "Policy Change", "Economic Shift", "Crisis"]),
            location=random.choice(["New York", "California", "Texas", "Florida"]),
            position=random.choice(["Reform", "Innovation", "Change", "Action"]),
            context=random.choice(["Economy", "Society", "Politics", "World"]),
            statement=random.choice(["We Need More Regulation", "Markets Are Efficient", "Change is Overdue"]),
            audience=random.choice(["Consumers", "Businesses", "Investors", "Society"])
        )
        
        # Publish date weighted toward recent (more recent = more articles)
        # Use exponential distribution to favor recent dates
        days_ago = int(random.expovariate(1.0 / (date_range / 3)))
        days_ago = min(days_ago, date_range)
        publish_date = end_date - timedelta(days=days_ago)
        
        # Word count and premium status
        word_count = random.randint(300, 3000)
        is_premium = random.random() < 0.20  # 20% premium
        
        # RPM (revenue per thousand views)
        # Premium articles have higher RPM
        if is_premium:
            estimated_rpm = round(random.uniform(8.0, 15.0), 2)
        else:
            estimated_rpm = round(random.uniform(1.5, 7.5), 2)
        
        articles.append({
            "article_id": article_id,
            "title": title,
            "writer_id": writer["writer_id"],
            "publish_date": publish_date.date().isoformat(),
            "category": category,
            "word_count": word_count,
            "is_premium": is_premium,
            "estimated_rpm": estimated_rpm,
            # Sentiment fields will be populated by enrichment pipeline
            "sentiment_score_positive": None,
            "sentiment_score_negative": None,
            "sentiment_label": None,
            "sentiment_enriched_at": None
        })
    
    # Sort by publish date
    articles.sort(key=lambda x: x["publish_date"])
    
    return articles


def generate_user_id() -> str:
    """Generate realistic GA4-style user pseudo ID"""
    timestamp = int(datetime.now().timestamp())
    random_str = ''.join(random.choices('abcdefghijklmnopqrstuvwxyz0123456789', k=10))
    return f"{timestamp}.{random_str}"


def generate_session_id(timestamp: int) -> str:
    """Generate GA4-style session ID"""
    random_num = random.randint(1000000, 9999999)
    return f"{timestamp}.{random_num}"


def generate_events(articles: List[Dict], target_events: int) -> List[Dict]:
    """Generate GA4-style events according to Contract 1 - OPTIMIZED VERSION"""
    
    start_date = datetime.strptime(CONFIG["start_date"], "%Y-%m-%d")
    end_date = datetime.strptime(CONFIG["end_date"], "%Y-%m-%d")
    date_range_days = (end_date - start_date).days
    
    # Pre-compute article publish dates as datetime objects for faster comparison
    article_publish_dates = []
    for article in articles:
        pub_date = datetime.strptime(article["publish_date"], "%Y-%m-%d")
        article_publish_dates.append(pub_date)
    
    # Pre-compute article weights once
    article_weights = []
    for pub_date in article_publish_dates:
        days_old = (end_date - pub_date).days
        weight = max(1, 100 * (0.95 ** days_old))
        article_weights.append(weight)
    
    # Pre-generate user pool
    print(f"Generating {target_events} events...")
    print("  Creating user pool...")
    num_users = 50000
    user_pool = [generate_user_id() for _ in range(num_users)]
    
    # Pre-generate random choices for efficiency
    print("  Pre-generating random data...")
    event_types = random.choices(
        CONFIG["event_types"],
        weights=[80, 5, 10, 3, 2],
        k=target_events
    )
    
    article_indices = random.choices(
        range(len(articles)),
        weights=article_weights,
        k=target_events
    )
    
    user_indices = random.choices(range(num_users), k=target_events)
    
    device_categories = random.choices(
        CONFIG["devices"],
        weights=[45, 50, 5],
        k=target_events
    )
    
    countries = random.choices(["US", "CA", "GB", "AU"], weights=[85, 5, 5, 5], k=target_events)
    
    hour_weights = [2, 1, 1, 1, 1, 2, 3, 5, 7, 8, 9, 9, 9, 8, 8, 8, 9, 10, 10, 9, 8, 6, 4, 3]
    hours = random.choices(range(24), weights=hour_weights, k=target_events)
    
    # Pre-generate random date offsets
    days_offsets = [random.randint(0, date_range_days) for _ in range(target_events)]
    
    # Traffic sources
    traffic_source_choices = random.choices(
        CONFIG["traffic_sources"],
        weights=[40, 15, 10, 20, 10, 5],
        k=target_events
    )
    
    # Static data
    us_states = ["NY", "CA", "TX", "FL", "IL", "PA", "OH", "GA", "NC", "MI"]
    cities = {
        "NY": ["New York", "Buffalo", "Rochester"],
        "CA": ["Los Angeles", "San Francisco", "San Diego"],
        "TX": ["Houston", "Dallas", "Austin"]
    }
    
    print("  Generating events in batches...")
    events = []
    filtered_count = 0
    
    for i in range(target_events):
        if i % 50000 == 0 and i > 0:
            print(f"  Progress: {i}/{target_events} events generated ({len(events)} kept, {filtered_count} filtered)")
        
        # Use pre-generated random data
        event_name = event_types[i]
        article_idx = article_indices[i]
        article = articles[article_idx]
        user_pseudo_id = user_pool[user_indices[i]]
        device_category = device_categories[i]
        country = countries[i]
        hour = hours[i]
        source, medium = traffic_source_choices[i]
        days_offset = days_offsets[i]
        
        # Generate timestamp
        event_date = start_date + timedelta(days=days_offset)
        event_datetime = event_date.replace(
            hour=hour,
            minute=random.randint(0, 59),
            second=random.randint(0, 59),
            microsecond=random.randint(0, 999999)
        )
        
        # Date validation - skip if article not yet published
        # Only compare dates (ignore time) to be less strict
        article_pub_date = article_publish_dates[article_idx]
        if event_date.date() < article_pub_date.date():
            filtered_count += 1
            continue
        
        event_timestamp = int(event_datetime.timestamp() * 1000000)
        ga_session_id = generate_session_id(int(event_datetime.timestamp()))
        
        # Device details
        browser = random.choice(CONFIG["browsers"][device_category])
        operating_system = random.choice(CONFIG["operating_systems"][device_category])
        
        # Geo
        region = random.choice(us_states) if country == "US" else ""
        city = random.choice(cities.get(region, ["Unknown"]))
        
        # Campaign
        campaign = None
        if medium in ["social", "email"]:
            campaign = f"{medium}_campaign_{random.randint(1, 5)}"
        
        # Event params
        event_params = [
            {"key": "article_id", "value": {"string_value": article["article_id"]}},
            {"key": "writer_id", "value": {"string_value": article["writer_id"]}}
        ]
        
        if event_name == "page_view":
            page_location = f"https://example-media.com/{article['category']}/{article['article_id']}"
            event_params.extend([
                {"key": "page_location", "value": {"string_value": page_location}},
                {"key": "page_title", "value": {"string_value": article["title"]}}
            ])
        elif event_name == "scroll":
            percent_scrolled = random.choices([25, 50, 75, 90, 100], weights=[10, 20, 30, 25, 15])[0]
            event_params.append({"key": "percent_scrolled", "value": {"int_value": percent_scrolled}})
        elif event_name == "user_engagement":
            engagement_time = int(random.lognormvariate(4.5, 0.8) * 1000)
            engagement_time = max(5000, min(300000, engagement_time))
            event_params.append({"key": "engagement_time_msec", "value": {"int_value": engagement_time}})
        
        # Build event record
        event = {
            "event_date": event_datetime.strftime("%Y%m%d"),
            "event_timestamp": event_timestamp,
            "event_name": event_name,
            "user_pseudo_id": user_pseudo_id,
            "ga_session_id": ga_session_id,
            "event_params": event_params,
            "device": {
                "category": device_category,
                "operating_system": operating_system,
                "browser": browser
            },
            "geo": {
                "country": country,
                "region": region,
                "city": city
            },
            "traffic_source": {
                "source": source,
                "medium": medium,
                "campaign": campaign
            }
        }
        
        events.append(event)
    
    print(f"  Generated {len(events)} events ({filtered_count} filtered out due to publish dates)")
    print("  Sorting events by timestamp...")
    events.sort(key=lambda x: x["event_timestamp"])
    
    return events


def save_data(output_dir: Path, writers: List[Dict], articles: List[Dict], events: List[Dict]):
    """Save generated data to CSV and JSON files"""
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Save writers as CSV
    print(f"Saving {len(writers)} writers to {output_dir}/writers.csv")
    with open(output_dir / "writers.csv", "w", newline="", encoding="utf-8") as f:
        if writers:
            writer = csv.DictWriter(f, fieldnames=writers[0].keys())
            writer.writeheader()
            writer.writerows(writers)
    
    # Save articles as CSV
    print(f"Saving {len(articles)} articles to {output_dir}/articles.csv")
    with open(output_dir / "articles.csv", "w", newline="", encoding="utf-8") as f:
        if articles:
            writer = csv.DictWriter(f, fieldnames=articles[0].keys())
            writer.writeheader()
            writer.writerows(articles)
    
    # Save events as JSONL (one JSON object per line, like GA4 BigQuery export)
    print(f"Saving {len(events)} events to {output_dir}/events.jsonl")
    with open(output_dir / "events.jsonl", "w", encoding="utf-8") as f:
        for event in events:
            f.write(json.dumps(event) + "\n")
    
    print(f"\n✅ Data generation complete!")
    print(f"   Writers: {len(writers)}")
    print(f"   Articles: {len(articles)}")
    print(f"   Events: {len(events)}")
    print(f"\nFiles created in: {output_dir.absolute()}")


def main():
    parser = argparse.ArgumentParser(description="Generate synthetic media analytics data")
    parser.add_argument("--output-dir", default="./data", help="Output directory for data files")
    parser.add_argument("--num-writers", type=int, default=75, help="Number of writers to generate")
    parser.add_argument("--num-articles", type=int, default=5000, help="Number of articles to generate")
    parser.add_argument("--num-events", type=int, default=500000, help="Number of events to generate")
    
    args = parser.parse_args()
    
    output_dir = Path(args.output_dir)
    
    print("=" * 60)
    print("Synthetic Media Analytics Data Generator")
    print("=" * 60)
    print(f"Date range: {CONFIG['start_date']} to {CONFIG['end_date']}")
    print(f"Target: {args.num_writers} writers, {args.num_articles} articles, {args.num_events} events")
    print()
    
    print("Step 1/3: Generating writers...")
    writers = generate_writers(args.num_writers)
    print(f"  ✓ Generated {len(writers)} writers")
    
    print("\nStep 2/3: Generating articles...")
    articles = generate_articles(args.num_articles, writers)
    print(f"  ✓ Generated {len(articles)} articles")
    
    print("\nStep 3/3: Generating events...")
    events = generate_events(articles, args.num_events)
    print(f"  ✓ Generated {len(events)} events")
    
    print("\nSaving data...")
    save_data(output_dir, writers, articles, events)


if __name__ == "__main__":
    main()