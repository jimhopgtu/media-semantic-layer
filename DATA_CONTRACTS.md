# Data Contracts - Experimentation Platform

**What data we track, why it matters, and how we ensure quality**

---

## 📋 Quick Reference

| Table | What It Stores | Business Purpose | Row Count |
|-------|---------------|------------------|-----------|
| experiments | Test configurations | "What are we testing?" | ~20 |
| article_variants | Different versions | "What's the control vs treatment?" | ~70 |
| experiment_assignments | Who saw what | "Fair randomization audit trail" | ~250K |
| events | User behavior | "Did they engage?" | ~500K |
| experiment_results | Statistical outcomes | "Did we find a winner?" | ~60 |
| writer_metadata | Author profiles | "Who writes this content?" | 75 |
| article_metadata | Content catalog | "What articles exist?" | 5,000 |

---

## 💡 Core Concept: What Is a Data Contract?

**Business definition:** A promise about what data looks like and what it means

**Why it matters:**
- **Prevents confusion:** Everyone agrees "engagement" means "60+ seconds OR 75% scroll"
- **Catches errors early:** If article_id is supposed to start with "art_" and one starts with "test_", we catch it
- **Enables automation:** Airflow can monitor experiments because it knows exactly what to expect
- **Builds trust:** Executives trust results when they see quality checks passed

**Analogy:** Like a legal contract but for data—specifies what's required, what's optional, what's allowed

---

## 📊 Contract 1: Experiments

### **Business Purpose**
Tracks what A/B tests we're running: the hypothesis, timeframe, and success criteria

### **What Questions It Answers**
- "What experiments are currently active?"
- "When does the headline test end?"
- "What lift are we trying to detect?"
- "How confident do we need to be before declaring a winner?"

### **Key Fields (Business View)**

| Field | What It Means | Example | Why It Matters |
|-------|--------------|---------|----------------|
| `experiment_name` | Human-readable test name | "Question vs Statement Headlines" | So people know what we're testing |
| `hypothesis` | What we think will happen | "Question headlines increase engagement 10%+" | Documents our reasoning |
| `start_date` / `end_date` | Test duration | Nov 15 - Dec 1 (16 days) | Determines when to check results |
| `target_metric` | What we're optimizing | "engagement_rate" | Defines success |
| `minimum_detectable_effect` | Smallest lift worth finding | 5% (0.05) | Determines sample size needed |
| `significance_level` | Confidence threshold | 0.05 (95% confidence) | How sure we need to be |

### **Business Rules**

✅ **Duration:** Tests must run 7-30 days
- Why: <7 days = unreliable (weekend vs weekday effects), >30 days = too slow

✅ **Traffic allocation:** 10-100% of traffic can be in experiment  
- Why: Sometimes we test on subset first (10%), then scale (100%)

✅ **No more than 3 overlapping experiments per category**
- Why: Too many = cannibalize each other's traffic, results unreliable

### **Example Record (Plain English)**

```
Experiment: "Question vs Statement Headlines for Sports"
Hypothesis: "Question format increases engagement 10%+"
Running: Nov 15 - Dec 1, 2024 (16 days)
Target: Detect 10% lift with 95% confidence
Traffic: 50% of sports visitors
Status: Completed
```

<details>
<summary><b>📐 Technical Schema (Click to expand)</b></summary>

| Field | Type | Required | Validation Rules |
|-------|------|----------|------------------|
| `experiment_id` | STRING | Yes | Format: `exp_\d{3}` |
| `experiment_name` | STRING | Yes | Length: 10-100 chars |
| `hypothesis` | STRING | Yes | Length: 20-500 chars |
| `variant_type` | STRING | Yes | Enum: ['headline', 'publish_time', 'content_format', 'editorial_intervention'] |
| `start_date` | DATE | Yes | Range: 2024-10-01 to 2025-01-07 |
| `end_date` | DATE | Yes | Must be > start_date, max 30 days |
| `status` | STRING | Yes | Enum: ['planning', 'running', 'completed', 'cancelled'] |
| `target_metric` | STRING | Yes | Enum: ['engagement_rate', 'scroll_completion', 'return_visits', 'quality_adjusted_engagement'] |
| `minimum_detectable_effect` | FLOAT | Yes | Range: 0.02-0.30 (2%-30%) |
| `target_power` | FLOAT | Yes | Range: 0.70-0.95, Default: 0.80 |
| `significance_level` | FLOAT | Yes | Range: 0.01-0.10, Default: 0.05 |
| `traffic_allocation_pct` | FLOAT | Yes | Range: 0.10-1.00 |
</details>

