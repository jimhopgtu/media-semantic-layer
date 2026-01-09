# 🚀 Media Analytics Semantic Layer - Project Kickoff

**Status:** Ready to start! All foundation materials created.

---

## 📦 What You're Getting

This package contains everything you need to build a production-grade, AI-enriched analytics platform over 2 weeks.

### Core Files Created

```
media-semantic-layer/
├── 📄 README.md                          # Main project documentation
├── 📄 requirements.txt                   # Python dependencies
├── 📄 .gitignore                        # Git ignore rules
├── 📄 .env.template                     # Environment config template
│
├── 🐍 generate_synthetic_data.py        # Data generator (500K events)
│
├── dbt_project/
│   ├── dbt_project.yml                  # dbt configuration
│   └── models/semantic/
│       ├── _semantic_models.yml         # ⭐ Entities & measures
│       └── _metrics.yml                 # ⭐ 7 governed metrics
│
├── scripts/
│   ├── load_to_snowflake.py            # Automated data loading
│   └── snowflake/
│       ├── create_tables.sql            # Table DDL
│       └── load_data.sql                # Data loading SQL
│
└── docs/
    ├── setup_guide.md                   # Day 0: Tool setup (2-3h)
    └── week1_roadmap.md                 # Week 1: Dev plan (16-18h)
```

---

## 🎯 Project Goals Recap

**Business Story:**
> "Built an AI-enriched content analytics system modeling real-world media operations. The dbt Semantic Layer governs metrics for writer productivity, content engagement, and revenue attribution—with sentiment analysis augmenting editorial quality scores."

**Technical Showcase:**
1. ✅ **dbt Semantic Layer** - Governed metrics (like your Arena Group Looker work, but modern)
2. ✅ **AI Integration** - Hugging Face sentiment in production pipeline
3. ✅ **Data Contracts** - Professional specs for all tables
4. ✅ **GA4-Style Data** - Realistic event-based analytics (mirrors your migrations)
5. ✅ **Orchestration** - Airflow DAG (coming Week 2)
6. ✅ **Self-Service** - Superset dashboards (coming Week 2)

---

## 🗓️ Your 2-Week Timeline

### **Week 1: Core Platform** (16-18 hours)

| Day | Focus | Hours | Deliverables |
|-----|-------|-------|--------------|
| **Friday (Today)** | Setup & prep | 2-3h | Accounts, data generated, loaded to Snowflake |
| **Monday** | Staging models | 4-5h | stg_ga4_events, stg_articles, stg_writers |
| **Tuesday** | Facts & dims | 4-5h | fct_article_events, dim_articles, dim_writers |
| **Wednesday** | Semantic layer | 5-6h | 7 metrics defined, MetricFlow tested |
| **Thursday** | HF enrichment | 4-5h | 5K articles with sentiment scores |
| **Friday** | Testing & docs | 3-4h | All tests passing, README updated |

### **Week 2: Orchestration & Dashboards** (8-10 hours)

| Day | Focus | Hours | Deliverables |
|-----|-------|-------|--------------|
| **Monday-Tuesday** | Airflow DAG | 4-5h | Orchestrated pipeline deployed to Astro |
| **Wednesday** | CI/CD | 2h | GitHub Actions for dbt test/deploy |
| **Thursday** | Superset | 3h | 2 dashboards consuming semantic layer |
| **Friday** | Polish | 2h | Demo video, LinkedIn post, final README |

---

## ✅ Today's Action Items (2-3 hours)

### Step 1: Tool Account Setup (60 min)

Follow `docs/setup_guide.md` to create accounts for:
- [ ] Snowflake (free trial)
- [ ] dbt Cloud (developer tier)
- [ ] Astro/Airflow (free tier)
- [ ] Hugging Face (get API token)
- [ ] Preset/Superset (free trial)
- [ ] GitHub repo created

### Step 2: Local Environment (30 min)

```bash
# Clone or create repo
git clone https://github.com/YOUR_USERNAME/media-semantic-layer.git
cd media-semantic-layer

# Copy all files from this package into repo
# (Or start fresh and use files as reference)

# Create Python venv
python -m venv venv
source venv/Scripts/activate  # Windows Git Bash
# or: .\venv\Scripts\activate  # Windows PowerShell

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.template .env
# Edit .env with your credentials
```

