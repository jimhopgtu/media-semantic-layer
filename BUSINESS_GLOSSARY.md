# Business Glossary - Experimentation Platform

**A plain-English guide to what we're measuring and why it matters**

---

## 📊 Key Metrics (What We Measure)

### **Engagement Rate** 
**Business definition:** % of visitors who actually READ your article  
**Technical definition:** Users who spent 60+ seconds OR scrolled past 75%  
**Why it matters:** Separates real readers from drive-by clickers  
**Good target:** 25-40% depending on content type  
**Example:** "Our sports content averages 32% engagement rate"

---

### **Lift**
**Business definition:** How much better the new version performed  
**Technical definition:** Relative or absolute difference between variants  
**Why it matters:** Measures the impact of your optimization  
**Good target:** 5-15% is a solid win  
**Example:** "Question headlines showed 11% lift in engagement"

---

### **Quality-Adjusted Engagement**
**Business definition:** Engagement weighted by content quality (prevents clickbait)  
**Technical definition:** Engagement Rate × AI Sentiment Score (0-1)  
**Why it matters:** Ensures we optimize for long-term value, not just clicks  
**Good target:** Growing over time (not declining)  
**Example:** "Variant had 40% engagement but only 18% quality-adjusted—it's clickbait"

---

### **Sentiment Score**
**Business definition:** How positive/negative the content tone is  
**Technical definition:** AI model output from 0 (negative) to 1 (positive)  
**Why it matters:** Predicts whether content builds or damages brand trust  
**Good target:** 0.60+ for most content, varies by category  
**Example:** "Opinion pieces average 0.55 sentiment, Sports averages 0.72"

---

### **Statistical Significance**
**Business definition:** Are we confident this isn't just random luck?  
**Technical definition:** p-value < 0.05 (95% confidence)  
**Why it matters:** Prevents shipping changes that don't actually work  
**Good target:** Wait for p < 0.05 AND sufficient sample size  
**Example:** "We need 8,500 users per variant to detect a 5% lift reliably"

---