---

## 📝 Contract 2: Article Variants

### **Business Purpose**
Stores all versions of content being tested (the original + the treatments)

### **What Questions It Answers**
- "What are we testing in Experiment #5?"
- "What's the control headline vs the variant?"
- "Does the variant have good or bad sentiment?"
- "How many different versions are we testing?"

### **Key Fields (Business View)**

| Field | What It Means | Example | Why It Matters |
|-------|--------------|---------|----------------|
| `variant_name` | Which version | "control" or "variant_a" | Identifies treatment group |
| `is_control` | Is this the baseline? | TRUE or FALSE | One must be control |
| `headline_text` | Actual headline shown | "Why This Team Could Shock Everyone" | What users actually saw |
| `sentiment_score_positive` | AI quality score (0-1) | 0.82 (positive tone) | Prevents clickbait |
| `sentiment_label` | Sentiment category | "POSITIVE" | Quick quality check |

### **Business Rules**

✅ **Exactly one control per experiment**
- Why: Need a baseline to compare against

✅ **Max 4 variants per experiment** (1 control + 3 treatments)
- Why: More variants = need more traffic to reach significance, dilutes results

✅ **All variants must have sentiment scores before experiment ends**
- Why: Can't calculate quality-adjusted metrics without AI scores

✅ **Headlines must differ by min 3 words from control**
- Why: Too similar = not really testing anything different

### **Example: Headline Test Variants**

```
Experiment: "Question Headlines for Sports"

Control (Baseline):
  Headline: "NBA Playoffs Start Next Week"
  Sentiment: 0.72 (positive)
  
Variant A (Testing):
  Headline: "Why This NBA Team Could Shock Everyone"
  Sentiment: 0.82 (more positive)
  
Variant B (Testing):
  Headline: "You Won't BELIEVE This Playoff Prediction!"
  Sentiment: 0.45 (clickbait - negative)
  
Result: Variant A wins! (Higher engagement AND better sentiment)
```

<details>
<summary><b>📐 Technical Schema (Click to expand)</b></summary>

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| `variant_id` | STRING | Yes | Unique ID | Format: `var_\d{5}` |
| `article_id` | STRING | Yes | Base article | FK to article_metadata |
| `experiment_id` | STRING | Yes | Which test | FK to experiments |
| `variant_name` | STRING | Yes | Treatment name | Enum: ['control', 'variant_a', 'variant_b', 'variant_c'] |
| `is_control` | BOOLEAN | Yes | Is baseline? | Exactly one TRUE per experiment |
| `headline_text` | STRING | Yes | Shown headline | Length: 10-150 chars |
| `sentiment_score_positive` | FLOAT | No | AI positive (0-1) | Populated by Hugging Face |
| `sentiment_score_negative` | FLOAT | No | AI negative (0-1) | Populated by Hugging Face |
| `sentiment_label` | STRING | No | Category | Enum: ['POSITIVE', 'NEGATIVE', 'NEUTRAL'] |
</details>

---

## 👥 Contract 3: Experiment Assignments

### **Business Purpose**
Audit trail showing who saw which variant (proves test was fair)

### **What Questions It Answers**
- "Was randomization balanced?" (Each variant got ~50% traffic)
- "Did User #12345 always see the same variant?" (Consistency check)
- "Are mobile users over-represented in control?" (Bias check)

### **Why This Matters**
- Proves the test was fair (not biased)
- Lets us audit for issues: "Wait, why did control get 70% traffic?"
- Required for causal inference later