### Step 3: Generate & Load Data (45 min)

```bash
# Generate synthetic data (5-10 min)
python generate_synthetic_data.py --output-dir ./data

# Verify output
ls -lh data/
# Should see: writers.csv, articles.csv, events.jsonl

# Load to Snowflake (10-15 min)
python scripts/load_to_snowflake.py

# Or use Snowflake UI to load files manually
```

### Step 4: Validation (15 min)

**In Snowflake Web UI:**
```sql
USE DATABASE media_analytics;
USE SCHEMA raw;

-- Check row counts
SELECT 'writers' as tbl, COUNT(*) as cnt FROM writer_metadata
UNION ALL
SELECT 'articles', COUNT(*) FROM article_metadata
UNION ALL
SELECT 'events', COUNT(*) FROM events_raw;

-- Expected:
-- writers:  75
-- articles: 5,000
-- events:   500,000+

-- Quick validation query
SELECT 
    a.category,
    COUNT(DISTINCT a.article_id) as articles,
    COUNT(CASE WHEN e.event_name = 'page_view' THEN 1 END) as pageviews
FROM article_metadata a
LEFT JOIN events_raw e 
    ON e.event_params[0]:value:string_value::STRING = a.article_id
GROUP BY a.category
ORDER BY pageviews DESC;
```

**Expected output:** ~5 categories with pageview counts

---

## 🎓 Key Files to Understand First

Before Monday, familiarize yourself with:

### 1. **Data Contracts** (in README.md)
- Contract 1: GA4 Events (500K rows)
- Contract 2: Articles (5K rows)  
- Contract 3: Writers (75 rows)
- Contract 4: Semantic Layer Metrics (7 metrics)

**Why it matters:** Interviews love hearing "I defined data contracts" - shows maturity.

### 2. **Semantic Models** (dbt_project/models/semantic/_semantic_models.yml)
```yaml
semantic_models:
  - name: article_events
    entities:
      - name: article (foreign key)
      - name: writer (foreign key)
    measures:
      - name: pageviews (count)
      - name: unique_users (count_distinct)
    dimensions:
      - name: category (categorical)
      - name: event_date (time)
```

**Why it matters:** This is the governance layer - the centerpiece of your project.

### 3. **Metrics** (dbt_project/models/semantic/_metrics.yml)
```yaml
metrics:
  - name: total_pageviews
    type: simple
    type_params:
      measure: pageviews
  
  - name: sentiment_adjusted_engagement
    type: derived
    type_params:
      expr: avg_engagement_time * avg_sentiment_positive
```

**Why it matters:** These are the "governed KPIs" you'll talk about in interviews.

---

## 🎤 Elevator Pitch (Practice This!)

> "I built a production-grade analytics platform similar to what I delivered at Arena Group - but modernized with dbt's Semantic Layer instead of Looker. The system processes GA4-style events for 5,000 articles and 75 writers, calculating engagement and revenue metrics.
>
> What makes it unique is the AI integration: I used Hugging Face to enrich articles with sentiment scores, then created a composite metric combining behavioral engagement with AI-detected content quality. The whole pipeline is orchestrated with Airflow and exposed through Superset dashboards.
>
> The semantic layer defines entities and metrics in code, enabling business users to self-serve without writing SQL - exactly the self-service culture I built at Hearst and Arena Group."

**Follow-up questions you'll get:**
- "How does the semantic layer differ from Looker?" → "MetricFlow is the open-source standard, supports multiple BI tools, better versioning..."
- "Why Hugging Face vs other ML?" → "Zero infrastructure, production-ready APIs, shows I can integrate AI without heavy MLOps..."
- "How long did this take?" → "Two weeks part-time, ~24 hours total. Shows I can move fast on modern tools."

---

## 💡 Pro Tips for Success

### Use Claude Effectively

**Good prompts:**
- "Generate dbt staging model to unnest GA4 event_params array"
- "Write SQL to calculate engagement_time_sec from milliseconds"
- "Review this model for performance issues"
- "Explain how to test referential integrity in dbt"

**Avoid:**
- "Build my entire project" (too vague)
- Copy-pasting without understanding
- Not reviewing generated code