### **Win Rate**
**Business definition:** What % of experiments found a winner  
**Technical definition:** Statistically significant positives / Total completed  
**Why it matters:** Measures experimentation program health  
**Good target:** 20-30% (higher = you're not taking enough risks)  
**Example:** "27% win rate across 15 experiments this quarter"

---

### **ROI (Return on Investment)**
**Business definition:** How much revenue we generated vs cost  
**Technical definition:** (Incremental Revenue - Program Costs) / Program Costs  
**Why it matters:** Justifies the experimentation program budget  
**Good target:** 5x+ return  
**Example:** "$127K revenue from $15K investment = 8.5x ROI"

---

## 🧪 Experimentation Terms

### **Control vs Variant**
**Business definition:** Original version vs new version we're testing  
**Example:** 
- Control: "NBA Playoffs Start Next Week" (what we've always done)
- Variant A: "Why This Team Could Shock Everyone" (what we're testing)

---

### **A/B Test / Experiment**
**Business definition:** Showing different versions to different people to see which works better  
**How it works:** 
- 50% of visitors see Control
- 50% see Variant A
- We measure which group engages more
**Why random assignment matters:** Ensures fair comparison (not just showing variants to morning traffic vs evening traffic)

---

### **Sample Size**
**Business definition:** How many people need to see each version before we can trust the results  
**Why it matters:** Too few = unreliable, random noise looks like real patterns  
**Rule of thumb:** Need 5,000-10,000+ users per variant for most tests  
**Example:** "We need 2 more days to hit 8,500 users per variant"

---

### **Statistical Power**
**Business definition:** Probability we'll detect a real difference if one exists  
**Technical definition:** 1 - β (type II error rate)  
**Why it matters:** Low power = might miss real winners  
**Good target:** 80%+ (industry standard)  
**Example:** "Our test has 85% power to detect a 5% lift"

---

### **Minimum Detectable Effect (MDE)**
**Business definition:** Smallest lift worth finding  
**Why it matters:** Determines sample size—smaller MDE requires more users  
**Trade-off:** Can detect 2% lift (requires 50K users) OR 10% lift (requires 2K users)  
**Example:** "We're targeting 5% MDE—any smaller isn't worth implementing"

---

### **False Positive Rate**
**Business definition:** How often we declare a "winner" that's actually just luck  
**Why it matters:** If too high, we ship changes that don't actually work  
**Good target:** ~5% (matches our significance level)  
**Example:** "Our FPR is 5.8%—within expected range"

---

## 📈 Revenue & Business Impact

### **RPM (Revenue Per Mille)**
**Business definition:** How much ad revenue per 1,000 pageviews  
**Typical values:**
- Sports: $8.50 RPM
- Finance: $12.00 RPM (premium advertisers)
- Lifestyle: $6.00 RPM
**Why it varies:** Finance readers are high-value for advertisers  
**Example:** "Finance RPM is 40% higher than sports—prioritize finance optimization"

---

### **Incremental Revenue**
**Business definition:** Extra money we made from the optimization  
**Formula:** (Extra engaged users × RPM) / 1000  
**Example calculation:**
- Baseline: 30% engagement on 100K monthly visitors = 30K engaged
- After optimization: 34.5% engagement = 34.5K engaged
- Lift: +4,500 engaged users
- Revenue: 4,500 × $8.50 / 1000 = **$38.25 extra per month**
- Annual: $38.25 × 12 = **$459 per article type**

---

### **Cost Per Conversion**
**Business definition:** How much we "pay" to get one engaged reader  
**Why it matters:** Helps prioritize which content to optimize  
**Example:** "Sports articles: $0.08 per engaged reader, Finance: $0.12—sports is more efficient"

---

## 🎯 Experiment Types

### **Headline Tests**
**What we're testing:** Different ways to write the title  
**Variants:**
- Question format: "Why did X happen?"
- Statement: "X happened"
- List: "5 reasons X happened"
**Typical results:** 5-20% lift when done well  
**Example:** Question format wins in Sports, fails in Finance

---

### **Publish Time Tests**
**What we're testing:** Best time of day to publish  
**Why it matters:** Reader behavior varies by time and category  
**Typical results:** 15-35% lift from optimal timing  
**Example:** Finance readers engage 6-9 AM (pre-market), Sports readers engage 7-10 PM (after work)

---

### **Format Tests**
**What we're testing:** Structure of the article  
**Variants:**
- Standard narrative
- Q&A format
- Listicle
- Data-heavy visualization
**Typical results:** 10-25% lift for complex topics  
**Example:** Q&A format works for rule changes, fails for game recaps

---

### **Editorial Intervention Tests**
**What we're testing:** Does AI-assisted editing help?  
**How we measure:** Writers with vs without AI tool  
**Why it's tricky:** Need causal inference (not just correlation)  
**Example:** "AI suggestions caused 7.5% lift (using difference-in-differences)"

---

## 📊 Dashboard Metrics (What Execs See)

### **Experiments per Month**
**Target:** 8-12 active tests  
**Interpretation:**
- Too few = not learning fast enough
- Too many = spreading resources thin, diluting traffic
**Current:** 9 experiments running

---

### **Average Time to Result**
**Target:** <14 days to reach statistical significance  
**Why it matters:** Faster iteration = faster learning  
**Current:** 11.3 days average

---

### **Program ROI**
**Target:** 5x+ return  
**Calculation:** (Incremental revenue - Program costs) / Program costs  
**Current:** 8.5x (very healthy)

---

### **Quality Score Trend**
**Target:** Stable or improving (not declining)  
**Why it matters:** Ensures we're not becoming clickbait  
**Measurement:** Average sentiment score across all content  
**Current:** +3.2% improvement YoY

---

## 🚨 Common Misunderstandings (What NOT to Say)

### ❌ "The variant is winning after 2 days!"
**Why this is wrong:** Too early—could be random noise or time-of-day effects  
**What to say instead:** "Variant is trending positive but needs 5 more days to reach significance"

---

### ❌ "Let's test 10 different headlines!"
**Why this is wrong:** Multiple testing problem—false positive rate goes way up  
**What to say instead:** "Let's test 3 variants max and apply Bonferroni correction"

---

### ❌ "This won with 90% confidence!"
**Why this is misleading:** We use 95% as standard (p<0.05)  
**What to say instead:** "This reached statistical significance at our 95% threshold (p=0.03)"

---

### ❌ "Engagement is up 5%, let's ship it!"
**Why incomplete:** Could be clickbait—check quality score  
**What to say instead:** "Engagement is up 5% and sentiment is stable at 0.74—safe to ship"

---

### ❌ "We should always choose the higher engagement rate"
**Why this is wrong:** Ignores business context (implementation cost, brand fit, quality)  
**What to say instead:** "Variant B has lower lift but better quality and easier to implement—it's the right choice"

---

## 🎤 How to Talk About This in Meetings

### **To Your CEO:**
> "We ran 15 experiments last quarter and found 5 winners. These optimizations generated $127K in incremental revenue against $15K in costs—that's an 8.5x return. Our content quality scores are also up 3.2%, so we're not becoming clickbait. Biggest win was publish time optimization for finance content—34% lift."

### **To Editorial Team:**
> "Our experiments show question-format headlines work really well in sports and lifestyle—11% average lift. But they backfire in finance where readers want direct information. We're building category-specific headline guidelines from these learnings."

### **To Product Team:**
> "Three experiments are ready to scale: question headlines (18% lift, easy implementation, $180K annual impact), 7 PM publish time for sports (28% lift, calendar automation needed), and Q&A format for complex topics (22% lift, template work required). I've prioritized them by ROI vs implementation cost."

### **To Writers:**
> "We tested your articles with different headlines and found that question format headlines get 15% more engagement without sacrificing quality. We're not asking you to write clickbait—the AI checks sentiment to make sure the tone stays positive. Here are some examples of what works..."

---

## 📚 Learn More

**For deeper technical details, see:**
- `DATA_CONTRACTS.md` - Database schemas and validation rules
- `docs/statistical_methods.md` - How we calculate significance, power, lift
- `docs/architecture.md` - System design and data flow

**For implementation guides, see:**
- `docs/setup_guide.md` - Getting started
- `docs/week1_roadmap.md` - Development plan

---

**Questions? Issues?**
Create a GitHub issue or refer to this glossary first—it covers 90% of questions!