### **Key Fields (Business View)**

| Field | What It Means | Example | Why It Matters |
|-------|--------------|---------|----------------|
| `user_pseudo_id` | Anonymous user ID | "1234567890.abcdefghij" | Tracks individual |
| `variant_id` | Which version they saw | "var_00102" | Assignment record |
| `assignment_timestamp` | When they got assigned | "2024-11-15 14:23:45" | Audit trail |
| `assignment_method` | How we assigned | "hash_based" (deterministic) | Ensures consistency |

### **Business Rules**

✅ **User must see same variant for entire experiment**
- Why: If User A sees control on Monday, variant on Tuesday = confuses results

✅ **Assignments must be balanced** (within 10%)
- Why: If control gets 70%, variant gets 30% = unfair test

✅ **No assignment after experiment ends**
- Why: Post-experiment traffic shouldn't be included

### **Example: Fair Randomization**

```
Experiment: "Question Headlines"
Total users assigned: 17,186

Control:     8,621 users (50.1%) ✅ Balanced
Variant A:   8,565 users (49.9%) ✅ Balanced

Device split in Control:
  Mobile:    4,825 (56%) 
  Desktop:   3,796 (44%)
  
Device split in Variant A:
  Mobile:    4,782 (56%) ✅ Same distribution
  Desktop:   3,783 (44%) ✅ No bias
```

<details>
<summary><b>📐 Technical Schema (Click to expand)</b></summary>

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `assignment_id` | STRING | Yes | UUID format |
| `user_pseudo_id` | STRING | Yes | Length: 20-40 chars |
| `experiment_id` | STRING | Yes | FK to experiments |
| `variant_id` | STRING | Yes | FK to article_variants |
| `assignment_timestamp` | TIMESTAMP | Yes | ISO 8601 |
| `assignment_method` | STRING | Yes | Enum: ['hash_based', 'random', 'stratified'] |
| `device_category` | STRING | Yes | Enum: ['desktop', 'mobile', 'tablet'] |
</details>

---

## 📱 Contract 4: Events (User Behavior)

### **Business Purpose**
Tracks every user interaction: views, scrolls, time spent

### **What Questions It Answers**
- "Did User #12345 engage with this article?"
- "How long did they spend reading?"
- "Did they scroll to the bottom?"
- "Which variant did they see?" (for experiment analysis)

### **Key Fields (Business View)**

| Field | What It Means | Example | Why It Matters |
|-------|--------------|---------|----------------|
| `event_name` | What happened | "page_view" or "user_engagement" | Type of interaction |
| `engagement_time_msec` | Time spent (milliseconds) | 87500 = 87.5 seconds | Measures real engagement |
| `percent_scrolled` | How far scrolled (0-100) | 85% = read most of it | Quality signal |
| `experiment_id` | Which test user is in | "exp_001" | Links to experiment |
| `variant_id` | Which version they saw | "var_00102" | Links to variant |

### **Business Rules**

✅ **Engagement time must be 0-300 seconds** (5 minutes max)
- Why: Longer = probably left tab open, not actually reading

✅ **Scroll % only for scroll events** (not page views)
- Why: Different event types have different data

✅ **All events during experiments must have experiment_id**
- Why: Can't analyze experiments without linking events to variants

### **Example: Engaged User**

```
User #1234567890 encountered Experiment "Question Headlines"

Event 1 - Page View:
  Time: Nov 15, 2:23 PM
  Variant: variant_a (question headline)
  Article: "Why This Team Could Shock Everyone"

Event 2 - User Engagement:
  Time: Nov 15, 2:24 PM (87 seconds later)
  Engagement time: 87.5 seconds ✅ Engaged!
  
Event 3 - Scroll:
  Time: Nov 15, 2:25 PM
  Scroll depth: 85% ✅ Read most of it!

Result: User engaged (>60 sec AND >75% scroll)
```

<details>
<summary><b>📐 Technical Schema (Click to expand)</b></summary>