### Git Hygiene

**Commit after each major milestone:**
```bash
git add .
git commit -m "Add staging models for GA4 events"
git push

# Makes your GitHub profile show consistent activity
```

### Documentation First

**Write descriptions as you code:**
```yaml
models:
  - name: fct_article_events
    description: |
      Event-level fact table combining GA4 events with article/writer context.
      Each row represents one user interaction (pageview, scroll, engagement).
      Used as foundation for all semantic layer metrics.
```

This pays off in interviews when you can explain your architecture clearly.

### Test Incrementally

```bash
# Don't wait to test everything at once!
dbt run -m stg_ga4_events
dbt test -m stg_ga4_events

# Fix issues immediately, then move to next model
```

---

## 🆘 When You Get Stuck

### Common Issues & Solutions

**Snowflake connection fails:**
- Check account locator format (no https://, no .snowflakecomputing.com suffix)
- Verify warehouse is running (COMPUTE_WH)
- Test with SnowSQL CLI first

**dbt compilation errors:**
- Check ref() and source() calls
- Validate YAML syntax (use yamllint or VSCode extension)
- Look for typos in model names

**Hugging Face API errors:**
- Check API token is correct: `hf_...`
- Model may be loading (wait 20 seconds, retry)
- Reduce batch size if rate limited

**MetricFlow queries fail:**
- Ensure dbt models are materialized first: `dbt run`
- Check semantic_models.yml references correct ref('model_name')
- Validate metric formulas don't reference missing measures

### Getting Help

1. **Check docs first:** docs/setup_guide.md, docs/week1_roadmap.md
2. **Search dbt Discourse:** https://discourse.getdbt.com/
3. **Ask Claude:** Paste error + context, get specific fix
4. **GitHub Issues:** Create issue in your repo for tracking

---

## 📈 Success Metrics

**By end of Week 1, you'll have:**
- ✅ 500K+ events loaded to Snowflake
- ✅ 7 working dbt models (3 staging, 3 marts, 1 semantic)
- ✅ 7 semantic layer metrics queryable via MetricFlow
- ✅ 5,000 articles enriched with AI sentiment scores
- ✅ 25+ passing dbt tests
- ✅ Professional README with architecture diagram
- ✅ 15-20 GitHub commits showing progress

**Interview readiness:**
- ✅ Can explain semantic layer vs traditional BI
- ✅ Can demo AI enrichment in production pipeline
- ✅ Can query metrics using natural language (via MetricFlow)
- ✅ Can discuss data contracts and governance

---

## 🎯 What Makes This Portfolio Piece Strong

1. **Directly relevant to your background:**
   - Arena Group: Writer profitability analytics → This: Writer revenue metrics
   - FOX/Hearst: GA4 migrations → This: GA4-style event processing
   - All roles: Semantic layers → This: Modern dbt semantic layer

2. **Shows AI-native skills:**
   - Not just "I know ML" - you integrated Hugging Face into prod pipeline
   - Sentiment-augmented metrics show creative use of AI
   - Demonstrates you can leverage AI tools (Claude) for development

3. **Production-grade:**
   - Data contracts (real companies use these)
   - CI/CD with GitHub Actions (not just local scripts)
   - Orchestration with Airflow (shows you think about operations)
   - Tests and documentation (shows maturity)

4. **Current tech stack (2025-2026):**
   - dbt Semantic Layer (hot topic, growing fast)
   - Snowflake (industry standard)
   - Hugging Face (de facto standard for ML APIs)
   - Claude Code (shows you're an early adopter)

---

## 🚀 Ready to Start?

You have everything you need! The hard prep work is done.

**Your weekend homework (optional, 1 hour):**
- [ ] Read setup_guide.md fully
- [ ] Watch dbt Semantic Layer intro video (YouTube, 15 min)
- [ ] Review your Arena Group Looker work - note similarities

**Monday morning, you'll hit the ground running!**

---

**Questions? Issues? Feedback?**

Create a GitHub issue in your repo or ask Claude. Good luck! 🎉

---

*Files created: Friday, January 10, 2025*  
*Estimated project completion: Friday, January 24, 2025*  
*Total effort: 24 hours over 2 weeks*