Follows GA4 BigQuery export schema with experiment extensions

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `event_id` | STRING | Yes | UUID format |
| `event_date` | STRING | Yes | YYYYMMDD format |
| `event_timestamp` | INT64 | Yes | Unix microseconds |
| `event_name` | STRING | Yes | Enum: ['page_view', 'scroll', 'user_engagement', 'click', 'return_visit'] |
| `user_pseudo_id` | STRING | Yes | Anonymous user ID |
| `experiment_id` | STRING | No | FK to experiments (NULL if not in experiment) |
| `variant_id` | STRING | No | FK to article_variants |
| `engagement_time_msec` | INT64 | No | Range: 0-300000 (5 min max) |
| `percent_scrolled` | INT64 | No | Range: 0-100 |
</details>

---

## 📊 Contract 5: Experiment Results

### **Business Purpose**
Statistical analysis showing which variant won, by how much, and how confident we are

### **What Questions It Answers**
- "Did we find a winner?"
- "What was the lift?"
- "Are we confident it's not just luck?"
- "Is it a big enough win to implement?"

### **Key Fields (Business View)**

| Field | What It Means | Example | Why It Matters |
|-------|--------------|---------|----------------|
| `variant_name` | Which version | "variant_a" | Identifies treatment |
| `sample_size` | How many users | 8,621 users | Bigger = more reliable |
| `metric_value_mean` | Average engagement rate | 0.36 = 36% | Performance |
| `vs_control_lift_pct` | How much better | 20% = variant is 20% better | The key number! |
| `p_value` | Probability it's luck | 0.002 = 0.2% chance it's random | Significance test |
| `is_statistically_significant` | Did we find a winner? | TRUE = Yes! | Decision point |
| `quality_adjusted_metric` | Engagement × sentiment | 0.295 = 29.5% | Prevents clickbait |

### **Business Rules**

✅ **Don't declare winner until p < 0.05 AND sample size sufficient**
- Why: Declaring too early = false positives, ship things that don't work

✅ **Apply Bonferroni correction if 3+ variants**
- Why: Testing multiple things inflates false positive rate

✅ **Check quality-adjusted metric before shipping**
- Why: Might have high engagement but negative sentiment (clickbait)

### **Example: Clear Winner**

```
Experiment: "Question Headlines for Sports"
Duration: 16 days, Nov 15 - Dec 1

Control:
  Sample: 8,621 users
  Engagement: 30.0%
  Sentiment: 0.72
  Quality-adjusted: 21.6%

Variant A (Question format):
  Sample: 8,565 users
  Engagement: 36.0% ✅ Better!
  Sentiment: 0.82 ✅ Also better sentiment!
  Quality-adjusted: 29.5% ✅ WAY better!
  
Statistics:
  Lift: 20% relative improvement
  P-value: 0.002 (99.8% confidence it's real)
  Significant: YES ✅
  
Decision: SHIP IT! Scale question headlines to all sports content.
Annual impact: $180K estimated revenue
```

### **Example: Clickbait Caught**

```
Experiment: "Curiosity Gap Headlines"

Control:
  Engagement: 30.0%
  Sentiment: 0.72
  Quality-adjusted: 21.6%

Variant B (Clickbait):
  Engagement: 36.0% ✅ Higher engagement
  Sentiment: 0.45 ❌ Negative tone!
  Quality-adjusted: 16.2% ❌ WORSE!
  
Statistics:
  Raw lift: 20% (looks like a win!)
  Quality-adjusted lift: -25% (actually worse!)
  
Decision: KILL IT. Clickbait damages brand. Traditional A/B testing would have shipped this!
```

<details>
<summary><b>📐 Technical Schema (Click to expand)</b></summary>

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `result_id` | STRING | Unique ID | Primary key |
| `experiment_id` | STRING | Which test | FK to experiments |
| `variant_id` | STRING | Which variant | FK to article_variants |
| `sample_size` | INTEGER | Users in variant | Must be > 0 |
| `metric_value_mean` | FLOAT | Avg engagement | Must be >= 0 |
| `metric_value_std_dev` | FLOAT | Standard deviation | Must be >= 0 |
| `confidence_interval_lower` | FLOAT | 95% CI lower | Calculated |
| `confidence_interval_upper` | FLOAT | 95% CI upper | Calculated |
| `vs_control_lift_pct` | FLOAT | Relative lift | NULL for control |
| `p_value` | FLOAT | Significance | Range 0-1, NULL for control |
| `is_statistically_significant` | BOOLEAN | Meets threshold | p < alpha |
| `statistical_power_achieved` | FLOAT | Achieved power | Range 0-1 |
| `quality_adjusted_metric` | FLOAT | Engagement × sentiment | AI-augmented |

**Derived Formulas:**
```
lift_pct = ((variant_mean - control_mean) / control_mean) * 100
p_value = calculated from t-test
quality_adjusted = mean_engagement * avg_sentiment_positive
```
</details>

---

## ✅ Data Quality Checks

### **What We Validate**

| Check | What It Catches | Example | Impact if Missed |
|-------|----------------|---------|------------------|
| **Completeness** | Missing required fields | Article with no headline | Can't run experiment |
| **Referential integrity** | Broken links | Variant references non-existent experiment | Results don't make sense |
| **Business logic** | Violates rules | Premium article with RPM < $8 | Revenue calculations wrong |
| **Consistency** | User sees different variants | User gets control Mon, variant Tue | Experiment contaminated |
| **Timeliness** | Late data | Events arrive 3 days after experiment ends | Can't make decisions |

### **Automated Monitoring (Airflow)**

✅ **Daily checks:**
- Sample sizes balanced? (within 10%)
- Events have experiment_id? (95%+ during test)
- Sentiment scores populated? (100% before experiment ends)
- No duplicate assignments? (each user assigned once)

✅ **Alerts sent if:**
- Sample size insufficient (won't reach significance in time)
- Randomization imbalanced (>15% difference)
- Data quality < 95% completeness

---

## 🎯 Success Criteria

### **Phase 1: Data Generation (Day 1-2)**
- [ ] 20 experiments with realistic parameters
- [ ] 70 article variants (3-4 per experiment)
- [ ] 500K events with proper experiment context
- [ ] 100% variants enriched with AI sentiment
- [ ] All data passes contract validations

### **Phase 2: Analysis (Day 3-4)**
- [ ] Experiment results calculated for all completed tests
- [ ] 5 significant positive results (27% win rate)
- [ ] 2 significant negative results (prove rigor)
- [ ] 1 inconclusive (stopped early, realistic)
- [ ] Quality-adjusted metrics catch 1 clickbait variant

### **Phase 3: Validation (Day 5)**
- [ ] False positive rate ~5% (matches alpha)
- [ ] Sample sizes meet power requirements
- [ ] Randomization balanced (max 10% difference)
- [ ] Semantic layer queries work
- [ ] Dashboards render correctly

---

## 🎤 How to Talk About Data Contracts

### **To Executives:**
> "Data contracts are our quality gates—they ensure experiment results are reliable. We validate everything: sample sizes, randomization balance, sentiment scores. That's why you can trust when we say 'this won got 20% lift with 99% confidence'—the data passed 15 quality checks."

### **To Product Team:**
> "Before we ship a winner, it has to pass our contract validation: statistically significant (p<0.05), sufficient sample size, quality-adjusted metric doesn't reveal clickbait. These gates prevent false positives."

### **To Data Team:**
> "We've defined explicit contracts for all 7 tables with validation rules, referential integrity, and business logic checks. Airflow monitors daily and alerts on violations. See DATA_CONTRACTS.md for full technical specs."

---

## 📚 Next Steps

**Want more detail?**
- See individual contract sections above
- Technical schemas available in expandable sections
- SQL DDL scripts: `scripts/snowflake/create_tables.sql`
- Validation queries: `scripts/validation/check_contracts.py`

**Questions?**
- Refer to BUSINESS_GLOSSARY.md for term definitions
- Check PROJECT_KICKOFF.md for overall context
- Create GitHub issue for specific questions
